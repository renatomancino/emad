-- =============================================================================
-- Cenato · 002_rls.sql
-- Row Level Security, privilegi per colonna e funzioni RPC con i controlli.
-- RNF_L_1, RNF_L_2, RNF_A_6, RNF_S_3 · CLAUDE.md regole 3, 5, 6, 7
-- Scheda Trello: [RM] Policy RLS per ruolo (con test).
--
-- Principi:
--   • Nessun accesso anonimo: al ruolo `anon` non resta alcun privilegio.
--   • Nutrizionista (NUT): solo i propri pazienti; i dati clinici in sola
--     lettura (check-in, pasti extra, aderenza) e nessuna DELETE sui dati clinici.
--   • Paziente (PAZ): solo i propri dati; scrive check-in, pasti extra e peso
--     solo finché il collegamento è Attivo.
--   • Le colonne "di stato" (ruolo, nutrizionista di un paziente, stato del
--     paziente, piano di abbonamento) non sono scrivibili direttamente: cambiano
--     solo dalle funzioni RPC qui sotto, che verificano chi chiama.
--   • Codici di errore delle RPC (SQLSTATE) con messaggio in italiano:
--       CN001 limite del piano          CN002 invito non valido
--       CN003 slot non disponibile      CN004 visita futura già presente
--       CN005 fuori finestra/disponib.  CN006 annullamento oltre il termine
--       CN007 operazione non consentita CN008 già collegato
--       CN009 serve un nuovo invito
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Integrazioni allo schema
-- -----------------------------------------------------------------------------

-- Chi ha archiviato il paziente: se è stato il paziente (scollegamento,
-- UC_GI_5) il nutrizionista non può riattivarlo da solo (serve un nuovo invito).
alter table public.pazienti add column archiviato_da public.ruolo_utente;

-- RF_GD_3: correzione del check-in entro il giorno successivo [DA CONFERMARE].
create or replace function public.giorni_correzione_checkin()
returns integer language sql immutable set search_path = '' as $$ select 1 $$;

-- Fuso orario degli orari di ricevimento (disponibilità e slot).
create or replace function public.fuso_orario()
returns text language sql immutable set search_path = '' as $$ select 'Europe/Rome' $$;

-- -----------------------------------------------------------------------------
-- Funzioni di supporto alle policy (security definer: leggono le tabelle senza
-- passare dalla RLS, così le policy non si richiamano a vicenda)
-- -----------------------------------------------------------------------------

create or replace function privato.e_nutrizionista()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profili
    where id = (select auth.uid()) and ruolo = 'nutrizionista'
  );
$$;

-- Il NUT che chiama segue questo paziente (qualunque stato: lo storico resta).
create or replace function privato.nut_segue(p_paziente uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pazienti
    where id = p_paziente and nutrizionista_id = (select auth.uid())
  );
$$;

-- Il PAZ che chiama è questo paziente (qualunque stato: vede i propri dati).
create or replace function privato.e_mio_collegamento(p_paziente uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pazienti
    where id = p_paziente and utente_id = (select auth.uid())
  );
$$;

-- Il PAZ che chiama è questo paziente e il collegamento è Attivo (può scrivere).
create or replace function privato.e_mio_collegamento_attivo(p_paziente uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.pazienti
    where id = p_paziente and utente_id = (select auth.uid()) and stato = 'attivo'
  );
$$;

