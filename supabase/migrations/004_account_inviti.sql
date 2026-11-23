-- =============================================================================
-- Cenato · 004_account_inviti.sql
-- Consenso GDPR con versione dell'informativa, errori distinti per i codici di
-- invito e verifica del codice PRIMA della registrazione.
-- RF_GA_1, RF_GA_6, RF_GI_2 · UC_GA_1, UC_GI_2 · RNF_L_1 · SCD_1
-- Schede Trello: [MC] Registrazione con ruolo e consenso GDPR,
--                [MC] Accettazione invito e collegamento al nutrizionista.
--
-- Codici di errore aggiunti (SQLSTATE), oltre a quelli di 002_rls.sql:
--   CN010 codice non valido     CN011 codice scaduto
--   CN012 codice già usato      CN013 invito revocato
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Consenso: data (già presente) e versione dell'informativa accettata
-- -----------------------------------------------------------------------------
alter table public.profili add column versione_informativa text;
comment on column public.profili.versione_informativa is
  'Versione dell''informativa sul trattamento dei dati sanitari accettata alla registrazione (RF_GA_6, GDPR art. 9). Il testo è in lib/core/costanti/informativa.dart.';

-- Chi aveva già dato il consenso (account demo) ha accettato la versione 1.0.
update public.profili set versione_informativa = '1.0' where consenso_dati_il is not null;

-- La registrazione senza consenso esplicito è rifiutata anche dal database
-- (non solo dall'app): CLAUDE.md regola 6, RNF_L_1.
create or replace function public.crea_profilo_da_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ruolo text := new.raw_user_meta_data ->> 'ruolo';
  v_nome  text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'nome', '')), '');
  v_consenso boolean := lower(coalesce(new.raw_user_meta_data ->> 'consenso_dati', 'false')) = 'true';
begin
  if v_ruolo is null or v_ruolo not in ('nutrizionista', 'paziente') then
    raise exception 'Ruolo mancante o non valido: usa nutrizionista o paziente'
      using errcode = '22023';
  end if;
  if not v_consenso then
    raise exception 'Serve il consenso esplicito al trattamento dei dati sanitari'
      using errcode = '22023';
  end if;

  insert into public.profili (id, ruolo, nome, consenso_dati_il, versione_informativa)
  values (
    new.id,
    v_ruolo::public.ruolo_utente,
    coalesce(v_nome, split_part(new.email, '@', 1)),
    now(),
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'versione_informativa'), ''), '1.0')
  );
  return new;
end;
$$;

-- -----------------------------------------------------------------------------
-- Inviti: stato del codice con errori distinti (SCD_1)
-- -----------------------------------------------------------------------------

-- Legge l'invito e ne controlla lo stato. Non modifica nulla.
create or replace function privato.invito_valido(p_codice text, p_blocca boolean)
returns public.inviti
language plpgsql
security definer
set search_path = ''
as $$
declare
  v public.inviti%rowtype;
begin
  if p_blocca then
    select * into v from public.inviti where codice = upper(trim(p_codice)) for update;
  else
    select * into v from public.inviti where codice = upper(trim(p_codice));
  end if;

  if not found then
    raise exception using errcode = 'CN010',
      message = 'Codice non valido: controlla di averlo scritto bene.';
  end if;
  if v.stato = 'utilizzato' then
    raise exception using errcode = 'CN012',
      message = 'Questo codice è già stato usato: chiedi un nuovo invito al tuo nutrizionista.';
  end if;
  if v.stato = 'revocato' then
    raise exception using errcode = 'CN013',
      message = 'Questo invito è stato annullato dal nutrizionista: chiedine uno nuovo.';
  end if;
  if v.stato = 'scaduto' or v.scadenza < now() then
    raise exception using errcode = 'CN011',
      message = 'Il codice è scaduto: chiedi un nuovo invito al tuo nutrizionista.';
  end if;
  return v;
end;
$$;

-- UC_GA_1 / UC_GI_2: verifica il codice PRIMA di creare l'account e mostra
-- "Sei stato invitato da <nome>". Chiamabile senza login: restituisce solo il
-- nome del nutrizionista e la scadenza. Il codice (8 caratteri su 32 simboli,
-- circa 10^12 combinazioni, validità 7 giorni) non è indovinabile a tentativi.
create or replace function public.verifica_invito(p_codice text)
returns table (nome_nutrizionista text, scadenza timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v public.inviti%rowtype;
begin
  v := privato.invito_valido(p_codice, false);
  return query
  select pr.nome, v.scadenza from public.profili pr where pr.id = v.nutrizionista_id;
end;
$$;

-- anteprima_invito (002) è sostituita da verifica_invito.
drop function if exists public.anteprima_invito(text);

-- UC_GI_2 · RF_GI_2: il paziente accetta l'invito (ora con errori distinti).
create or replace function public.accetta_invito(p_codice text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utente uuid := (select auth.uid());
  v_invito public.inviti%rowtype;
begin
  if not exists (select 1 from public.profili where id = v_utente and ruolo = 'paziente') then
    raise exception using errcode = 'CN007', message = 'Solo un paziente può accettare un invito.';
  end if;

  v_invito := privato.invito_valido(p_codice, true);

  if exists (select 1 from public.pazienti where utente_id = v_utente and stato <> 'archiviato') then
    raise exception using errcode = 'CN008',
      message = 'Sei già collegato a un nutrizionista: interrompi prima il collegamento.';
  end if;

  -- UC_GI_2, flusso 5.1: il limite potrebbe essere stato raggiunto nel frattempo.
  perform 1 from public.nutrizionisti where id = v_invito.nutrizionista_id for update;
  begin
    perform privato.verifica_limite_piano(v_invito.nutrizionista_id, false);
  exception when sqlstate 'CN001' then
    raise exception using errcode = 'CN001',
      message = 'Il nutrizionista ha raggiunto il limite del suo piano: contattalo per completare il collegamento.';
  end;

  update public.pazienti
  set utente_id = v_utente, stato = 'attivo', data_collegamento = now(),
      data_archiviazione = null, archiviato_da = null
  where id = v_invito.paziente_id;

  update public.inviti set stato = 'utilizzato', utilizzato_il = now() where id = v_invito.id;
  return v_invito.paziente_id;
end;
$$;

-- Permessi: verifica_invito anche senza login; il resto invariato.
revoke execute on function public.verifica_invito(text), privato.invito_valido(text, boolean)
  from public, anon, authenticated;
grant execute on function public.verifica_invito(text) to anon, authenticated;
grant execute on function public.accetta_invito(text) to authenticated;
