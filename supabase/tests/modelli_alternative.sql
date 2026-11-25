-- =============================================================================
-- Cenato · test di modelli (pasti salvati, piani modello) e alternative
-- RF_GP_6, RF_GP_9 · RF_GD_2 · SD_1. Richiede la migrazione 008.
-- Come rls.sql: nel SQL Editor, in una transazione annullata (ROLLBACK).
-- Ogni riga deve avere esito OK.
-- =============================================================================
begin;

create temp table esiti (n serial, utente text, prova text, atteso text, ottenuto text, esito text) on commit drop;

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

create or replace function pg_temp.esegui(p_uid uuid, p_sql text) returns text language plpgsql as $f$
declare r text := 'ok';
begin
  if p_uid is null then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
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
  latte uuid; avena uuid; fette uuid; pane uuid;
  piano_a uuid; bozza uuid; g_bozza uuid; pa_bozza uuid; v_bozza uuid;
  colazione uuid; cena uuid; alt_colazione uuid; alt_cena uuid;
  m_a uuid;
  r text; c bigint;
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@mod.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@mod.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_a1,  'paz.a1@mod.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A1"}'),
    (u_b1,  'paz.b1@mod.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz B1"}');
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_a, u_a1, 'attivo', now()) returning id into paz_a1;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_b, u_b1, 'attivo', now()) returning id into paz_b1;

  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Latte', 46, 3.4, 4.9, 1.6, 'open_food_facts') returning id into latte;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Avena', 372, 13.5, 60, 7, 'open_food_facts') returning id into avena;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Fette biscottate', 410, 11, 72, 6, 'open_food_facts') returning id into fette;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Pane', 270, 9, 50, 3, 'open_food_facts') returning id into pane;

  -- ============================================================ MODELLI (RF_GP_9)
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''Colazione tipo'', ''pasto'', %L::jsonb)',
    nut_a, '{"tipo":"colazione","voci":[]}'));
  perform pg_temp.registra('NUT A', 'Salva un pasto come modello', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''Settimana'', ''piano'', %L::jsonb)',
    nut_a, '{"giorni":[]}'));
  perform pg_temp.registra('NUT A', 'Salva un piano come modello', 'ok', r, r = 'ok');
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''Falso'', ''pasto'', %L::jsonb)',
    nut_b, '{}'));
  perform pg_temp.registra('NUT A', 'Non salva un modello a nome di un altro nutrizionista', 'violazione RLS', r, r like '42501%');
  r := pg_temp.esegui(u_a1, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''Mio'', ''pasto'', %L::jsonb)',
    u_a1, '{}'));
  perform pg_temp.registra('PAZ A1', 'Il paziente non crea modelli', 'negato', r, r <> 'ok');

  -- vincoli sul nome e sul tipo
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, '''', ''pasto'', %L::jsonb)', nut_a, '{}'));
  perform pg_temp.registra('NUT A', 'Nome vuoto rifiutato', '23514', r, r like '23514%');
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, %L, ''pasto'', %L::jsonb)', nut_a, repeat('x', 121), '{}'));
  perform pg_temp.registra('NUT A', 'Nome di 121 caratteri rifiutato', '23514', r, r like '23514%');
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''X'', ''altro'', %L::jsonb)', nut_a, '{}'));
  perform pg_temp.registra('NUT A', 'Tipo sconosciuto rifiutato', '22P02', r, r like '22P02%');
  r := pg_temp.esegui(nut_a, format(
    'insert into public.modelli_piano (nutrizionista_id, nome, tipo, contenuto) values (%L, ''X'', ''pasto'', null)', nut_a));
  perform pg_temp.registra('NUT A', 'Contenuto mancante rifiutato', '23502', r, r like '23502%');

  -- chi vede cosa
  c := pg_temp.conta(nut_a, 'select count(*) from public.modelli_piano');
  perform pg_temp.registra('NUT A', 'Vede i propri modelli (2)', '2', c::text, c = 2);
  c := pg_temp.conta(nut_b, 'select count(*) from public.modelli_piano');
  perform pg_temp.registra('NUT B', 'Non vede i modelli di un altro nutrizionista', '0', c::text, c = 0);
  c := pg_temp.conta(u_a1, 'select count(*) from public.modelli_piano');
  perform pg_temp.registra('PAZ A1', 'Il paziente non vede i modelli', '0', c::text, c = 0);
  c := pg_temp.conta(null, 'select count(*) from public.modelli_piano');
  perform pg_temp.registra('anonimo', 'Senza login non legge i modelli', 'negato', c::text, c = -1);

  -- modifica ed eliminazione
  select id into m_a from public.modelli_piano where nutrizionista_id = nut_a and tipo = 'pasto';
  c := pg_temp.conta(nut_b, format('with d as (delete from public.modelli_piano where id = %L returning 1) select count(*) from d', m_a));
  perform pg_temp.registra('NUT B', 'Non elimina il modello di un altro', '0', c::text, c = 0);
  c := pg_temp.conta(nut_b, format('with u as (update public.modelli_piano set nome = ''Rubato'' where id = %L returning 1) select count(*) from u', m_a));
  perform pg_temp.registra('NUT B', 'Non modifica il modello di un altro', '0', c::text, c = 0);
  c := pg_temp.conta(nut_a, format('with d as (delete from public.modelli_piano where id = %L returning 1) select count(*) from d', m_a));
  perform pg_temp.registra('NUT A', 'Elimina un proprio modello', '1', c::text, c = 1);
  c := pg_temp.conta(nut_a, 'select count(*) from public.modelli_piano');
  perform pg_temp.registra('NUT A', 'Resta solo il piano modello', '1', c::text, c = 1);

  -- ============================================== ALTERNATIVE (RF_GP_6, RF_GD_2)
  -- Colazione: latte (alternativa: fette) e avena; cena: pane (alternativa: fette)
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":['
      '{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":200,"alternative":[{"alimento_id":"%s","quantita_g":35}]},{"alimento_id":"%s","quantita_g":40}]},'
      '{"tipo":"cena","voci":[{"alimento_id":"%s","quantita_g":80,"alternative":[{"alimento_id":"%s","quantita_g":60}]}]}'
      ']}]}', latte, fette, avena, pane, fette)));
  perform pg_temp.registra('NUT A', 'Piano con alternative salvato', 'ok', r, r = 'ok');
  select id into piano_a from public.piani where paziente_id = paz_a1 and stato = 'corrente';
  select pa.id into colazione from public.pasti pa join public.giorni g on g.id = pa.giorno_id
    where g.piano_id = piano_a and pa.tipo = 'colazione';
  select pa.id into cena from public.pasti pa join public.giorni g on g.id = pa.giorno_id
    where g.piano_id = piano_a and pa.tipo = 'cena';
  select a.id into alt_colazione from public.alternative a join public.voci_pasto v on v.id = a.voce_id where v.pasto_id = colazione;
  select a.id into alt_cena from public.alternative a join public.voci_pasto v on v.id = a.voce_id where v.pasto_id = cena;

  -- come le legge l'app: le alternative di UN pasto
  c := pg_temp.conta(u_a1, format('select count(*) from public.alternative a join public.voci_pasto v on v.id = a.voce_id where v.pasto_id = %L', colazione));
  perform pg_temp.registra('PAZ A1', 'Vede le alternative del pasto (solo quelle: 1)', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.alternative');
  perform pg_temp.registra('PAZ A1', 'Vede le alternative del suo piano (2)', '2', c::text, c = 2);
  c := pg_temp.conta(u_b1, 'select count(*) from public.alternative');
  perform pg_temp.registra('PAZ B1', 'Non vede le alternative di un altro paziente', '0', c::text, c = 0);
  c := pg_temp.conta(nut_b, 'select count(*) from public.alternative');
  perform pg_temp.registra('NUT B', 'Non vede le alternative di un altro nutrizionista', '0', c::text, c = 0);

  -- il paziente non modifica le alternative
  r := pg_temp.esegui(u_a1, format('insert into public.alternative (voce_id, alimento_id, quantita_g) select id, %L, 50 from public.voci_pasto where pasto_id = %L limit 1', pane, colazione));
  perform pg_temp.registra('PAZ A1', 'Non aggiunge alternative', 'negato', r, r <> 'ok');
  c := pg_temp.conta(u_a1, format('with d as (delete from public.alternative where id = %L returning 1) select count(*) from d', alt_colazione));
  perform pg_temp.registra('PAZ A1', 'Non elimina alternative', '0', c::text, c in (0, -1));

  -- una versione assegnata non si modifica a mano: l'alternativa nuova si fa con una nuova versione
  r := pg_temp.esegui(nut_a, format('insert into public.alternative (voce_id, alimento_id, quantita_g) select id, %L, 50 from public.voci_pasto where pasto_id = %L limit 1', pane, colazione));
  perform pg_temp.registra('NUT A', 'Su una versione assegnata non si aggiungono alternative a mano', 'violazione RLS', r, r like '42501%');

  -- check-in "Alternativa": solo le alternative di QUEL pasto (SD_1)
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato, alternativa_id) values (%L, %L, current_date, ''alternativa'', %L)', paz_a1, colazione, alt_colazione));
  perform pg_temp.registra('PAZ A1', 'Check-in con un''alternativa del pasto', 'ok', r, r = 'ok');
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato, alternativa_id) values (%L, %L, current_date, ''alternativa'', %L)', paz_a1, cena, alt_colazione));
  perform pg_temp.registra('PAZ A1', 'Check-in con l''alternativa di un altro pasto rifiutato', '23514', r, r like '23514%');
  r := pg_temp.esegui(u_a1, format('insert into public.check_in (paziente_id, pasto_id, data, stato) values (%L, %L, current_date, ''alternativa'')', paz_a1, cena));
  perform pg_temp.registra('PAZ A1', 'Check-in "Alternativa" senza scegliere l''alternativa rifiutato', '23514', r, r like '23514%');

  -- una bozza non si vede: le sue alternative restano nascoste al paziente
  insert into public.piani (paziente_id, nutrizionista_id, versione, stato) values (paz_a1, nut_a, 99, 'bozza') returning id into bozza;
  insert into public.giorni (piano_id, giorno_settimana) values (bozza, 2) returning id into g_bozza;
  insert into public.pasti (giorno_id, tipo) values (g_bozza, 'colazione') returning id into pa_bozza;
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g)
    values (pa_bozza, latte, 100, 46, 3.4, 4.9, 1.6) returning id into v_bozza;
  insert into public.alternative (voce_id, alimento_id, quantita_g) values (v_bozza, fette, 30);
  c := pg_temp.conta(u_a1, 'select count(*) from public.alternative');
  perform pg_temp.registra('PAZ A1', 'Le alternative di una bozza non si vedono', '2', c::text, c = 2);
  c := pg_temp.conta(nut_a, 'select count(*) from public.alternative');
  perform pg_temp.registra('NUT A', 'Il nutrizionista vede anche quelle della bozza (3)', '3', c::text, c = 3);

  -- una nuova versione porta con sé le alternative e ne cambia gli id
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":200,"alternative":[{"alimento_id":"%s","quantita_g":35},{"alimento_id":"%s","quantita_g":50}]}]}]}]}', latte, fette, pane)));
  perform pg_temp.registra('NUT A', 'Nuova versione con due alternative per una voce', 'ok', r, r = 'ok');
  c := pg_temp.conta(u_a1, 'select count(*) from public.alternative a join public.voci_pasto v on v.id = a.voce_id join public.pasti pa on pa.id = v.pasto_id join public.giorni g on g.id = pa.giorno_id join public.piani p on p.id = g.piano_id where p.stato = ''corrente''');
  perform pg_temp.registra('PAZ A1', 'Nella versione corrente vede le 2 alternative della voce', '2', c::text, c = 2);
  perform pg_temp.registra('PAZ A1', 'Il check-in già fatto resta valido sulla versione vecchia', '1',
    (select count(*) from public.check_in where paziente_id = paz_a1 and alternativa_id = alt_colazione)::text,
    (select count(*) from public.check_in where paziente_id = paz_a1 and alternativa_id = alt_colazione) = 1);
end $$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
