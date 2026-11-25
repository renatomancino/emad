-- =============================================================================
-- Cenato · test del salvataggio del piano (008) · RF_GP_1, RF_GP_2, RF_GP_7
-- Come rls.sql: nel SQL Editor, in una transazione annullata (ROLLBACK).
-- Ogni riga deve avere esito OK.
-- =============================================================================
begin;

create temp table esiti (n serial, utente text, prova text, atteso text, ottenuto text, esito text) on commit drop;

-- Come un utente: conteggio (-1 se accesso negato).
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

-- Come un utente: esegue e restituisce 'ok' oppure SQLSTATE: messaggio.
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
  u_a1 uuid := gen_random_uuid();   -- paziente attivo di A
  u_a2 uuid := gen_random_uuid();   -- paziente archiviato di A
  u_b1 uuid := gen_random_uuid();   -- paziente di B
  paz_a1 uuid; paz_a2 uuid; paz_b1 uuid; paz_inv uuid;
  latte uuid; avena uuid; fette uuid; mio uuid; di_b uuid;
  p1 uuid; p2 uuid; ci uuid; pasto_v1 uuid;
  r text; c bigint; k numeric;
  struttura jsonb;
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (nut_a, 'nut.a@piano.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut A"}'),
    (nut_b, 'nut.b@piano.local', '{"consenso_dati":true,"ruolo":"nutrizionista","nome":"Nut B"}'),
    (u_a1,  'paz.a1@piano.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A1"}'),
    (u_a2,  'paz.a2@piano.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz A2"}'),
    (u_b1,  'paz.b1@piano.local', '{"consenso_dati":true,"ruolo":"paziente","nome":"Paz B1"}');
  -- il piano Free ha 1 paziente: A passa a Pro per averne due
  update public.nutrizionisti set piano_abbonamento = 'pro', periodo_fatturazione = 'annuale' where id = nut_a;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_a, u_a1, 'attivo', now()) returning id into paz_a1;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento, data_archiviazione)
    values (nut_a, u_a2, 'archiviato', now(), now()) returning id into paz_a2;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_collegamento)
    values (nut_b, u_b1, 'attivo', now()) returning id into paz_b1;
  insert into public.pazienti (nutrizionista_id, stato, nome)
    values (nut_a, 'invitato', 'Invitato') returning id into paz_inv;

  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Latte', 46, 3.4, 4.9, 1.6, 'open_food_facts') returning id into latte;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Avena', 372, 13.5, 60, 7, 'open_food_facts') returning id into avena;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte)
    values ('Fette biscottate', 410, 11, 72, 6, 'open_food_facts') returning id into fette;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Mio alimento', 100, 10, 10, 1, 'personalizzato', nut_a) returning id into mio;
  insert into public.alimenti (nome, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte, creato_da)
    values ('Alimento di B', 100, 10, 10, 1, 'personalizzato', nut_b) returning id into di_b;

  -- Piano di SC_GP_1 in piccolo: lunedì e martedì; colazione con alternativa
  struttura := jsonb_build_object('giorni', jsonb_build_array(
    jsonb_build_object('giorno', 1, 'pasti', jsonb_build_array(
      jsonb_build_object('tipo', 'colazione', 'orario', '08:00', 'voci', jsonb_build_array(
        jsonb_build_object('alimento_id', latte, 'quantita_g', 200),
        jsonb_build_object('alimento_id', avena, 'quantita_g', 40,
          'alternative', jsonb_build_array(jsonb_build_object('alimento_id', fette, 'quantita_g', 35)))))
    )),
    jsonb_build_object('giorno', 2, 'pasti', jsonb_build_array(
      jsonb_build_object('tipo', 'colazione', 'voci', jsonb_build_array(
        jsonb_build_object('alimento_id', latte, 'quantita_g', 150)))
    ))
  ));

  -- ------------------------------------------------------------ versione 1
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, struttura));
  perform pg_temp.registra('NUT A', 'Salva e assegna il primo piano', 'ok', r, r = 'ok');
  select id into p1 from public.piani where paziente_id = paz_a1 and versione = 1;
  perform pg_temp.registra('NUT A', 'La versione 1 è corrente', 'corrente',
    coalesce((select stato::text from public.piani where id = p1), 'assente'),
    (select stato from public.piani where id = p1) = 'corrente');
  c := pg_temp.conta(nut_a, format('select count(*) from public.giorni where piano_id = %L', p1));
  perform pg_temp.registra('NUT A', 'Giorni, pasti e voci creati (2 giorni)', '2', c::text, c = 2);
  c := pg_temp.conta(nut_a, format('select count(*) from public.voci_pasto v join public.pasti pa on pa.id = v.pasto_id join public.giorni g on g.id = pa.giorno_id where g.piano_id = %L', p1));
  perform pg_temp.registra('NUT A', 'Voci create (3)', '3', c::text, c = 3);
  select kcal into k from public.voci_pasto v join public.pasti pa on pa.id = v.pasto_id join public.giorni g on g.id = pa.giorno_id
   where g.piano_id = p1 and v.alimento_id = avena;
  perform pg_temp.registra('NUT A', 'kcal ricalcolate dal database (40 g di avena = 148,8)', '148.8', k::text, k = 148.8);
  c := pg_temp.conta(nut_a, format('select count(*) from public.alternative a join public.voci_pasto v on v.id = a.voce_id join public.pasti pa on pa.id = v.pasto_id join public.giorni g on g.id = pa.giorno_id where g.piano_id = %L', p1));
  perform pg_temp.registra('NUT A', 'L''alternativa è conservata', '1', c::text, c = 1);
  c := pg_temp.conta(u_a1, 'select count(*) from public.piani');
  perform pg_temp.registra('PAZ A1', 'Vede il piano assegnato', '1', c::text, c = 1);

  -- Un check-in sul piano v1: deve sopravvivere alla nuova versione (UC_GP_1, note)
  select pa.id into pasto_v1 from public.pasti pa join public.giorni g on g.id = pa.giorno_id
   where g.piano_id = p1 and g.giorno_settimana = 1;
  insert into public.check_in (paziente_id, pasto_id, data, stato)
    values (paz_a1, pasto_v1, current_date, 'seguito') returning id into ci;

  -- ------------------------------------------------------------ versione 2
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, struttura));
  perform pg_temp.registra('NUT A', 'Una modifica crea la versione 2', 'ok', r, r = 'ok');
  select id into p2 from public.piani where paziente_id = paz_a1 and versione = 2;
  perform pg_temp.registra('NUT A', 'La versione 2 è corrente e la 1 è superata', 'corrente + superato',
    (select stato::text from public.piani where id = p2) || ' + ' || (select stato::text from public.piani where id = p1),
    (select stato from public.piani where id = p2) = 'corrente' and (select stato from public.piani where id = p1) = 'superato');
  c := pg_temp.conta(nut_a, format('select count(*) from public.piani where paziente_id = %L and stato = ''corrente''', paz_a1));
  perform pg_temp.registra('NUT A', 'Una sola versione corrente per paziente', '1', c::text, c = 1);
  perform pg_temp.registra('NUT A', 'Il check-in resta legato alla versione precedente', '1',
    (select count(*) from public.check_in where id = ci and pasto_id = pasto_v1)::text,
    (select count(*) from public.check_in where id = ci and pasto_id = pasto_v1) = 1);
  c := pg_temp.conta(nut_a, format('select count(*) from public.giorni where piano_id = %L', p1));
  perform pg_temp.registra('NUT A', 'La versione 1 conserva la sua struttura', '2', c::text, c = 2);
  c := pg_temp.conta(u_a1, 'select count(*) from public.piani where stato = ''corrente''');
  perform pg_temp.registra('PAZ A1', 'Vede una sola versione corrente', '1', c::text, c = 1);

  -- ------------------------------------------------------------ permessi
  r := pg_temp.esegui(nut_b, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, struttura));
  perform pg_temp.registra('NUT B', 'Non assegna un piano al paziente di un altro', 'CN020', r, r like 'CN020%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a2, struttura));
  perform pg_temp.registra('NUT A', 'Non assegna un piano a un paziente archiviato', 'CN020', r, r like 'CN020%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_inv, struttura));
  perform pg_temp.registra('NUT A', 'Non assegna un piano a un paziente solo invitato', 'CN020', r, r like 'CN020%');
  r := pg_temp.esegui(u_a1, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, struttura));
  perform pg_temp.registra('PAZ A1', 'Il paziente non assegna piani', 'CN020', r, r like 'CN020%');
  r := pg_temp.esegui(null, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, struttura));
  perform pg_temp.registra('anonimo', 'Senza login non può chiamare salva_piano', 'permesso negato', r, r like '42501%');

  -- ------------------------------------------------------------ struttura non valida
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    '{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[]}]}]}'));
  perform pg_temp.registra('NUT A', 'Pasto senza alimenti rifiutato', 'CN022', r, r like 'CN022%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1, '{"giorni":[]}'));
  perform pg_temp.registra('NUT A', 'Piano senza giorni rifiutato', 'CN021', r, r like 'CN021%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    '{"giorni":[{"giorno":1,"pasti":[]}]}'));
  perform pg_temp.registra('NUT A', 'Giorno senza pasti rifiutato', 'CN021', r, r like 'CN021%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":8,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10}]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Giorno 8 rifiutato', 'CN021', r, r like 'CN021%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10}]}]},{"giorno":1,"pasti":[{"tipo":"cena","voci":[{"alimento_id":"%s","quantita_g":10}]}]}]}', latte, latte)));
  perform pg_temp.registra('NUT A', 'Giorno ripetuto rifiutato', 'CN021', r, r like 'CN021%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"brunch","voci":[{"alimento_id":"%s","quantita_g":10}]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Tipo di pasto sconosciuto rifiutato', 'CN021', r, r like 'CN021%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":0}]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Quantità zero rifiutata', 'CN024', r, r like 'CN024%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":-5}]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Quantità negativa rifiutata', 'CN024', r, r like 'CN024%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":99999}]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Quantità enorme rifiutata', 'CN024', r, r like 'CN024%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10}]}]}]}', di_b)));
  perform pg_temp.registra('NUT A', 'Alimento personalizzato di un altro rifiutato', 'CN023', r, r like 'CN023%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10}]}]}]}', gen_random_uuid())));
  perform pg_temp.registra('NUT A', 'Alimento inesistente rifiutato', 'CN023', r, r like 'CN023%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10,"alternative":[{"alimento_id":"%s","quantita_g":10}]}]}]}]}', latte, di_b)));
  perform pg_temp.registra('NUT A', 'Alternativa non disponibile rifiutata', 'CN023', r, r like 'CN023%');
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":50}]}]}]}', mio)));
  perform pg_temp.registra('NUT A', 'Un proprio alimento personalizzato è accettato', 'ok', r, r = 'ok');

  -- ------------------------------------------------------------ tutto o niente
  -- (dopo l'ultimo salvataggio ok le versioni sono 3)
  r := pg_temp.esegui(nut_a, format('select public.salva_piano(%L, current_date, %L::jsonb)', paz_a1,
    format('{"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","voci":[{"alimento_id":"%s","quantita_g":10}]}]},{"giorno":2,"pasti":[{"tipo":"cena","voci":[]}]}]}', latte)));
  perform pg_temp.registra('NUT A', 'Errore al secondo giorno: salvataggio rifiutato', 'CN022', r, r like 'CN022%');
  c := pg_temp.conta(nut_a, format('select count(*) from public.piani where paziente_id = %L', paz_a1));
  perform pg_temp.registra('NUT A', 'Tutto o niente: nessuna versione in più dopo un errore', '3', c::text, c = 3);
  c := pg_temp.conta(nut_a, format('select count(*) from public.piani where paziente_id = %L and stato = ''corrente'' and versione = 3', paz_a1));
  perform pg_temp.registra('NUT A', 'Tutto o niente: la versione 3 resta corrente', '1', c::text, c = 1);

  -- ------------------------------------------------------------ RLS esistente invariata
  c := pg_temp.conta(nut_b, 'select count(*) from public.piani');
  perform pg_temp.registra('NUT B', 'Non vede i piani di un altro nutrizionista', '0', c::text, c = 0);
  c := pg_temp.conta(u_b1, 'select count(*) from public.piani');
  perform pg_temp.registra('PAZ B1', 'Non vede i piani di un altro paziente', '0', c::text, c = 0);
  r := pg_temp.esegui(nut_a, format('update public.voci_pasto set quantita_g = 1 where pasto_id in (select pa.id from public.pasti pa join public.giorni g on g.id = pa.giorno_id where g.piano_id = %L)', p2));
  c := pg_temp.conta(nut_a, format('select count(*) from public.voci_pasto v join public.pasti pa on pa.id = v.pasto_id join public.giorni g on g.id = pa.giorno_id where g.piano_id = %L and v.quantita_g = 1', p2));
  perform pg_temp.registra('NUT A', 'Una versione assegnata non si modifica a mano (solo nuova versione)', '0', c::text, c = 0);
end $$;

select n, utente, prova, atteso, ottenuto, esito from esiti order by n;

rollback;
