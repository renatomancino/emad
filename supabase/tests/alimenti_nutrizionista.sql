-- =============================================================================
-- Cenato · test della policy RLS di alimenti_nutrizionista (006)
-- Alimenti recenti e preferiti del nutrizionista · RF_GP_14.
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
  u_paz uuid := gen_random_uuid();
  alim uuid;
  r text; c bigint;
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@alim.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@alim.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_paz, 'paz@alim.local',   '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz"}');
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Pane di prova', 250, 8, 49, 1.5, 'open_food_facts') returning id into alim;

  -- anonimo
  c := pg_temp.conta(null, 'select count(*) from public.alimenti_nutrizionista');
  perform pg_temp.registra('anonimo', 'Non legge recenti e preferiti', 'negato', c::text, c <= 0);

  -- NUT A scrive le proprie righe
  r := pg_temp.esegui(nut_a, format('insert into public.alimenti_nutrizionista (nutrizionista_id, alimento_id) values (%L, %L)', nut_a, alim));
  perform pg_temp.registra('NUT A', 'Segna un alimento tra i recenti', 'ok', r, r = 'ok');

  r := pg_temp.esegui(nut_a, format('insert into public.alimenti_nutrizionista (nutrizionista_id, alimento_id) values (%L, %L)', nut_b, alim));
  perform pg_temp.registra('NUT A', 'Non scrive una riga a nome di NUT B', 'violazione RLS', r, r like '42501%');

  r := pg_temp.esegui(nut_a, format('insert into public.alimenti_nutrizionista (nutrizionista_id, alimento_id) values (%L, %L)', nut_a, alim));
  perform pg_temp.registra('NUT A', 'Una sola riga per coppia nutrizionista-alimento', 'chiave duplicata', r, r like '23505%');

  c := pg_temp.conta(nut_a, 'select count(*) from public.alimenti_nutrizionista');
  perform pg_temp.registra('NUT A', 'Vede le proprie righe', '1', c::text, c = 1);

  c := pg_temp.conta(nut_a, format('with u as (update public.alimenti_nutrizionista set preferito = true where alimento_id = %L returning 1) select count(*) from u', alim));
  perform pg_temp.registra('NUT A', 'Mette la stella al proprio alimento', '1', c::text, c = 1);

  -- NUT B non vede né tocca le righe di A
  c := pg_temp.conta(nut_b, 'select count(*) from public.alimenti_nutrizionista');
  perform pg_temp.registra('NUT B', 'Non vede le righe di NUT A', '0', c::text, c = 0);

  c := pg_temp.conta(nut_b, format('with u as (update public.alimenti_nutrizionista set preferito = false where alimento_id = %L returning 1) select count(*) from u', alim));
  perform pg_temp.registra('NUT B', 'Non modifica le righe di NUT A', '0', c::text, c = 0);

  c := pg_temp.conta(nut_b, format('with d as (delete from public.alimenti_nutrizionista where alimento_id = %L returning 1) select count(*) from d', alim));
  perform pg_temp.registra('NUT B', 'Non cancella le righe di NUT A', '0', c::text, c = 0);

  -- un paziente non è un nutrizionista
  r := pg_temp.esegui(u_paz, format('insert into public.alimenti_nutrizionista (nutrizionista_id, alimento_id) values (%L, %L)', u_paz, alim));
  perform pg_temp.registra('PAZ', 'Non scrive recenti e preferiti', 'negato', r, r <> 'ok');

  -- l'alimento sparisce dalla cache: sparisce anche dai recenti
  delete from public.alimenti where id = alim;
  c := (select count(*) from public.alimenti_nutrizionista);
  perform pg_temp.registra('sistema', 'Senza l''alimento non restano righe orfane', '0', c::text, c = 0);
end $$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
