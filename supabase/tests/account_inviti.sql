-- =============================================================================
-- Cenato · test di consenso e inviti (004_account_inviti.sql)
-- Richiede i dati di prova (seed.sql). Transazione annullata: non lascia dati.
-- Ogni riga deve avere esito = OK.
-- =============================================================================
begin;

create temp table esiti (n serial, prova text, ottenuto text, esito text) on commit drop;
grant all on esiti to anon, authenticated;
grant usage on sequence esiti_n_seq to anon, authenticated;

create or replace function pg_temp.come(p_uid uuid) returns void language plpgsql as $f$
begin
  if p_uid is null then
    perform set_config('request.jwt.claims', '{"role":"anon"}', true);
    execute 'set local role anon';
  else
    perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
    execute 'set local role authenticated';
  end if;
end $f$;

create or replace function pg_temp.esegui(p_sql text) returns text language plpgsql as $f$
begin
  execute p_sql;
  return 'ok';
exception when others then
  return sqlstate || ': ' || sqlerrm;
end $f$;

create or replace function pg_temp.esito(p_prova text, p_ottenuto text, p_ok boolean) returns void language sql as $f$
  insert into esiti (prova, ottenuto, esito) values (p_prova, p_ottenuto, case when p_ok then 'OK' else 'KO' end);
$f$;

do $$
declare
  giulia uuid := '00000000-0000-4000-8000-000000000001';
  nuovo1 uuid := gen_random_uuid();
  nuovo2 uuid := gen_random_uuid();
  nuovo3 uuid := gen_random_uuid();
  c_ok text; c_usato text; c_revocato text; c_scaduto text; r text;
  paz uuid;
