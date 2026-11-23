-- =============================================================================
-- Cenato · test delle policy RLS e delle RPC (002_rls.sql)
-- Esegui nel SQL Editor dopo le migrazioni: tutto avviene in una transazione
-- annullata (ROLLBACK), quindi non lascia dati. Ogni riga deve avere esito OK.
--
-- Come funziona: crea 2 nutrizionisti e 3 pazienti di prova, poi esegue le
-- query "come" ciascun utente impostando il ruolo `authenticated` (o `anon`) e
-- il JWT (request.jwt.claims), cioè come farebbe l'app con quell'account.
-- Esito riportato in docs/test-rls.md.
-- =============================================================================
begin;

create temp table esiti (n serial, utente text, prova text, atteso text, ottenuto text, esito text) on commit drop;

-- Esegue una query di conteggio come un utente; -1 se l'accesso è negato.
create or replace function pg_temp.conta(p_uid uuid, p_sql text) returns bigint language plpgsql as $f$
declare v bigint;
begin
  if p_uid is null then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
  begin
    execute p_sql into v;
  exception when insufficient_privilege then
    v := -1;
  end;
  execute 'reset role';
  return v;
end $f$;

-- Esegue un comando come un utente; restituisce 'ok' oppure SQLSTATE: messaggio.
create or replace function pg_temp.esegui(p_uid uuid, p_sql text) returns text language plpgsql as $f$
declare r text := 'ok';
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  begin
    execute p_sql;
  exception when others then
    r := sqlstate || ': ' || sqlerrm;
  end;
  execute 'reset role';
  return r;
end $f$;

create or replace function pg_temp.registra(p_utente text, p_prova text, p_atteso text, p_ottenuto text, p_ok boolean)
returns void language sql as $f$
  insert into esiti (utente, prova, atteso, ottenuto, esito)
  values (p_utente, p_prova, p_atteso, p_ottenuto, case when p_ok then 'OK' else 'KO' end);
$f$;

do $$
declare
  nut_a uuid := gen_random_uuid();   -- piano Pro, pazienti A1 e A2
  nut_b uuid := gen_random_uuid();   -- piano Free, paziente B1
  u_a1 uuid := gen_random_uuid();
  u_a2 uuid := gen_random_uuid();
  u_b1 uuid := gen_random_uuid();
  u_nuovo uuid := gen_random_uuid(); -- paziente senza nutrizionista
  paz_a1 uuid; paz_a2 uuid; paz_b1 uuid;
  piano_a1 uuid; piano_b1 uuid; giorno uuid; pasto_a1 uuid; pasto_b1 uuid; alim uuid; ci_a1 uuid;
  oggi_dow smallint := extract(isodow from current_date);
  slot timestamptz := ((current_date + 3)::timestamp + time '09:30') at time zone 'Europe/Rome';
  r text; c bigint;
