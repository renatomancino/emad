-- =============================================================================
-- Cenato · test della visibilità degli alimenti (007)
-- Chi vede e chi modifica la cache `alimenti` · RF_GP_3, RF_GP_5, RNF_IN_1.
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
  u_a1 uuid := gen_random_uuid();   -- paziente di A
  u_b1 uuid := gen_random_uuid();   -- paziente di B
  paz_a1 uuid; paz_b1 uuid;
  piano_a uuid; piano_bozza uuid; giorno uuid; giorno_b uuid; pasto uuid; pasto_b uuid; voce uuid;
  off uuid; torta_a uuid; alt_a uuid; solo_bozza uuid; non_in_piano uuid; seed uuid; pasta_b uuid;
  r text; c bigint;
  oggi_dow smallint := extract(isodow from current_date);
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@vis.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@vis.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_a1,  'paz.a1@vis.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A1"}'),
    (u_b1,  'paz.b1@vis.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz B1"}');
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_a, u_a1, 'attivo', now()) returning id into paz_a1;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_b, u_b1, 'attivo', now()) returning id into paz_b1;

  -- alimenti: uno di Open Food Facts, personalizzati di A e di B, uno senza proprietario (seed)
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Cache OFF', 100, 1, 1, 1, 'open_food_facts') returning id into off;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Torta di A', 300, 5, 40, 10, 'personalizzato', nut_a) returning id into torta_a;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Alternativa di A', 300, 5, 40, 10, 'personalizzato', nut_a) returning id into alt_a;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Solo in bozza di A', 300, 5, 40, 10, 'personalizzato', nut_a) returning id into solo_bozza;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Non in piano di A', 300, 5, 40, 10, 'personalizzato', nut_a) returning id into non_in_piano;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Pasta di B', 300, 5, 40, 10, 'personalizzato', nut_b) returning id into pasta_b;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Senza proprietario (seed)', 300, 5, 40, 10, 'personalizzato') returning id into seed;

  -- piano corrente di A1 con "Torta di A" come voce e "Alternativa di A" come alternativa
  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
    values (paz_a1, nut_a, 1, 'corrente', current_date - 7) returning id into piano_a;
  insert into public.giorni (piano_id, giorno_settimana) values (piano_a, oggi_dow) returning id into giorno;
  insert into public.pasti (giorno_id, tipo) values (giorno, 'colazione') returning id into pasto;
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g)
    values (pasto, torta_a, 100, 300, 5, 40, 10) returning id into voce;
  insert into public.alternative (voce_id, alimento_id, quantita_g) values (voce, alt_a, 100);

  -- una versione in bozza (non visibile al paziente) con "Solo in bozza di A"
  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
    values (paz_a1, nut_a, 2, 'bozza', current_date) returning id into piano_bozza;
  insert into public.giorni (piano_id, giorno_settimana) values (piano_bozza, oggi_dow) returning id into giorno_b;
  insert into public.pasti (giorno_id, tipo) values (giorno_b, 'colazione') returning id into pasto_b;
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g)
    values (pasto_b, solo_bozza, 100, 300, 5, 40, 10);

  -- ------------------------------------------------------------ lettura
  c := pg_temp.conta(null, 'select count(*) from public.alimenti');
  perform pg_temp.registra('anonimo', 'Non legge la cache alimenti', 'negato', c::text, c <= 0);

  c := pg_temp.conta(nut_a, format('select count(*) from public.alimenti where id = %L', off));
  perform pg_temp.registra('NUT A', 'Vede gli alimenti di Open Food Facts', '1', c::text, c = 1);
  c := pg_temp.conta(nut_b, format('select count(*) from public.alimenti where id = %L', off));
  perform pg_temp.registra('NUT B', 'Vede gli alimenti di Open Food Facts', '1', c::text, c = 1);

  c := pg_temp.conta(nut_a, format('select count(*) from public.alimenti where id = %L', torta_a));
  perform pg_temp.registra('NUT A', 'Vede i propri alimenti personalizzati', '1', c::text, c = 1);
  c := pg_temp.conta(nut_b, format('select count(*) from public.alimenti where id in (%L, %L, %L)', torta_a, alt_a, non_in_piano));
  perform pg_temp.registra('NUT B', 'Non vede gli alimenti personalizzati di NUT A', '0', c::text, c = 0);
  c := pg_temp.conta(nut_a, format('select count(*) from public.alimenti where id = %L', pasta_b));
  perform pg_temp.registra('NUT A', 'Non vede gli alimenti personalizzati di NUT B', '0', c::text, c = 0);

  c := pg_temp.conta(nut_a, format('select count(*) from public.alimenti where id = %L', seed));
  perform pg_temp.registra('NUT A', 'Vede gli alimenti senza proprietario (seed)', '1', c::text, c = 1);
  c := pg_temp.conta(nut_b, format('select count(*) from public.alimenti where id = %L', seed));
  perform pg_temp.registra('NUT B', 'Vede gli alimenti senza proprietario (seed)', '1', c::text, c = 1);

  c := pg_temp.conta(u_a1, format('select count(*) from public.alimenti where id = %L', torta_a));
  perform pg_temp.registra('PAZ A1', 'Vede l''alimento personalizzato nel proprio piano', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, format('select count(*) from public.alimenti where id = %L', alt_a));
  perform pg_temp.registra('PAZ A1', 'Vede l''alimento personalizzato usato come alternativa', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, format('select count(*) from public.alimenti where id in (%L, %L)', non_in_piano, solo_bozza));
  perform pg_temp.registra('PAZ A1', 'Non vede alimenti fuori dal piano o solo in una bozza', '0', c::text, c = 0);
  c := pg_temp.conta(u_a1, format('select count(*) from public.alimenti where id = %L', pasta_b));
  perform pg_temp.registra('PAZ A1', 'Non vede gli alimenti personalizzati di un altro nutrizionista', '0', c::text, c = 0);
  c := pg_temp.conta(u_b1, format('select count(*) from public.alimenti where id = %L', torta_a));
  perform pg_temp.registra('PAZ B1', 'Non vede gli alimenti del piano di un altro paziente', '0', c::text, c = 0);

  -- ------------------------------------------------------------ modifica
  c := pg_temp.conta(nut_a, format('with u as (update public.alimenti set kcal_100g = 310 where id = %L returning 1) select count(*) from u', torta_a));
  perform pg_temp.registra('NUT A', 'Modifica un proprio alimento personalizzato', '1', c::text, c = 1);
  c := pg_temp.conta(nut_a, format('with u as (update public.alimenti set kcal_100g = 1 where id = %L returning 1) select count(*) from u', off));
  perform pg_temp.registra('NUT A', 'Non modifica un alimento di Open Food Facts', '0', c::text, c = 0);
  c := pg_temp.conta(nut_b, format('with u as (update public.alimenti set kcal_100g = 1 where id = %L returning 1) select count(*) from u', off));
  perform pg_temp.registra('NUT B', 'Non modifica un alimento di Open Food Facts', '0', c::text, c = 0);
  c := pg_temp.conta(nut_b, format('with u as (update public.alimenti set kcal_100g = 1 where id = %L returning 1) select count(*) from u', torta_a));
  perform pg_temp.registra('NUT B', 'Non modifica l''alimento personalizzato di NUT A', '0', c::text, c = 0);
  c := pg_temp.conta(u_a1, format('with u as (update public.alimenti set kcal_100g = 1 where id = %L returning 1) select count(*) from u', torta_a));
  perform pg_temp.registra('PAZ A1', 'Non modifica gli alimenti', '0', c::text, c <= 0);

  -- ---------------------------------------------------------- inserimento
  r := pg_temp.esegui(nut_a, 'insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte) values (''Nuovo da OFF'', 1, 1, 1, 1, ''open_food_facts'')');
  perform pg_temp.registra('NUT A', 'Salva in cache un alimento di Open Food Facts', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, format('insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da) values (''Nuovo mio'', 1, 1, 1, 1, ''personalizzato'', %L)', nut_a));
  perform pg_temp.registra('NUT A', 'Crea un alimento personalizzato a proprio nome', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, 'insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte) values (''Senza proprietario'', 1, 1, 1, 1, ''personalizzato'')');
  perform pg_temp.registra('NUT A', 'Non crea un alimento personalizzato senza proprietario', 'violazione RLS', r, r like '42501%');
  r := pg_temp.esegui(nut_a, format('insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da) values (''Falso'', 1, 1, 1, 1, ''personalizzato'', %L)', nut_b));
  perform pg_temp.registra('NUT A', 'Non crea un alimento a nome di NUT B', 'violazione RLS', r, r like '42501%');
  r := pg_temp.esegui(u_a1, 'insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte) values (''Da paziente'', 1, 1, 1, 1, ''open_food_facts'')');
  perform pg_temp.registra('PAZ A1', 'Non scrive nella cache degli alimenti', 'negato', r, r <> 'ok');
end $$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