-- Profili leggibili: il proprio, quelli dei propri pazienti (NUT) e quello del
-- proprio nutrizionista (PAZ).
create or replace function privato.profilo_visibile(p_profilo uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_profilo = (select auth.uid())
      or exists (select 1 from public.pazienti
                 where utente_id = p_profilo and nutrizionista_id = (select auth.uid()))
      or exists (select 1 from public.pazienti
                 where nutrizionista_id = p_profilo and utente_id = (select auth.uid()));
$$;

-- Piano: il NUT autore lo gestisce; il PAZ legge le versioni assegnate
-- (corrente e superate, per lo storico dei check-in), mai le bozze.
create or replace function privato.nut_gestisce_piano(p_piano uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.piani p join public.pazienti pz on pz.id = p.paziente_id
    where p.id = p_piano and p.nutrizionista_id = (select auth.uid())
      and pz.nutrizionista_id = (select auth.uid())
  );
$$;

create or replace function privato.piano_leggibile(p_piano uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select privato.nut_gestisce_piano(p_piano) or exists (
    select 1 from public.piani p join public.pazienti pz on pz.id = p.paziente_id
    where p.id = p_piano and p.stato <> 'bozza' and pz.utente_id = (select auth.uid())
  );
$$;

-- La struttura del piano si modifica solo in bozza: una versione assegnata non
-- cambia più, si crea una nuova versione (RF_GP_7).
create or replace function privato.piano_in_bozza_del_nut(p_piano uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select privato.nut_gestisce_piano(p_piano)
     and exists (select 1 from public.piani where id = p_piano and stato = 'bozza');
$$;

create or replace function privato.piano_del_giorno(p_giorno uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select piano_id from public.giorni where id = p_giorno;
$$;

create or replace function privato.piano_del_pasto(p_pasto uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select g.piano_id from public.pasti pa join public.giorni g on g.id = pa.giorno_id
  where pa.id = p_pasto;
$$;

create or replace function privato.piano_della_voce(p_voce uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select g.piano_id from public.voci_pasto v
  join public.pasti pa on pa.id = v.pasto_id
  join public.giorni g on g.id = pa.giorno_id
  where v.id = p_voce;
$$;

create or replace function privato.paziente_del_check_in(p_check_in uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select paziente_id from public.check_in where id = p_check_in;
$$;

-- -----------------------------------------------------------------------------
-- Privilegi di base: niente ad anon; ad authenticated solo ciò che serve.
-- La RLS decide poi QUALI righe.
-- -----------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;
alter default privileges in schema public revoke all on tables from anon;

grant select, update (nome)                                         on public.profili to authenticated;
grant select, update (titolo, durata_visita_min)                    on public.nutrizionisti to authenticated;
grant select                                                        on public.abbonamenti to authenticated;
grant select, update (nome, data_nascita, altezza_cm, obiettivo)    on public.pazienti to authenticated;
grant select                                                        on public.inviti to authenticated;
grant select, insert                                                on public.obiettivi to authenticated;
grant select, insert, update                                        on public.alimenti to authenticated;
grant select, insert, update, delete                                on public.piani to authenticated;
grant select, insert, update, delete                                on public.giorni to authenticated;
grant select, insert, update, delete                                on public.pasti to authenticated;
grant select, insert, update, delete                                on public.voci_pasto to authenticated;
grant select, insert, update, delete                                on public.alternative to authenticated;
grant select, insert, update, delete                                on public.modelli_piano to authenticated;
grant select, insert, update (stato, alternativa_id, etichetta, nota) on public.check_in to authenticated;
grant select, insert                                                on public.pasti_extra to authenticated;
grant select, insert, update (testo)                                on public.commenti to authenticated;
grant select, insert, update (valore_kg)                            on public.misure_peso to authenticated;
grant select                                                        on public.stati_aderenza to authenticated;
grant select, update (letta_il)                                     on public.notifiche to authenticated;
grant select, insert, update                                        on public.preferenze_notifiche to authenticated;
grant select, insert, update, delete                                on public.disponibilita to authenticated;
grant select, insert, update                                        on public.finestre_prenotazione to authenticated;
grant select, insert, update (inizio, durata_min, stato, nota, annullata_il) on public.visite to authenticated;

-- =============================================================================
-- Policy per tabella
-- =============================================================================

-- profili ---------------------------------------------------------------------
-- (000_profili.sql ha già: profili_select_proprio, profili_update_proprio)
create policy profili_select_collegati on public.profili
  for select to authenticated
  using (privato.profilo_visibile(id));

-- nutrizionisti -----------------------------------------------------------------
create policy nutrizionisti_select on public.nutrizionisti
  for select to authenticated
  using (id = (select auth.uid()) or privato.profilo_visibile(id));
create policy nutrizionisti_update_proprio on public.nutrizionisti
  for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- abbonamenti -------------------------------------------------------------------
create policy abbonamenti_select_proprio on public.abbonamenti
  for select to authenticated
  using (nutrizionista_id = (select auth.uid()));

-- pazienti ----------------------------------------------------------------------
create policy pazienti_select_nut on public.pazienti
  for select to authenticated
  using (nutrizionista_id = (select auth.uid()));
create policy pazienti_select_paz on public.pazienti
  for select to authenticated
  using (utente_id = (select auth.uid()));
create policy pazienti_update_nut on public.pazienti
  for update to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()));
create policy pazienti_update_paz on public.pazienti
  for update to authenticated
  using (utente_id = (select auth.uid()) and stato = 'attivo')
  with check (utente_id = (select auth.uid()));

-- inviti ------------------------------------------------------------------------
create policy inviti_select_nut on public.inviti
  for select to authenticated
  using (nutrizionista_id = (select auth.uid()));

-- obiettivi ---------------------------------------------------------------------
create policy obiettivi_select on public.obiettivi
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));
create policy obiettivi_insert_nut on public.obiettivi
  for insert to authenticated
  with check (privato.nut_segue(paziente_id));

-- alimenti (cache condivisa) ------------------------------------------------------
create policy alimenti_select on public.alimenti
  for select to authenticated
  using (true);
create policy alimenti_insert_nut on public.alimenti
  for insert to authenticated
  with check (privato.e_nutrizionista() and (creato_da is null or creato_da = (select auth.uid())));
create policy alimenti_update_nut on public.alimenti
  for update to authenticated
  using (privato.e_nutrizionista() and (fonte = 'open_food_facts' or creato_da = (select auth.uid())))
  with check (privato.e_nutrizionista() and (fonte = 'open_food_facts' or creato_da = (select auth.uid())));

-- piani -------------------------------------------------------------------------
create policy piani_select on public.piani
  for select to authenticated
  using (privato.piano_leggibile(id));
create policy piani_insert_nut on public.piani
  for insert to authenticated
  with check (nutrizionista_id = (select auth.uid()) and privato.nut_segue(paziente_id));
create policy piani_update_nut on public.piani
  for update to authenticated
  using (privato.nut_gestisce_piano(id))
  with check (nutrizionista_id = (select auth.uid()) and privato.nut_segue(paziente_id));
create policy piani_delete_bozza on public.piani
  for delete to authenticated
  using (privato.piano_in_bozza_del_nut(id));

-- giorni, pasti, voci, alternative ---------------------------------------------------
create policy giorni_select on public.giorni
  for select to authenticated using (privato.piano_leggibile(piano_id));
create policy giorni_scrittura on public.giorni
  for all to authenticated
  using (privato.piano_in_bozza_del_nut(piano_id))
  with check (privato.piano_in_bozza_del_nut(piano_id));

create policy pasti_select on public.pasti
  for select to authenticated using (privato.piano_leggibile(privato.piano_del_giorno(giorno_id)));
create policy pasti_scrittura on public.pasti
  for all to authenticated
  using (privato.piano_in_bozza_del_nut(privato.piano_del_giorno(giorno_id)))
  with check (privato.piano_in_bozza_del_nut(privato.piano_del_giorno(giorno_id)));

create policy voci_pasto_select on public.voci_pasto
  for select to authenticated using (privato.piano_leggibile(privato.piano_del_pasto(pasto_id)));
create policy voci_pasto_scrittura on public.voci_pasto
  for all to authenticated
  using (privato.piano_in_bozza_del_nut(privato.piano_del_pasto(pasto_id)))
  with check (privato.piano_in_bozza_del_nut(privato.piano_del_pasto(pasto_id)));

create policy alternative_select on public.alternative
  for select to authenticated using (privato.piano_leggibile(privato.piano_della_voce(voce_id)));
create policy alternative_scrittura on public.alternative
  for all to authenticated
  using (privato.piano_in_bozza_del_nut(privato.piano_della_voce(voce_id)))
  with check (privato.piano_in_bozza_del_nut(privato.piano_della_voce(voce_id)));

-- modelli_piano -------------------------------------------------------------------
create policy modelli_piano_nut on public.modelli_piano
  for all to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()) and privato.e_nutrizionista());

-- check_in ----------------------------------------------------------------------
create policy check_in_select on public.check_in
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));
-- Il paziente registra o corregge solo i propri check-in, di oggi o del giorno
-- prima (RF_GD_3), e solo con collegamento Attivo.
create policy check_in_insert_paz on public.check_in
  for insert to authenticated
  with check (
    privato.e_mio_collegamento_attivo(paziente_id)
    and data <= current_date
    and data >= current_date - public.giorni_correzione_checkin()
  );