begin
  -- ---------------------------------------------------------------- dati
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@rls.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@rls.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_a1,  'paz.a1@rls.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A1"}'),
    (u_a2,  'paz.a2@rls.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A2"}'),
    (u_b1,  'paz.b1@rls.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz B1"}'),
    (u_nuovo, 'paz.nuovo@rls.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz Nuovo"}');
  update public.nutrizionisti set piano_abbonamento = 'pro', periodo_fatturazione = 'annuale' where id = nut_a;

  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento) values
    (nut_a, u_a1, 'attivo', now()) returning id into paz_a1;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento) values
    (nut_a, u_a2, 'attivo', now()) returning id into paz_a2;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento) values
    (nut_b, u_b1, 'attivo', now()) returning id into paz_b1;

  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Yogurt bianco', 61, 3.5, 4.7, 3.3, 'open_food_facts') returning id into alim;

  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
    values (paz_a1, nut_a, 1, 'corrente', current_date - 7) returning id into piano_a1;
  insert into public.giorni (piano_id, giorno_settimana) values (piano_a1, oggi_dow) returning id into giorno;
  insert into public.pasti (giorno_id, tipo) values (giorno, 'colazione') returning id into pasto_a1;
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g)
    values (pasto_a1, alim, 125, 76, 4.4, 5.9, 4.1);

  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
    values (paz_b1, nut_b, 1, 'corrente', current_date - 7) returning id into piano_b1;
  insert into public.giorni (piano_id, giorno_settimana) values (piano_b1, oggi_dow) returning id into giorno;
  insert into public.pasti (giorno_id, tipo) values (giorno, 'colazione') returning id into pasto_b1;

  insert into public.check_in (paziente_id, pasto_id, data, stato) values (paz_a1, pasto_a1, current_date, 'seguito') returning id into ci_a1;
  insert into public.check_in (paziente_id, pasto_id, data, stato) values (paz_b1, pasto_b1, current_date, 'saltato');
  insert into public.misure_peso (paziente_id, data, valore_kg) values (paz_a1, current_date, 80), (paz_b1, current_date, 70);
  insert into public.obiettivi (paziente_id, kcal, proteine_g, carboidrati_g, grassi_g) values (paz_a1, 2000, 110, 230, 65), (paz_b1, 1800, 90, 200, 60);
  insert into public.commenti (check_in_id, nutrizionista_id, testo) values (ci_a1, nut_a, 'Ottimo!');
  insert into public.disponibilita (nutrizionista_id, giorno_settimana, ora_inizio, ora_fine)
    select nut_a, g, '08:00', '20:00' from generate_series(1, 7) g;
  insert into public.finestre_prenotazione (paziente_id, dal, al) values
    (paz_a1, current_date, current_date + 30), (paz_a2, current_date, current_date + 30);

  -- ------------------------------------------------------- utente anonimo
  c := pg_temp.conta(null, 'select count(*) from public.pazienti');
  perform pg_temp.registra('anonimo', 'Non legge i pazienti', 'negato', c::text, c <= 0);
  c := pg_temp.conta(null, 'select count(*) from public.check_in');
  perform pg_temp.registra('anonimo', 'Non legge i check-in', 'negato', c::text, c <= 0);
  c := pg_temp.conta(null, 'select count(*) from public.profili');
  perform pg_temp.registra('anonimo', 'Non legge i profili', 'negato', c::text, c <= 0);
  c := pg_temp.conta(null, 'select count(*) from public.alimenti');
  perform pg_temp.registra('anonimo', 'Non legge la cache alimenti', 'negato', c::text, c <= 0);

  -- ------------------------------------------------------- nutrizionista A
  c := pg_temp.conta(nut_a, 'select count(*) from public.pazienti');
  perform pg_temp.registra('NUT A', 'Vede solo i propri pazienti', '2', c::text, c = 2);
  c := pg_temp.conta(nut_a, format('select count(*) from public.check_in where paziente_id = %L', paz_b1));
  perform pg_temp.registra('NUT A', 'Non legge i check-in di un paziente non suo', '0', c::text, c = 0);
  c := pg_temp.conta(nut_a, format('select count(*) from public.check_in where paziente_id = %L', paz_a1));
  perform pg_temp.registra('NUT A', 'Legge i check-in del proprio paziente', '1', c::text, c = 1);
  c := pg_temp.conta(nut_a, format('select count(*) from public.misure_peso where paziente_id = %L', paz_b1));
  perform pg_temp.registra('NUT A', 'Non legge il peso di un paziente non suo', '0', c::text, c = 0);
  c := pg_temp.conta(nut_a, format('select count(*) from public.profili where id = %L', u_b1));
  perform pg_temp.registra('NUT A', 'Non legge il profilo di un paziente non suo', '0', c::text, c = 0);
  c := pg_temp.conta(nut_a, format('select count(*) from public.profili where id = %L', u_a1));
  perform pg_temp.registra('NUT A', 'Legge il nome del proprio paziente', '1', c::text, c = 1);
  c := pg_temp.conta(nut_a, format('select count(*) from public.piani where paziente_id = %L', paz_b1));
  perform pg_temp.registra('NUT A', 'Non legge il piano di un paziente non suo', '0', c::text, c = 0);
  r := pg_temp.esegui(nut_a, format('insert into public.obiettivi (paziente_id, kcal, proteine_g, carboidrati_g, grassi_g) values (%L, 2000, 100, 200, 60)', paz_b1));
  perform pg_temp.registra('NUT A', 'Non scrive obiettivi per un paziente non suo', 'negato', r, r like '42501%');
  r := pg_temp.esegui(nut_a, format('insert into public.obiettivi (paziente_id, kcal, proteine_g, carboidrati_g, grassi_g) values (%L, 2100, 110, 230, 65)', paz_a1));
  perform pg_temp.registra('NUT A', 'Scrive obiettivi per il proprio paziente', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, format('delete from public.check_in where id = %L', ci_a1));
  perform pg_temp.registra('NUT A', 'Non cancella dati clinici (check-in)', 'negato', r, r like '42501%');
  r := pg_temp.esegui(nut_a, format('update public.check_in set stato = %L where id = %L', 'saltato', ci_a1));
  c := pg_temp.conta(nut_a, format('select count(*) from public.check_in where id = %L and stato = %L', ci_a1, 'saltato'));
  perform pg_temp.registra('NUT A', 'Non modifica i check-in del paziente', '0 righe modificate', c::text, c = 0);
  r := pg_temp.esegui(nut_a, format('update public.pazienti set stato = %L where id = %L', 'archiviato', paz_a1));
  perform pg_temp.registra('NUT A', 'Non cambia lo stato del paziente senza RPC', 'negato', r, r like '42501%');
  r := pg_temp.esegui(nut_a, format('update public.nutrizionisti set piano_abbonamento = %L where id = %L', 'pro', nut_a));
  perform pg_temp.registra('NUT A', 'Non cambia il proprio piano senza RPC', 'negato', r, r like '42501%');

  -- ------------------------------------------------------- nutrizionista B (Free)
  c := pg_temp.conta(nut_b, format('select count(*) from public.commenti'));
  perform pg_temp.registra('NUT B', 'Non legge i commenti di un altro nutrizionista', '0', c::text, c = 0);
  r := pg_temp.esegui(nut_b, 'select * from public.crea_invito(''Nuovo paziente'')');
  perform pg_temp.registra('NUT B', 'Free con 1 paziente: invito bloccato (RF_GAD_7)', 'CN001', r, r like 'CN001: Hai raggiunto il limite del piano Free%');
  r := pg_temp.esegui(nut_a, 'select * from public.crea_invito(''Nuovo paziente'')');
  perform pg_temp.registra('NUT A', 'Pro: invito creato', 'ok', r, r = 'ok');

  -- ------------------------------------------------------- paziente A1
  c := pg_temp.conta(u_a1, 'select count(*) from public.check_in');
  perform pg_temp.registra('PAZ A1', 'Vede solo i propri check-in', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.misure_peso');
  perform pg_temp.registra('PAZ A1', 'Vede solo il proprio peso', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.pazienti');
  perform pg_temp.registra('PAZ A1', 'Non vede gli altri pazienti', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, format('select count(*) from public.profili where id = %L', u_a2));
  perform pg_temp.registra('PAZ A1', 'Non legge il profilo di un altro paziente', '0', c::text, c = 0);
  c := pg_temp.conta(u_a1, format('select count(*) from public.profili where id = %L', nut_a));
  perform pg_temp.registra('PAZ A1', 'Legge il nome del proprio nutrizionista', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, format('select count(*) from public.profili where id = %L', nut_b));
  perform pg_temp.registra('PAZ A1', 'Non legge un altro nutrizionista', '0', c::text, c = 0);
  c := pg_temp.conta(u_a1, 'select count(*) from public.piani');
  perform pg_temp.registra('PAZ A1', 'Legge solo il proprio piano', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.commenti');
  perform pg_temp.registra('PAZ A1', 'Legge i commenti ai propri check-in', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.inviti');
  perform pg_temp.registra('PAZ A1', 'Non legge gli inviti', '0', c::text, c = 0);
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato) values (%L, %L, current_date, %L)', paz_b1, pasto_b1, 'seguito'));
  -- Rifiutato dalla RLS (42501) o, prima ancora, dal trigger di verifica che non
  -- trova il pasto tra quelli visibili al paziente (23514): in entrambi i casi
  -- la riga non viene scritta.
  perform pg_temp.registra('PAZ A1', 'Non scrive check-in per un altro paziente', 'negato', r, r like '42501%' or r like '23514%');
  c := pg_temp.conta(nut_b, format('select count(*) from public.check_in where paziente_id = %L', paz_b1));
  perform pg_temp.registra('NUT B', 'Il check-in di B1 è rimasto uno solo', '1', c::text, c = 1);
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato) values (%L, %L, current_date - 3, %L)', paz_a1, pasto_a1, 'seguito'));
  perform pg_temp.registra('PAZ A1', 'Non registra check-in di 3 giorni fa (RF_GD_3)', 'negato', r, r like '42501%');
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato) values (%L, %L, current_date - 1, %L)', paz_a1, pasto_a1, 'fuori_piano'));
  perform pg_temp.registra('PAZ A1', 'Registra il check-in di ieri', 'ok', r, r = 'ok');
  r := pg_temp.esegui(u_a1, format('update public.profili set ruolo = %L where id = %L', 'nutrizionista', u_a1));
  perform pg_temp.registra('PAZ A1', 'Non cambia il proprio ruolo', 'negato', r, r like '42501%');
  r := pg_temp.esegui(u_a1, format('update public.pazienti set nutrizionista_id = %L where id = %L', nut_b, paz_a1));
  perform pg_temp.registra('PAZ A1', 'Non cambia il proprio nutrizionista', 'negato', r, r like '42501%');
  r := pg_temp.esegui(u_a1, format('insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine) values (%L, %L, %L, 45, %L, %L)', nut_a, paz_a1, slot, 'prenotata', 'paziente'));
  perform pg_temp.registra('PAZ A1', 'Non inserisce visite senza RPC', 'negato', r, r like '42501%');
  r := pg_temp.esegui(u_a1, format('select public.prenota_visita(%L)', slot + interval '40 days'));
  perform pg_temp.registra('PAZ A1', 'Prenotazione fuori finestra rifiutata', 'CN005', r, r like 'CN005%');
  r := pg_temp.esegui(u_a1, format('select public.prenota_visita(%L)', slot + interval '10 minutes'));
  perform pg_temp.registra('PAZ A1', 'Orario non allineato agli slot rifiutato', 'CN005', r, r like 'CN005%');
  r := pg_temp.esegui(u_a1, format('select public.prenota_visita(%L)', slot));
  perform pg_temp.registra('PAZ A1', 'Prenota uno slot libero (RF_GV_8)', 'ok', r, r = 'ok');
  r := pg_temp.esegui(u_a1, format('select public.prenota_visita(%L)', slot + interval '1 day'));
  perform pg_temp.registra('PAZ A1', 'Seconda visita futura rifiutata', 'CN004', r, r like 'CN004%');

  -- ------------------------------------------------------- paziente A2
  r := pg_temp.esegui(u_a2, format('select public.prenota_visita(%L)', slot));
  perform pg_temp.registra('PAZ A2', 'Slot già preso da A1 rifiutato (RNF_A_6)', 'CN003', r, r like 'CN003%');
  c := pg_temp.conta(u_a2, 'select count(*) from public.visite');
  perform pg_temp.registra('PAZ A2', 'Non vede la visita di A1', '0', c::text, c = 0);

  -- ------------------------------------------------------- paziente senza nutrizionista
  r := pg_temp.esegui(u_nuovo, 'select public.accetta_invito(''ZZZZZZZZ'')');
  perform pg_temp.registra('PAZ nuovo', 'Codice inesistente rifiutato', 'CN010', r, r like 'CN010%');
  r := pg_temp.esegui(u_nuovo, format('select public.accetta_invito(%L)', (select codice from public.inviti where nutrizionista_id = nut_a limit 1)));
  perform pg_temp.registra('PAZ nuovo', 'Accetta l''invito di NUT A', 'ok', r, r = 'ok');
  c := pg_temp.conta(nut_a, 'select count(*) from public.pazienti where stato = ''attivo''');
  perform pg_temp.registra('NUT A', 'Vede il nuovo paziente Attivo', '3', c::text, c = 3);

  -- ------------------------------------------------------- scollegamento
  r := pg_temp.esegui(u_a1, 'select public.scollega_paziente()');
  perform pg_temp.registra('PAZ A1', 'Si scollega (RF_GI_7)', 'ok', r, r = 'ok');
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato) values (%L, %L, current_date, %L)', paz_a1, pasto_a1, 'alternativa'));
  perform pg_temp.registra('PAZ A1', 'Dopo lo scollegamento non scrive check-in', 'negato', r, r like '42501%' or r like '23%');
  c := pg_temp.conta(nut_a, format('select count(*) from public.check_in where paziente_id = %L', paz_a1));
  perform pg_temp.registra('NUT A', 'Conserva lo storico del paziente archiviato', '2', c::text, c = 2);
  c := pg_temp.conta(nut_a, format('select count(*) from public.visite where paziente_id = %L and stato = %L', paz_a1, 'annullata'));
  perform pg_temp.registra('NUT A', 'Visita futura annullata allo scollegamento', '1', c::text, c = 1);
  r := pg_temp.esegui(nut_a, format('select public.riattiva_paziente(%L)', paz_a1));
  perform pg_temp.registra('NUT A', 'Non riattiva chi si è scollegato da solo', 'CN009', r, r like 'CN009%');
end;
$$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
