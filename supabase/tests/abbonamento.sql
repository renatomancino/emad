-- =============================================================================
-- Cenato · test di piani, limiti e inviti (003_abbonamento.sql + 002_rls.sql)
-- Richiede i dati di prova (seed.sql). Transazione annullata: non lascia dati.
-- Ogni riga deve avere esito = OK.
-- =============================================================================
begin;

create temp table esiti (n serial, prova text, ottenuto text, esito text) on commit drop;
grant all on esiti to authenticated;
grant usage on sequence esiti_n_seq to authenticated;

create or replace function pg_temp.come(p_email text) returns void language plpgsql as $f$
begin
  perform set_config('request.jwt.claims',
    json_build_object('sub', (select id from auth.users where email = p_email), 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
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
declare r text; s record; c_scad text;
begin
  -- Elena: piano Free con Anna già collegata (SC_GAD_2)
  perform pg_temp.come('elena@example.com');
  select * into s from public.stato_abbonamento();
  perform pg_temp.esito('Free: 1 posto su 1, non può invitare', format('%s/%s %s', s.posti_occupati, s.limite, s.puo_invitare),
                        s.posti_occupati = 1 and s.limite = 1 and not s.puo_invitare);
  r := pg_temp.esegui('select * from public.crea_invito(''Nuovo'')');
  perform pg_temp.esito('Free: 2° invito bloccato con messaggio (RF_GAD_7)', r, r like 'CN001: Hai raggiunto il limite del piano Free%');
  r := pg_temp.esegui('select public.cambia_piano(''start'', null)');
  perform pg_temp.esito('Cambio piano senza periodo rifiutato', r, r like 'CN007%');
  r := pg_temp.esegui('select public.cambia_piano(''start'', ''mensile'')');
  perform pg_temp.esito('Passa a Start mensile (pagamento simulato)', r, r = 'ok');
  select * into s from public.stato_abbonamento();
  perform pg_temp.esito('Start: limite 5, può invitare', format('%s %s/%s', s.piano, s.posti_occupati, s.limite),
                        s.piano = 'start' and s.limite = 5 and s.puo_invitare);
  r := pg_temp.esegui('select * from public.crea_invito(''Nuovo'')');
  perform pg_temp.esito('Dopo Start il 2° invito funziona', r, r = 'ok');
  r := pg_temp.esegui('select public.cambia_piano(''free'')');
  perform pg_temp.esito('Ritorno a Free bloccato (2 posti occupati)', r, r like 'CN001: Non puoi passare al piano Free%');
  execute 'reset role';
  perform pg_temp.esito('Abbonamento registrato come simulato, 12 €',
    (select format('%s %s %s', piano, importo_cent, pagamento_simulato) from public.abbonamenti a
       join auth.users u on u.id = a.nutrizionista_id where u.email = 'elena@example.com' and a.fine is null),
    exists (select 1 from public.abbonamenti a join auth.users u on u.id = a.nutrizionista_id
            where u.email = 'elena@example.com' and a.fine is null and a.piano = 'start'
              and a.importo_cent = 1200 and a.pagamento_simulato));

  -- Giulia: Pro con 3 attivi, 1 archiviato e 1 invito in attesa
  perform pg_temp.come('giulia@example.com');
  select * into s from public.stato_abbonamento();
  perform pg_temp.esito('Pro: nessun limite', format('%s limite=%s', s.piano, coalesce(s.limite::text, 'nessuno')),
                        s.piano = 'pro' and s.limite is null and s.puo_invitare);
  r := pg_temp.esegui('select public.cambia_piano(''start'', ''annuale'')');
  perform pg_temp.esito('Da Pro a Start annuale: 3 attivi + 1 invito <= 5', r, r = 'ok');
  r := pg_temp.esegui('select public.revoca_invito((select id from public.inviti where codice = ''GIULIA26''))');
  perform pg_temp.esito('Revoca dell''invito in attesa (RF_GI_8)', r, r = 'ok');
  r := pg_temp.esegui('select public.revoca_invito((select id from public.inviti where codice = ''GIULIA26''))');
  perform pg_temp.esito('Un invito revocato non si revoca due volte', r, r like 'CN007%');
  r := pg_temp.esegui('select public.riattiva_paziente((select p.id from public.pazienti p join public.profili pr on pr.id = p.utente_id where pr.nome = ''Luca Galli''))');
  perform pg_temp.esito('Start: riattiva Luca (4 attivi su 5)', r, r = 'ok');
  r := pg_temp.esegui('select public.archivia_paziente((select p.id from public.pazienti p join public.profili pr on pr.id = p.utente_id where pr.nome = ''Luca Galli''))');
  perform pg_temp.esito('Start: archivia di nuovo Luca (libera il posto)', r, r = 'ok');
  execute 'reset role';

  -- Il codice revocato non è più accettabile (SCD_1)
  perform pg_temp.come('marco@example.com');
  r := pg_temp.esegui('select * from public.verifica_invito(''GIULIA26'')');
  perform pg_temp.esito('Codice revocato rifiutato con messaggio distinto (CN013)', r, r like 'CN013%');
  r := pg_temp.esegui('select * from public.stato_abbonamento()');
  perform pg_temp.esito('Un paziente non ha abbonamento', r, r like 'CN007%');
  execute 'reset role';

  -- Scadenza (SCD_1): un codice oltre la scadenza è rifiutato e passa a "scaduto".
  -- Il codice si legge come nutrizionista: il paziente non vede gli inviti (RLS).
  perform pg_temp.come('giulia@example.com');
  select codice into c_scad from public.crea_invito('Scadenza');
  execute 'reset role';
  update public.inviti set scadenza = now() - interval '1 minute' where codice = c_scad;
  perform pg_temp.come('marco@example.com');
  r := pg_temp.esegui(format('select * from public.verifica_invito(%L)', c_scad));
  perform pg_temp.esito('Codice scaduto rifiutato con messaggio distinto (CN011)', r, r like 'CN011%');
  execute 'reset role';
  perform pg_temp.come('giulia@example.com');
  perform public.crea_invito('Altro');
  execute 'reset role';
  perform pg_temp.esito('Invito scaduto in stato "scaduto"',
    (select i.stato::text from public.inviti i join public.pazienti p on p.id = i.paziente_id where p.nome = 'Scadenza'),
    (select i.stato from public.inviti i join public.pazienti p on p.id = i.paziente_id where p.nome = 'Scadenza') = 'scaduto');
end;
$$;

select n, prova, ottenuto, esito from esiti order by n;

rollback;