create policy check_in_update_paz on public.check_in
  for update to authenticated
  using (
    privato.e_mio_collegamento_attivo(paziente_id)
    and data >= current_date - public.giorni_correzione_checkin()
  )
  with check (privato.e_mio_collegamento_attivo(paziente_id));

-- pasti_extra -------------------------------------------------------------------
create policy pasti_extra_select on public.pasti_extra
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));
create policy pasti_extra_insert_paz on public.pasti_extra
  for insert to authenticated
  with check (
    privato.e_mio_collegamento_attivo(paziente_id)
    and data <= current_date
    and data >= current_date - public.giorni_correzione_checkin()
  );

-- commenti ----------------------------------------------------------------------
create policy commenti_select on public.commenti
  for select to authenticated
  using (
    privato.nut_segue(privato.paziente_del_check_in(check_in_id))
    or privato.e_mio_collegamento(privato.paziente_del_check_in(check_in_id))
  );
create policy commenti_insert_nut on public.commenti
  for insert to authenticated
  with check (
    nutrizionista_id = (select auth.uid())
    and privato.nut_segue(privato.paziente_del_check_in(check_in_id))
  );
create policy commenti_update_nut on public.commenti
  for update to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()));

-- misure_peso (RF_GM_1: PAZ, o NUT durante la visita) ------------------------------
create policy misure_peso_select on public.misure_peso
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));
create policy misure_peso_insert on public.misure_peso
  for insert to authenticated
  with check (
    inserita_da = (select auth.uid())
    and (privato.e_mio_collegamento_attivo(paziente_id) or privato.nut_segue(paziente_id))
  );
