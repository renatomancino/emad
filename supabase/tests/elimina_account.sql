-- =============================================================================
-- Cenato · test dell'eliminazione dell'account (005_elimina_account.sql)
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
  elena  uuid := '00000000-0000-4000-8000-000000000002';
  marco  uuid := '00000000-0000-4000-8000-000000000011';
  sara   uuid := '00000000-0000-4000-8000-000000000012';
  anna   uuid := '00000000-0000-4000-8000-000000000015';
  paz_marco uuid; r text; n_prima int;
begin
  select id into paz_marco from public.pazienti where utente_id = marco;
  select count(*) into n_prima from public.check_in where paziente_id = paz_marco;
  perform pg_temp.esito('Marco ha dati clinici prima', n_prima::text, n_prima > 0);

  -- Senza login non si elimina nulla
  perform pg_temp.come(null);
  r := pg_temp.esegui('select public.elimina_account()');
  perform pg_temp.esito('Senza login: eliminazione negata', r, r like '42501%');
  execute 'reset role';

  -- ------------------------------------------------------------- PAZIENTE
  perform pg_temp.come(marco);
  r := pg_temp.esegui('select public.elimina_account()');
  perform pg_temp.esito('Marco elimina il proprio account', r, r = 'ok');
  execute 'reset role';

  perform pg_temp.esito('Account di accesso cancellato',
    (select count(*)::text from auth.users where id = marco),
    (select count(*) from auth.users where id = marco) = 0);
  perform pg_temp.esito('Profilo cancellato',
    (select count(*)::text from public.profili where id = marco),
    (select count(*) from public.profili where id = marco) = 0);
  perform pg_temp.esito('Check-in, peso, piani, obiettivi, commenti e visite cancellati',
    (select (select count(*) from public.check_in where paziente_id = paz_marco)
          + (select count(*) from public.misure_peso where paziente_id = paz_marco)
          + (select count(*) from public.piani where paziente_id = paz_marco)
          + (select count(*) from public.obiettivi where paziente_id = paz_marco)
          + (select count(*) from public.visite where paziente_id = paz_marco)
          + (select count(*) from public.pasti_extra where paziente_id = paz_marco)
          + (select count(*) from public.finestre_prenotazione where paziente_id = paz_marco))::text,
    (select (select count(*) from public.check_in where paziente_id = paz_marco)
          + (select count(*) from public.misure_peso where paziente_id = paz_marco)
          + (select count(*) from public.piani where paziente_id = paz_marco)
          + (select count(*) from public.obiettivi where paziente_id = paz_marco)
          + (select count(*) from public.visite where paziente_id = paz_marco)
          + (select count(*) from public.pasti_extra where paziente_id = paz_marco)
          + (select count(*) from public.finestre_prenotazione where paziente_id = paz_marco)) = 0);

  perform pg_temp.esito('Resta solo un guscio anonimo, archiviato e senza dati personali',
    (select format('%s | %s | utente=%s | altezza=%s | obiettivo=%s', nome, stato, utente_id is null, altezza_cm is null, obiettivo is null)
       from public.pazienti where id = paz_marco),
    (select nome = 'Account eliminato' and stato = 'archiviato' and utente_id is null and data_nascita is null
            and altezza_cm is null and obiettivo is null and archiviato_da = 'paziente' and data_collegamento is not null
       from public.pazienti where id = paz_marco));

  -- Giulia vede il guscio tra gli archiviati ma nessun dato clinico di Marco
  perform pg_temp.come(giulia);
  perform pg_temp.esito('Giulia vede "Account eliminato" tra gli archiviati',
    (select count(*)::text from public.pazienti where id = paz_marco and nome = 'Account eliminato'),
    (select count(*) from public.pazienti where id = paz_marco and nome = 'Account eliminato') = 1);
  perform pg_temp.esito('Giulia non vede più alcun check-in di Marco',
    (select count(*)::text from public.check_in where paziente_id = paz_marco),
    (select count(*) from public.check_in where paziente_id = paz_marco) = 0);
  execute 'reset role';

  -- Nel Free il guscio continua a occupare il posto (anna elimina, Elena resta piena)
  perform pg_temp.come(anna);
  r := pg_temp.esegui('select public.elimina_account()');
  execute 'reset role';
  perform pg_temp.esito('Anna (paziente di Elena, piano Free) elimina l''account', r, r = 'ok');
  perform pg_temp.come(elena);
  r := pg_temp.esegui('select * from public.crea_invito(''Nuovo'')');
  execute 'reset role';
  perform pg_temp.esito('Free: dopo l''eliminazione il posto resta occupato (CN001)', r, r like 'CN001%');

  -- ------------------------------------------------------------- NUTRIZIONISTA
  perform pg_temp.come(giulia);
  r := pg_temp.esegui('select public.elimina_account()');
  execute 'reset role';
  perform pg_temp.esito('Giulia elimina il proprio account', r, r = 'ok');

  perform pg_temp.esito('Nessun dato di Giulia rimasto',
    (select format('auth=%s profili=%s pazienti=%s inviti=%s visite=%s piani=%s commenti=%s disponibilita=%s',
       (select count(*) from auth.users where id = giulia),
       (select count(*) from public.profili where id = giulia),
       (select count(*) from public.pazienti where nutrizionista_id = giulia),
       (select count(*) from public.inviti where nutrizionista_id = giulia),
       (select count(*) from public.visite where nutrizionista_id = giulia),
       (select count(*) from public.piani where nutrizionista_id = giulia),
       (select count(*) from public.commenti where nutrizionista_id = giulia),
       (select count(*) from public.disponibilita where nutrizionista_id = giulia))),
    (select (select count(*) from auth.users where id = giulia)
          + (select count(*) from public.pazienti where nutrizionista_id = giulia)
          + (select count(*) from public.inviti where nutrizionista_id = giulia)
          + (select count(*) from public.visite where nutrizionista_id = giulia)
          + (select count(*) from public.piani where nutrizionista_id = giulia)
          + (select count(*) from public.commenti where nutrizionista_id = giulia)
          + (select count(*) from public.disponibilita where nutrizionista_id = giulia) = 0));

  perform pg_temp.esito('I dati clinici dei suoi pazienti sono cancellati',
    (select count(*)::text from public.check_in c join public.pazienti p on p.id = c.paziente_id where p.utente_id = sara),
    (select count(*) from public.check_in c join public.pazienti p on p.id = c.paziente_id where p.utente_id = sara) = 0);

  perform pg_temp.esito('Gli account dei pazienti (Sara) restano, non più collegati',
    (select format('profilo=%s collegamenti=%s', (select count(*) from public.profili where id = sara), (select count(*) from public.pazienti where utente_id = sara))),
    (select count(*) from public.profili where id = sara) = 1 and (select count(*) from public.pazienti where utente_id = sara) = 0);

  -- Sara, ora senza nutrizionista, può accettare un nuovo invito (da Elena: Free pieno, quindi rifiutato)
  perform pg_temp.come(sara);
  perform pg_temp.esito('Sara non vede più pazienti né dati',
    (select count(*)::text from public.pazienti),
    (select count(*) from public.pazienti) = 0);
  execute 'reset role';

  -- Un utente non può eliminare l'account di un altro: la funzione agisce solo su chi chiama
  perform pg_temp.esito('Elena è ancora presente',
    (select count(*)::text from auth.users where id = elena),
    (select count(*) from auth.users where id = elena) = 1);
end;
$$;

select n, prova, ottenuto, esito from esiti order by n;

rollback;
