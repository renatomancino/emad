-- =============================================================================
-- Cenato · test del codice a barre degli alimenti (009)
-- Unicità per fonte e per nutrizionista, ricerca per codice · RF_GP_4, RF_GP_5, UC_GP_3.
-- Richiede 001, 002, 006, 007 e 009.
-- Come rls.sql: nel SQL Editor, in una transazione annullata (ROLLBACK).
-- Ogni riga deve avere esito OK.
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
  nut_a uuid := gen_random_uuid();
  nut_b uuid := gen_random_uuid();
  u_a1 uuid := gen_random_uuid();
  r text; c bigint;
  ins_pers text := 'insert into public.alimenti (nome, codice_barre, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da) values (%L, %L, 100, 1, 1, 1, ''personalizzato'', %L)';
  ins_off text := 'insert into public.alimenti (nome, codice_barre, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte) values (%L, %L, 100, 1, 1, 1, ''open_food_facts'')';
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@cb.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@cb.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_a1,  'paz.a1@cb.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A1"}');

  -- ----------------------------------------------- Open Food Facts: unico
  r := pg_temp.esegui(nut_a, format(ins_off, 'Yogurt OFF', '8000000000132'));
  perform pg_temp.registra('NUT A', 'Salva in cache un prodotto scansionato', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_b, format(ins_off, 'Yogurt OFF doppio', '8000000000132'));
  perform pg_temp.registra('NUT B', 'Non duplica nella cache lo stesso codice di Open Food Facts', '23505', r, r like '23505%');
  c := pg_temp.conta(nut_b, 'select count(*) from public.alimenti where codice_barre = ''8000000000132''');
  perform pg_temp.registra('NUT B', 'Trova in cache il codice salvato da NUT A', '1', c::text, c = 1);

  -- -------------------------------------- personalizzati: per nutrizionista
  r := pg_temp.esegui(nut_a, format(ins_pers, 'Sconosciuto di A', '8000000000149', nut_a));
  perform pg_temp.registra('NUT A', 'Inserisce a mano un prodotto con il codice letto', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_b, format(ins_pers, 'Sconosciuto di B', '8000000000149', nut_b));
  perform pg_temp.registra('NUT B', 'Inserisce a mano lo stesso codice (non vede quello di A)', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, format(ins_pers, 'Doppione di A', '8000000000149', nut_a));
  perform pg_temp.registra('NUT A', 'Non inserisce due volte lo stesso codice', '23505', r, r like '23505%');
  c := pg_temp.conta(nut_a, 'select count(*) from public.alimenti where codice_barre = ''8000000000149''');
  perform pg_temp.registra('NUT A', 'Cercando il codice vede solo il proprio personalizzato', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.alimenti where codice_barre = ''8000000000149''');
  perform pg_temp.registra('PAZ A1', 'Non vede i personalizzati fuori dal proprio piano', '0', c::text, c = 0);

  -- ---------------------------- stesso codice tra personalizzato e OFF
  r := pg_temp.esegui(nut_b, format(ins_off, 'Ora su OFF', '8000000000149'));
  perform pg_temp.registra('NUT B', 'Salva da OFF un codice già inserito a mano da altri', 'ok', r, r = 'ok');
  c := pg_temp.conta(nut_a, 'select count(*) from public.alimenti where codice_barre = ''8000000000149''');
  perform pg_temp.registra('NUT A', 'Cercando il codice vede il proprio e quello di OFF', '2', c::text, c = 2);

  -- ------------------------------------------- senza codice: nessun limite
  r := pg_temp.esegui(nut_a, format(ins_pers, 'Senza codice 1', null, nut_a));
  r := r || '/' || pg_temp.esegui(nut_a, format(ins_pers, 'Senza codice 2', null, nut_a));
  perform pg_temp.registra('NUT A', 'Più personalizzati senza codice', 'ok/ok', r, r = 'ok/ok');

  -- ------------------------------------------------- formato del codice
  r := pg_temp.esegui(nut_a, format(ins_pers, 'Codice sbagliato', '12AB', nut_a));
  perform pg_temp.registra('NUT A', 'Rifiuta un codice non numerico', '23514', r, r like '23514%');
end $$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