create policy misure_peso_update on public.misure_peso
  for update to authenticated
  using (inserita_da = (select auth.uid()))
  with check (inserita_da = (select auth.uid()));

-- stati_aderenza (solo lettura: li calcola il back-end) -----------------------------
create policy stati_aderenza_select on public.stati_aderenza
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));

-- notifiche e preferenze -----------------------------------------------------------
create policy notifiche_select_proprie on public.notifiche
  for select to authenticated using (utente_id = (select auth.uid()));
create policy notifiche_update_proprie on public.notifiche
  for update to authenticated
  using (utente_id = (select auth.uid())) with check (utente_id = (select auth.uid()));

create policy preferenze_proprie on public.preferenze_notifiche
  for all to authenticated
  using (utente_id = (select auth.uid())) with check (utente_id = (select auth.uid()));

-- disponibilita -------------------------------------------------------------------
create policy disponibilita_select on public.disponibilita
  for select to authenticated
  using (nutrizionista_id = (select auth.uid()) or privato.profilo_visibile(nutrizionista_id));
create policy disponibilita_scrittura_nut on public.disponibilita
  for all to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()) and privato.e_nutrizionista());

-- finestre_prenotazione -------------------------------------------------------------
create policy finestre_select on public.finestre_prenotazione
  for select to authenticated
  using (privato.nut_segue(paziente_id) or privato.e_mio_collegamento(paziente_id));
