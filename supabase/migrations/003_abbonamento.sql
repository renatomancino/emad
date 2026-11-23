-- =============================================================================
-- Cenato · 003_abbonamento.sql
-- Piani Free / Start / Pro: posti occupati in un solo punto, stato
-- dell'abbonamento e cambio piano con pagamento SIMULATO.
-- RF_GAD_4, RF_GAD_5, RF_GAD_7 · UC_GAD_3 · SC_GAD_2
-- Scheda Trello: [RM] Piani Free/Start/Pro, limiti e abbonamento simulato.
--
-- La stessa regola è in Dart in lib/domain/regole/limiti_piano.dart (con test):
--   Free  = pazienti che hanno accettato un invito (anche archiviati) + inviti in attesa
--   Start = pazienti attivi + inviti in attesa, al massimo 5
--   Pro   = nessun limite
-- =============================================================================

-- Prezzi in centesimi, IVA esclusa (CLAUDE.md regola 4, RF_GAD_5).
create or replace function public.prezzo_piano(p_piano text, p_periodo text)
returns integer language sql immutable set search_path = '' as $$
  select case p_piano
    when 'start' then case p_periodo when 'annuale' then 12000 else 1200 end
    when 'pro'   then case p_periodo when 'annuale' then 25000 else 2500 end
    else 0
  end;
$$;

-- Posti occupati secondo la regola del piano indicato (unico punto della regola).
create or replace function privato.posti_occupati(
  p_nutrizionista uuid, p_piano public.piano_abbonamento, p_includi_inviti boolean
)
returns integer language sql stable security definer set search_path = '' as $$
  select
    case when p_piano = 'free'
      then privato.pazienti_invitati_totali(p_nutrizionista)
      else (select count(*)::integer from public.pazienti
            where nutrizionista_id = p_nutrizionista and stato = 'attivo')
    end
    + case when p_includi_inviti
      then (select count(*)::integer from public.inviti
            where nutrizionista_id = p_nutrizionista and stato = 'creato' and scadenza >= now())
      else 0
    end;
$$;

-- verifica_limite_piano (002) ora usa posti_occupati: stessa regola ovunque.
create or replace function privato.verifica_limite_piano(p_nutrizionista uuid, p_includi_inviti boolean)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_piano public.piano_abbonamento;
  v_limite integer;
begin
  select piano_abbonamento into v_piano from public.nutrizionisti where id = p_nutrizionista;
  v_limite := public.limite_pazienti(v_piano::text);
  if v_limite is null then
    return;
  end if;

  if privato.posti_occupati(p_nutrizionista, v_piano, p_includi_inviti) >= v_limite then
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

-- UC_GAD_3: stato dell'abbonamento per la schermata del nutrizionista.
create or replace function public.stato_abbonamento()
returns table (
  piano public.piano_abbonamento,
  periodo public.periodo_fatturazione,
  limite integer,
  pazienti_attivi integer,
  pazienti_collegati_totali integer,
  inviti_in_attesa integer,
  posti_occupati integer,
  puo_invitare boolean
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  v_nut uuid := (select auth.uid());
  v_piano public.piano_abbonamento;
  v_periodo public.periodo_fatturazione;
  v_limite integer;
  v_occupati integer;
begin
  if not privato.e_nutrizionista() then
    raise exception using errcode = 'CN007', message = 'Solo un nutrizionista ha un abbonamento.';
  end if;
  select n.piano_abbonamento, n.periodo_fatturazione into v_piano, v_periodo
  from public.nutrizionisti n where n.id = v_nut;
  v_limite := public.limite_pazienti(v_piano::text);
  v_occupati := privato.posti_occupati(v_nut, v_piano, true);

  return query select
    v_piano, v_periodo, v_limite,
    (select count(*)::integer from public.pazienti p where p.nutrizionista_id = v_nut and p.stato = 'attivo'),
    privato.pazienti_invitati_totali(v_nut),
    (select count(*)::integer from public.inviti i
     where i.nutrizionista_id = v_nut and i.stato = 'creato' and i.scadenza >= now()),
    v_occupati,
    v_limite is null or v_occupati < v_limite;
end;
$$;

-- UC_GAD_3, RF_GAD_5: cambio piano con pagamento SIMULATO (nessun addebito).
-- Il declassamento è bloccato se i posti occupati superano il nuovo limite.
create or replace function public.cambia_piano(
  p_piano public.piano_abbonamento, p_periodo public.periodo_fatturazione default null
)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_nut uuid := (select auth.uid());
  v_attuale public.piano_abbonamento;
  v_periodo public.periodo_fatturazione := case when p_piano = 'free' then null else p_periodo end;
  v_limite integer := public.limite_pazienti(p_piano::text);
  v_occupati integer;
begin
  if not privato.e_nutrizionista() then
    raise exception using errcode = 'CN007', message = 'Solo un nutrizionista può cambiare piano.';
  end if;
  if p_piano <> 'free' and v_periodo is null then
    raise exception using errcode = 'CN007', message = 'Scegli la fatturazione mensile o annuale.';
  end if;

  select piano_abbonamento into v_attuale from public.nutrizionisti where id = v_nut for update;

  if v_limite is not null then
    v_occupati := privato.posti_occupati(v_nut, p_piano, true);
    if v_occupati > v_limite then
      raise exception using
        errcode = 'CN001',
        message = format('Non puoi passare al piano %s: occupi %s posti e il limite è %s.',
                         initcap(p_piano::text), v_occupati, v_limite),
        detail = p_piano::text,
        hint = case p_piano
          when 'free' then 'Il piano Free conta tutti i pazienti che hanno accettato un invito, anche archiviati.'
          else 'Archivia qualche paziente o revoca gli inviti in attesa, poi riprova.'
        end;
    end if;
  end if;

  update public.abbonamenti set fine = now() where nutrizionista_id = v_nut and fine is null;
  insert into public.abbonamenti (nutrizionista_id, piano, periodo_fatturazione, importo_cent, pagamento_simulato)
  values (v_nut, p_piano, v_periodo, public.prezzo_piano(p_piano::text, v_periodo::text), true);
  update public.nutrizionisti
  set piano_abbonamento = p_piano, periodo_fatturazione = v_periodo
  where id = v_nut;
end;
$$;

revoke execute on function public.prezzo_piano(text, text), public.stato_abbonamento(),
  public.cambia_piano(public.piano_abbonamento, public.periodo_fatturazione),
  privato.posti_occupati(uuid, public.piano_abbonamento, boolean)
from public, anon;
grant execute on function public.prezzo_piano(text, text), public.stato_abbonamento(),
  public.cambia_piano(public.piano_abbonamento, public.periodo_fatturazione)
to authenticated;