begin
  -- Consenso: data e versione dell'informativa (RF_GA_6)
  r := pg_temp.esegui(format('insert into auth.users (id, email, raw_user_meta_data) values (%L, ''a@t.local'', ''{"ruolo":"paziente","nome":"A"}'')', nuovo1));
  perform pg_temp.esito('Senza consenso la registrazione è rifiutata', r, r like '22023%');
  r := pg_temp.esegui(format('insert into auth.users (id, email, raw_user_meta_data) values (%L, ''a@t.local'', ''{"ruolo":"paziente","nome":"A","consenso_dati":false}'')', nuovo1));
  perform pg_temp.esito('Consenso "false" rifiutato', r, r like '22023%');
  insert into auth.users (id, email, raw_user_meta_data) values
    (nuovo1, 'n1@t.local', '{"ruolo":"paziente","nome":"Nuovo Uno","consenso_dati":true,"versione_informativa":"2.0"}'),
    (nuovo2, 'n2@t.local', '{"ruolo":"paziente","nome":"Nuovo Due","consenso_dati":true}'),
    (nuovo3, 'n3@t.local', '{"ruolo":"paziente","nome":"Nuovo Tre","consenso_dati":true}');
  perform pg_temp.esito('Data e versione del consenso salvate',
    (select format('%s %s', consenso_dati_il is not null, versione_informativa) from public.profili where id = nuovo1),
    (select consenso_dati_il is not null and versione_informativa = '2.0' from public.profili where id = nuovo1));
  perform pg_temp.esito('Versione predefinita 1.0',
    (select versione_informativa from public.profili where id = nuovo2),
    (select versione_informativa = '1.0' from public.profili where id = nuovo2));

  -- Codici di invito di Giulia (Pro): uno valido, uno da usare, uno da revocare, uno da far scadere
  perform pg_temp.come(giulia);
  select codice into c_ok from public.crea_invito('Valido');
  select codice into c_usato from public.crea_invito('Usato');
  select codice into c_revocato from public.crea_invito('Revocato');
  select codice into c_scaduto from public.crea_invito('Scaduto');
  perform public.revoca_invito((select id from public.inviti where codice = c_revocato));
  execute 'reset role';
  update public.inviti set scadenza = now() - interval '1 minute' where codice = c_scaduto;

  -- verifica_invito prima della registrazione: chiamabile senza login
  perform pg_temp.come(null);
  r := pg_temp.esegui(format('select nome_nutrizionista from public.verifica_invito(%L)', c_ok));
  perform pg_temp.esito('Senza login: verifica del codice valido', r, r = 'ok');
  perform pg_temp.esito('Senza login: nome del nutrizionista mostrato',
    (select nome_nutrizionista from public.verifica_invito(c_ok)),
    (select nome_nutrizionista from public.verifica_invito(c_ok)) = 'Dott.ssa Giulia Rinaldi');
  r := pg_temp.esegui(format('select * from public.verifica_invito(%L)', lower(c_ok)));
  perform pg_temp.esito('Il codice scritto in minuscolo vale lo stesso', r, r = 'ok');
  r := pg_temp.esegui('select * from public.verifica_invito(''ZZZZZZZZ'')');
  perform pg_temp.esito('Codice inesistente: CN010', r, r like 'CN010%');
  r := pg_temp.esegui(format('select * from public.verifica_invito(%L)', c_revocato));
  perform pg_temp.esito('Codice revocato: CN013', r, r like 'CN013%');
  r := pg_temp.esegui(format('select * from public.verifica_invito(%L)', c_scaduto));
  perform pg_temp.esito('Codice scaduto: CN011', r, r like 'CN011%');
  r := pg_temp.esegui('select * from public.accetta_invito(''ZZZZZZZZ'')');
  perform pg_temp.esito('Senza login non si accetta un invito', r, r like '42501%');
  execute 'reset role';

  -- Accettazione: il collegamento avviene con la RPC (SCD_1, SCD_3)
  perform pg_temp.come(nuovo1);
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_usato));
  perform pg_temp.esito('Il paziente accetta l''invito', r, r = 'ok');
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_ok));
  perform pg_temp.esito('Già collegato: un secondo invito è rifiutato (CN008)', r, r like 'CN008%');
  execute 'reset role';
  perform pg_temp.esito('Paziente Attivo e invito Usato',
    (select format('%s %s', p.stato, i.stato) from public.inviti i join public.pazienti p on p.id = i.paziente_id where i.codice = c_usato),
    (select p.stato = 'attivo' and p.utente_id = nuovo1 and p.data_collegamento is not null and i.stato = 'utilizzato'
       from public.inviti i join public.pazienti p on p.id = i.paziente_id where i.codice = c_usato));

  perform pg_temp.come(nuovo2);
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_usato));
  perform pg_temp.esito('Codice già usato: CN012', r, r like 'CN012%');
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_revocato));
  perform pg_temp.esito('Codice revocato: nessun collegamento (CN013)', r, r like 'CN013%');
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_scaduto));
  perform pg_temp.esito('Codice scaduto: nessun collegamento (CN011)', r, r like 'CN011%');
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_ok));
  perform pg_temp.esito('Un altro paziente accetta il codice valido', r, r = 'ok');
  execute 'reset role';
  perform pg_temp.esito('Nessun collegamento creato dai codici non validi',
    (select count(*)::text from public.pazienti where utente_id = nuovo3),
    (select count(*) from public.pazienti where utente_id = nuovo3) = 0);

  -- Il nutrizionista vede subito i nuovi pazienti Attivi
  perform pg_temp.come(giulia);
  perform pg_temp.esito('Giulia vede i due nuovi pazienti Attivi',
    (select count(*)::text from public.pazienti where utente_id in (nuovo1, nuovo2) and stato = 'attivo'),
    (select count(*) from public.pazienti where utente_id in (nuovo1, nuovo2) and stato = 'attivo') = 2);
  execute 'reset role';

  -- Il nutrizionista non può accettare inviti
  perform pg_temp.come(giulia);
  r := pg_temp.esegui(format('select public.accetta_invito(%L)', c_ok));
  perform pg_temp.esito('Un nutrizionista non accetta inviti (CN007)', r, r like 'CN007%');
  execute 'reset role';
end;
$$;

select n, prova, ottenuto, esito from esiti order by n;

rollback;