create policy finestre_insert_nut on public.finestre_prenotazione
  for insert to authenticated with check (privato.nut_segue(paziente_id));
create policy finestre_update_nut on public.finestre_prenotazione
  for update to authenticated
  using (privato.nut_segue(paziente_id)) with check (privato.nut_segue(paziente_id));

-- visite (il PAZ prenota e annulla solo tramite RPC) ---------------------------------
create policy visite_select on public.visite
  for select to authenticated
  using (nutrizionista_id = (select auth.uid()) or privato.e_mio_collegamento(paziente_id));
create policy visite_insert_nut on public.visite
  for insert to authenticated
  with check (
    nutrizionista_id = (select auth.uid())
    and origine = 'nutrizionista'
    and stato = 'fissata'
    and exists (select 1 from public.pazienti
                where id = paziente_id and nutrizionista_id = (select auth.uid()) and stato = 'attivo')
  );
create policy visite_update_nut on public.visite
  for update to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()));

-- =============================================================================
-- Funzioni RPC (security definer, con controllo del chiamante)
-- =============================================================================

-- Segna come scaduti gli inviti oltre la scadenza (SCD_1).
create or replace function privato.aggiorna_inviti_scaduti()
returns void language sql security definer set search_path = '' as $$
  update public.inviti set stato = 'scaduto'
  where stato = 'creato' and scadenza < now();
$$;

