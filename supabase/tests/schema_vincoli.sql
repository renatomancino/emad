-- =============================================================================
-- Cenato · test dei vincoli dello schema (001_schema.sql)
-- Esegui nel SQL Editor: lavora in una transazione annullata (ROLLBACK),
-- quindi non lascia dati. Ogni riga del risultato deve avere esito = 'OK'.
-- =============================================================================
begin;

create temp table esiti (n serial, prova text, esito text) on commit drop;

do $$
declare
  nut uuid := gen_random_uuid();
  nut2 uuid := gen_random_uuid();
  paz_u uuid := gen_random_uuid();
  paz uuid;
  paz2 uuid;
  piano uuid; giorno uuid; pasto uuid; pasto_altro uuid; voce uuid; alt uuid; alim uuid;
  domani timestamptz := date_trunc('hour', now()) + interval '1 day';
begin
  -- Utenti: il trigger crea profili e, per il nutrizionista, piano Free.
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut,  'test.nut@vincoli.local',  '{"ruolo":"nutrizionista","nome":"Nut Test"}'),
    (nut2, 'test.nut2@vincoli.local', '{"ruolo":"nutrizionista","nome":"Nut Due"}'),
    (paz_u,'test.paz@vincoli.local',  '{"ruolo":"paziente","nome":"Paz Test"}');

  insert into esiti (prova, esito) select 'Profilo e piano Free creati alla registrazione',
    case when (select piano_abbonamento from public.nutrizionisti where id = nut) = 'free'
          and (select ruolo from public.profili where id = paz_u) = 'paziente' then 'OK' else 'KO' end;

  -- Ruolo non modificabile
  begin
    update public.profili set ruolo = 'nutrizionista' where id = paz_u;
    insert into esiti (prova, esito) values ('Ruolo non modificabile', 'KO');
  exception when insufficient_privilege then
    insert into esiti (prova, esito) values ('Ruolo non modificabile', 'OK');
  end;

  -- Registrazione senza ruolo rifiutata
  begin
    insert into auth.users (id, email, raw_user_meta_data) values (gen_random_uuid(), 'senza.ruolo@vincoli.local', '{}');
    insert into esiti (prova, esito) values ('Registrazione senza ruolo rifiutata', 'KO');
  exception when invalid_parameter_value then
    insert into esiti (prova, esito) values ('Registrazione senza ruolo rifiutata', 'OK');
  end;

  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut, paz_u, 'attivo', now()) returning id into paz;

  -- Un paziente collegato non si elimina
  begin
    delete from public.pazienti where id = paz;
    insert into esiti (prova, esito) values ('Paziente collegato non eliminabile', 'KO');
  exception when insufficient_privilege then
    insert into esiti (prova, esito) values ('Paziente collegato non eliminabile', 'OK');
  end;

  -- Un solo collegamento aperto per persona
  begin
    insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento) values (nut2, paz_u, 'attivo', now());
    insert into esiti (prova, esito) values ('Un solo nutrizionista alla volta', 'KO');
  exception when unique_violation then
    insert into esiti (prova, esito) values ('Un solo nutrizionista alla volta', 'OK');
  end;

  -- Piano: una sola versione corrente
  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
    values (paz, nut, 1, 'corrente', current_date) returning id into piano;
  begin
    insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio) values (paz, nut, 2, 'corrente', current_date);
    insert into esiti (prova, esito) values ('Una sola versione corrente del piano', 'KO');
  exception when unique_violation then
    insert into esiti (prova, esito) values ('Una sola versione corrente del piano', 'OK');
  end;

  insert into public.giorni (piano_id, giorno_settimana) values (piano, 1) returning id into giorno;
  insert into public.pasti (giorno_id, tipo) values (giorno, 'colazione') returning id into pasto;
  insert into public.pasti (giorno_id, tipo) values (giorno, 'pranzo') returning id into pasto_altro;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Prova', 100, 1, 1, 1, 'personalizzato') returning id into alim;
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g)
    values (pasto_altro, alim, 100, 100, 1, 1, 1) returning id into voce;
  insert into public.alternative (voce_id, alimento_id, quantita_g) values (voce, alim, 50) returning id into alt;

  -- Check-in: unico per pasto e giorno
  insert into public.check_in (paziente_id, pasto_id, data, stato) values (paz, pasto, current_date, 'seguito');
  begin
    insert into public.check_in (paziente_id, pasto_id, data, stato) values (paz, pasto, current_date, 'saltato');
    insert into esiti (prova, esito) values ('Un solo check-in per pasto e giorno', 'KO');
  exception when unique_violation then
    insert into esiti (prova, esito) values ('Un solo check-in per pasto e giorno', 'OK');
  end;

  -- Check-in: l'alternativa deve essere del pasto
  begin
    insert into public.check_in (paziente_id, pasto_id, data, stato, alternativa_id)
      values (paz, pasto, current_date - 1, 'alternativa', alt);
    insert into esiti (prova, esito) values ('Alternativa solo tra quelle del pasto', 'KO');
  exception when check_violation then
    insert into esiti (prova, esito) values ('Alternativa solo tra quelle del pasto', 'OK');
  end;

  -- Visite: slot unico per il nutrizionista
  insert into public.pazienti (nutrizionista_id, stato, nome) values (nut, 'invitato', 'Altro') returning id into paz2;
  insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
    values (nut, paz, domani, 45, 'prenotata', 'paziente');
  begin
    insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
      values (nut, paz2, domani + interval '15 minutes', 45, 'fissata', 'nutrizionista');
    insert into esiti (prova, esito) values ('Slot non prenotabile due volte (RNF_A_6)', 'KO');
  exception when exclusion_violation then
    insert into esiti (prova, esito) values ('Slot non prenotabile due volte (RNF_A_6)', 'OK');
  end;

  -- Visite: una sola visita futura per paziente
  begin
    insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
      values (nut, paz, domani + interval '3 days', 45, 'fissata', 'nutrizionista');
    insert into esiti (prova, esito) values ('Una sola visita futura per paziente (RF_GV_8)', 'KO');
  exception when exclusion_violation then
    insert into esiti (prova, esito) values ('Una sola visita futura per paziente (RF_GV_8)', 'OK');
  end;

  -- Dopo l'annullamento lo slot torna libero (SCD_2)
  update public.visite set stato = 'annullata', annullata_il = now() where paziente_id = paz;
  insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
    values (nut, paz2, domani, 45, 'fissata', 'nutrizionista');
  insert into esiti (prova, esito) values ('Slot di nuovo libero dopo l''annullamento', 'OK');

  -- Visita con paziente di un altro nutrizionista
  begin
    insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine)
      values (nut2, paz, domani + interval '10 days', 45, 'fissata', 'nutrizionista');
    insert into esiti (prova, esito) values ('Visita solo con i propri pazienti', 'KO');
  exception when check_violation then
    insert into esiti (prova, esito) values ('Visita solo con i propri pazienti', 'OK');
  end;

  -- Limiti dei piani in un solo punto
  insert into esiti (prova, esito) select 'Limiti Free 1 / Start 5 / Pro illimitato',
    case when public.limite_pazienti('free') = 1 and public.limite_pazienti('start') = 5
          and public.limite_pazienti('pro') is null then 'OK' else 'KO' end;

  insert into esiti (prova, esito) select 'Contatore pazienti invitati (Free)',
    case when privato.pazienti_invitati_totali(nut) = 1 then 'OK' else 'KO' end;
end;
$$;

select n, prova, esito from esiti order by n;

rollback;