-- Posti occupati e limite del piano di un nutrizionista (RF_GAD_4):
-- Free: tutti i pazienti che hanno accettato (anche archiviati) + inviti in attesa;
-- Start: pazienti attivi + inviti in attesa; Pro: nessun limite.
create or replace function privato.verifica_limite_piano(p_nutrizionista uuid, p_includi_inviti boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_piano public.piano_abbonamento;
  v_limite integer;
  v_occupati integer;
begin
  select piano_abbonamento into v_piano from public.nutrizionisti where id = p_nutrizionista;
  v_limite := public.limite_pazienti(v_piano::text);
  if v_limite is null then
    return;
  end if;

  if v_piano = 'free' then
    v_occupati := privato.pazienti_invitati_totali(p_nutrizionista);
  else
    select count(*) into v_occupati from public.pazienti
    where nutrizionista_id = p_nutrizionista and stato = 'attivo';
  end if;

  if p_includi_inviti then
    v_occupati := v_occupati + (
      select count(*) from public.inviti
      where nutrizionista_id = p_nutrizionista and stato = 'creato' and scadenza >= now()
    );
  end if;

  if v_occupati >= v_limite then
    raise exception using
      errcode = 'CN001',
      message = case v_piano
        when 'free' then format('Hai raggiunto il limite del piano Free (%s paziente).', v_limite)
        else format('Hai raggiunto il limite del piano Start (%s pazienti attivi).', v_limite)
      end,
      detail = v_piano::text,
      hint = case v_piano
        when 'free' then 'Passa a Start o Pro per invitare altri pazienti.'
        else 'Passa a Pro oppure archivia un paziente per liberare un posto.'
      end;
  end if;
end;
$$;

-- UC_GI_1 · RF_GI_1, RF_GAD_7: crea un invito se il piano lo consente.
create or replace function public.crea_invito(p_nome text default null)
returns table (invito_id uuid, paziente_id uuid, codice text, scadenza timestamptz)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_nut uuid := (select auth.uid());
  v_codice text;
  v_paziente uuid;
  v_invito uuid;
  v_scadenza timestamptz;
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  if not privato.e_nutrizionista() then
    raise exception using errcode = 'CN007', message = 'Solo un nutrizionista può creare un invito.';
  end if;

  -- Serializza gli inviti dello stesso nutrizionista (limite non aggirabile).
  perform 1 from public.nutrizionisti where id = v_nut for update;
  perform privato.aggiorna_inviti_scaduti();
  perform privato.verifica_limite_piano(v_nut, true);

  loop
    select string_agg(substr(v_alfabeto, 1 + floor(random() * length(v_alfabeto))::int, 1), '')
      into v_codice from generate_series(1, 8);
    exit when not exists (select 1 from public.inviti i where i.codice = v_codice);
  end loop;

  insert into public.pazienti (nutrizionista_id, stato, nome)
  values (v_nut, 'invitato', nullif(trim(p_nome), ''))
  returning id into v_paziente;

  insert into public.inviti as i (nutrizionista_id, paziente_id, codice)
  values (v_nut, v_paziente, v_codice)
  returning i.id, i.scadenza into v_invito, v_scadenza;

  return query select v_invito, v_paziente, v_codice, v_scadenza;
end;
$$;

-- RF_GI_8: revoca di un invito non ancora usato.
create or replace function public.revoca_invito(p_invito uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.inviti set stato = 'revocato', revocato_il = now()
  where id = p_invito and nutrizionista_id = (select auth.uid()) and stato = 'creato';
  if not found then
    raise exception using errcode = 'CN007', message = 'Invito non trovato o già utilizzato.';
  end if;
end;
$$;

-- UC_GI_2, passo 3: mostra il nome del nutrizionista prima della conferma.
create or replace function public.anteprima_invito(p_codice text)
returns table (nome_nutrizionista text, scadenza timestamptz)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  return query
  select pr.nome, i.scadenza
  from public.inviti i join public.profili pr on pr.id = i.nutrizionista_id
  where i.codice = upper(trim(p_codice)) and i.stato = 'creato' and i.scadenza >= now();
  if not found then
    raise exception using errcode = 'CN002',
      message = 'Codice non valido, scaduto o già usato: chiedi un nuovo invito al nutrizionista.';
  end if;
end;
$$;

-- UC_GI_2 · RF_GI_2: il paziente accetta l'invito e si collega.
create or replace function public.accetta_invito(p_codice text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_utente uuid := (select auth.uid());
  v_invito public.inviti%rowtype;
begin
  if not exists (select 1 from public.profili where id = v_utente and ruolo = 'paziente') then
    raise exception using errcode = 'CN007', message = 'Solo un paziente può accettare un invito.';
  end if;

  perform privato.aggiorna_inviti_scaduti();
  select * into v_invito from public.inviti
  where codice = upper(trim(p_codice)) and stato = 'creato' and scadenza >= now()
  for update;
  if not found then
    raise exception using errcode = 'CN002',
      message = 'Codice non valido, scaduto o già usato: chiedi un nuovo invito al nutrizionista.';
  end if;

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
  set utente_id = v_utente, stato = 'attivo', data_collegamento = now()
  where id = v_invito.paziente_id;

  update public.inviti set stato = 'utilizzato', utilizzato_il = now() where id = v_invito.id;
  return v_invito.paziente_id;
end;
$$;

-- Annulla le visite future di un paziente (SCD_2: archiviato o scollegato).
create or replace function privato.annulla_visite_future(p_paziente uuid)
returns void language sql security definer set search_path = '' as $$
  update public.visite set stato = 'annullata', annullata_il = now()
  where paziente_id = p_paziente and stato in ('fissata', 'prenotata') and inizio > now();
$$;

-- UC_GI_4 · RF_GI_4: archiviazione da parte del nutrizionista.
create or replace function public.archivia_paziente(p_paziente uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.pazienti
  set stato = 'archiviato', data_archiviazione = now(), archiviato_da = 'nutrizionista'
  where id = p_paziente and nutrizionista_id = (select auth.uid()) and stato = 'attivo';
  if not found then
    raise exception using errcode = 'CN007', message = 'Paziente non trovato o non attivo.';
  end if;
  perform privato.annulla_visite_future(p_paziente);
end;
$$;

-- UC_GI_4 · RF_GI_5: riattivazione, se il piano lo consente.
create or replace function public.riattiva_paziente(p_paziente uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_nut uuid := (select auth.uid());
  v_paz public.pazienti%rowtype;
begin
  select * into v_paz from public.pazienti
  where id = p_paziente and nutrizionista_id = v_nut and stato = 'archiviato'
  for update;
  if not found then
    raise exception using errcode = 'CN007', message = 'Paziente non trovato o non archiviato.';
  end if;
  if v_paz.archiviato_da = 'paziente' then
    raise exception using errcode = 'CN009',
      message = 'Il paziente ha interrotto il collegamento: per seguirlo di nuovo serve un nuovo invito.';
  end if;

  perform 1 from public.nutrizionisti where id = v_nut for update;
  -- Nel Free il paziente è già contato: si può riattivare solo se il totale
  -- non supera il limite. In Start serve un posto attivo libero.
  if (select piano_abbonamento from public.nutrizionisti where id = v_nut) = 'free' then
    if privato.pazienti_invitati_totali(v_nut) > public.limite_pazienti('free') then
      raise exception using errcode = 'CN001', message = 'Hai superato il limite del piano Free.',
        hint = 'Passa a Start o Pro per riattivare il paziente.';
    end if;
  else
    perform privato.verifica_limite_piano(v_nut, false);
  end if;

  begin
    update public.pazienti
    set stato = 'attivo', data_archiviazione = null, archiviato_da = null
    where id = p_paziente;
  exception when unique_violation then
    raise exception using errcode = 'CN008',
      message = 'Il paziente è ora collegato a un altro nutrizionista.';
  end;
end;
$$;

-- UC_GI_5 · RF_GI_7: il paziente interrompe il collegamento.
create or replace function public.scollega_paziente()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_paziente uuid;
begin
  update public.pazienti
  set stato = 'archiviato', data_archiviazione = now(), archiviato_da = 'paziente'
  where utente_id = (select auth.uid()) and stato = 'attivo'
  returning id into v_paziente;
  if v_paziente is null then
    raise exception using errcode = 'CN007', message = 'Non risulti collegato a un nutrizionista.';
  end if;
  perform privato.annulla_visite_future(v_paziente);
end;
$$;

-- UC_GV_4 · RF_GV_8, RNF_A_6: il paziente prenota uno slot libero.
create or replace function public.prenota_visita(p_inizio timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_paz public.pazienti%rowtype;
  v_durata integer;
  v_locale timestamp := p_inizio at time zone public.fuso_orario();
  v_giorno smallint := extract(isodow from (p_inizio at time zone public.fuso_orario()));
  v_visita uuid;
begin
  select * into v_paz from public.pazienti
  where utente_id = (select auth.uid()) and stato = 'attivo';
  if not found then
    raise exception using errcode = 'CN007', message = 'Per prenotare devi essere collegato a un nutrizionista.';
  end if;

  if p_inizio <= now() then
    raise exception using errcode = 'CN005', message = 'Scegli un orario futuro.';
  end if;

  if not exists (
    select 1 from public.finestre_prenotazione f
    where f.paziente_id = v_paz.id and v_locale::date between f.dal and f.al
  ) then
    raise exception using errcode = 'CN005',
      message = 'La data è fuori dalla tua finestra di prenotazione.';
  end if;

  select durata_visita_min into v_durata from public.nutrizionisti where id = v_paz.nutrizionista_id;

  -- Lo slot deve stare in una fascia di disponibilità ed essere allineato alla
  -- durata della visita (gli slot partono dall'inizio della fascia).
  if not exists (
    select 1 from public.disponibilita d
    where d.nutrizionista_id = v_paz.nutrizionista_id
      and d.giorno_settimana = v_giorno
      and v_locale::time >= d.ora_inizio
      and (v_locale + make_interval(mins => v_durata))::time <= d.ora_fine
      and (v_locale + make_interval(mins => v_durata))::date = v_locale::date
      and (extract(epoch from (v_locale::time - d.ora_inizio))::integer / 60) % v_durata = 0
  ) then
    raise exception using errcode = 'CN005',
      message = 'L''orario scelto non è tra gli slot di ricevimento del nutrizionista.';
  end if;

  if exists (
    select 1 from public.visite
    where paziente_id = v_paz.id and stato in ('fissata', 'prenotata') and fine > now()
  ) then
    raise exception using errcode = 'CN004',
      message = 'Hai già una visita in programma: annullala prima di prenotarne un''altra.';
  end if;

  begin
    insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
    values (v_paz.nutrizionista_id, v_paz.id, p_inizio, v_durata, 'prenotata', 'paziente')
    returning id into v_visita;
  exception when exclusion_violation then
    if exists (select 1 from public.visite
               where paziente_id = v_paz.id and stato in ('fissata', 'prenotata') and fine > now()) then
      raise exception using errcode = 'CN004',
        message = 'Hai già una visita in programma: annullala prima di prenotarne un''altra.';
    end if;
    raise exception using errcode = 'CN003',
      message = 'Lo slot non è più disponibile: scegline un altro.';
  end;
  return v_visita;
end;
$$;

-- UC_GV_4 · RF_GV_9: il paziente annulla la propria visita fino a 24 ore prima.
create or replace function public.annulla_visita(p_visita uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_inizio timestamptz;
begin
  select v.inizio into v_inizio
  from public.visite v join public.pazienti p on p.id = v.paziente_id
  where v.id = p_visita and p.utente_id = (select auth.uid())
    and v.stato in ('fissata', 'prenotata')
  for update of v;
  if not found then
    raise exception using errcode = 'CN007', message = 'Visita non trovata o già annullata.';
  end if;
  if v_inizio - now() < make_interval(hours => public.ore_minime_annullamento()) then
    raise exception using errcode = 'CN006',
      message = format('Puoi annullare fino a %s ore prima: contatta il nutrizionista.',
                       public.ore_minime_annullamento());
  end if;
  update public.visite set stato = 'annullata', annullata_il = now() where id = p_visita;
end;
$$;

-- -----------------------------------------------------------------------------
-- Permessi sulle funzioni: di default Postgres le rende eseguibili da tutti.
-- -----------------------------------------------------------------------------
revoke execute on all functions in schema public from public, anon, authenticated;
revoke execute on all functions in schema privato from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon;
alter default privileges in schema privato revoke execute on functions from public, anon;

-- Funzioni usate dalle policy: le valuta l'utente autenticato. Stanno nello
-- schema privato, quindi non sono chiamabili come API.
grant execute on function
  privato.e_nutrizionista(), privato.nut_segue(uuid), privato.e_mio_collegamento(uuid),
  privato.e_mio_collegamento_attivo(uuid), privato.profilo_visibile(uuid),
  privato.nut_gestisce_piano(uuid), privato.piano_leggibile(uuid), privato.piano_in_bozza_del_nut(uuid),
  privato.piano_del_giorno(uuid), privato.piano_del_pasto(uuid), privato.piano_della_voce(uuid),
  privato.paziente_del_check_in(uuid)
to authenticated;
grant execute on function
  public.giorni_correzione_checkin(), public.limite_pazienti(text),
  public.giorni_validita_invito(), public.ore_minime_annullamento(), public.fuso_orario()
to authenticated;

-- RPC chiamabili dall'app (security definer VOLUTO: controllano il chiamante).
-- Il Security Advisor le segnala come "eseguibili da utenti autenticati": è
-- il comportamento previsto.
grant execute on function
  public.crea_invito(text), public.revoca_invito(uuid), public.anteprima_invito(text),
  public.accetta_invito(text), public.archivia_paziente(uuid), public.riattiva_paziente(uuid),
  public.scollega_paziente(), public.prenota_visita(timestamptz), public.annulla_visita(uuid)
to authenticated;
