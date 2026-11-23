-- =============================================================================
-- Cenato · dati di prova per la demo (seed)
-- Solo dati FITTIZI: personaggi degli scenari del RAD (docs/rad/06-scenari.md),
-- nessun dato sanitario reale. Credenziali e uso: docs/demo-dati.md.
--
-- È anche lo SCRIPT DI RESET: si può rieseguire quando si vuole (es. il giorno
-- prima della demo). Cancella SOLO i dati degli account demo (@example.com,
-- dominio che l'app non accetta in registrazione) e li ricrea con date
-- relative a oggi, così semaforo, visite e finestre restano validi.
--
-- Esecuzione: SQL Editor di Supabase (ruolo postgres), dopo le migrazioni.
-- Scheda Trello: [MC] Dati di prova per la demo (seed).
-- =============================================================================

-- Account demo (id fissi per poterli ritrovare e cancellare).
create temp table demo_utenti (id uuid primary key, email text, ruolo text, nome text) on commit drop;
insert into demo_utenti values
  ('00000000-0000-4000-8000-000000000001', 'giulia@example.com', 'nutrizionista', 'Dott.ssa Giulia Rinaldi'),
  ('00000000-0000-4000-8000-000000000002', 'elena@example.com',  'nutrizionista', 'Dott.ssa Elena Ferri'),
  ('00000000-0000-4000-8000-000000000011', 'marco@example.com',  'paziente',      'Marco Esposito'),
  ('00000000-0000-4000-8000-000000000012', 'sara@example.com',   'paziente',      'Sara Romano'),
  ('00000000-0000-4000-8000-000000000013', 'luca@example.com',   'paziente',      'Luca Galli'),
  ('00000000-0000-4000-8000-000000000014', 'paolo@example.com',  'paziente',      'Paolo Greco'),
  ('00000000-0000-4000-8000-000000000015', 'anna@example.com',   'paziente',      'Anna Conti');

-- =============================================================================
-- 1. RESET dei dati demo
-- =============================================================================
do $$
begin
  -- Consente di cancellare i pazienti collegati SOLO in questa transazione.
  perform set_config('cenato.consenti_reset', 'on', true);

  create temp table demo_pazienti on commit drop as
    select p.id from public.pazienti p
    where p.nutrizionista_id in (select id from demo_utenti)
       or p.utente_id in (select id from demo_utenti);

  delete from public.commenti
    where check_in_id in (select id from public.check_in where paziente_id in (select id from demo_pazienti))
       or nutrizionista_id in (select id from demo_utenti);
  delete from public.check_in        where paziente_id in (select id from demo_pazienti);
  delete from public.pasti_extra     where paziente_id in (select id from demo_pazienti);
  delete from public.misure_peso     where paziente_id in (select id from demo_pazienti);
  delete from public.stati_aderenza  where paziente_id in (select id from demo_pazienti);
  delete from public.visite          where paziente_id in (select id from demo_pazienti)
                                        or nutrizionista_id in (select id from demo_utenti);
  delete from public.finestre_prenotazione where paziente_id in (select id from demo_pazienti);
  delete from public.obiettivi       where paziente_id in (select id from demo_pazienti);
  delete from public.piani           where paziente_id in (select id from demo_pazienti);  -- giorni, pasti, voci, alternative a cascata
  delete from public.inviti          where nutrizionista_id in (select id from demo_utenti);
  delete from public.pazienti        where id in (select id from demo_pazienti);
  delete from public.alimenti a
    where (a.id::text like '00000000-0000-4000-a000-%' or a.creato_da in (select id from demo_utenti))
      and not exists (select 1 from public.voci_pasto v where v.alimento_id = a.id)
      and not exists (select 1 from public.alternative x where x.alimento_id = a.id);
  -- Profili, nutrizionisti, abbonamenti, disponibilità, notifiche e identità a cascata.
  delete from auth.users where id in (select id from demo_utenti);
end;
$$;

-- =============================================================================
-- 2. Funzioni di supporto (temporanee, solo per questo script)
-- =============================================================================

-- Crea un account già confermato con password nota (login dall'app).
create or replace function pg_temp.crea_utente(p_id uuid, p_email text, p_ruolo text, p_nome text)
returns void language plpgsql as $f$
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, recovery_token, email_change_token_new, email_change,
    email_change_token_current, phone_change, phone_change_token, reauthentication_token
  ) values (
    '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated', p_email,
    extensions.crypt('CenatoDemo2026!', extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}',
    jsonb_build_object('ruolo', p_ruolo, 'nome', p_nome, 'consenso_dati', true),
    now() - interval '60 days', now(),
    '', '', '', '', '', '', '', ''
  );
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (p_id::text, p_id,
          jsonb_build_object('sub', p_id::text, 'email', p_email, 'email_verified', true),
          'email', now(), now(), now());
end $f$;

-- Prossimo giorno feriale (lun-ven) a partire da una data.
create or replace function pg_temp.feriale(p_data date) returns date language sql as $f$
  select p_data + case extract(isodow from p_data)::int when 6 then 2 when 7 then 1 else 0 end;
$f$;

-- Data e ora locali (Europe/Rome) → timestamptz.
create or replace function pg_temp.alle(p_data date, p_ora time) returns timestamptz language sql as $f$
  select (p_data + p_ora) at time zone 'Europe/Rome';
$f$;

-- Aggiunge una voce al pasto calcolando kcal e macro dall'alimento.
create or replace function pg_temp.voce(p_pasto uuid, p_alimento uuid, p_quantita numeric, p_ordine int)
returns uuid language sql as $f$
  insert into public.voci_pasto (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g, ordine)
  select p_pasto, a.id, p_quantita,
         round(a.kcal_100g * p_quantita / 100, 1), round(a.proteine_100g * p_quantita / 100, 1),
         round(a.carboidrati_100g * p_quantita / 100, 1), round(a.grassi_100g * p_quantita / 100, 1), p_ordine
  from public.alimenti a where a.id = p_alimento
  returning id;
$f$;

create or replace function pg_temp.alt(p_voce uuid, p_alimento uuid, p_quantita numeric) returns void language sql as $f$
  insert into public.alternative (voce_id, alimento_id, quantita_g) values (p_voce, p_alimento, p_quantita);
$f$;

-- Piano settimanale completo (7 giorni × colazione, spuntino, pranzo, cena) con alternative.
create or replace function pg_temp.crea_piano(p_paziente uuid, p_nut uuid, p_inizio date) returns uuid
language plpgsql as $f$
declare
  v_piano uuid; v_giorno uuid; v_pasto uuid; v uuid; d int;
  latte uuid := '00000000-0000-4000-a000-000000000001'; avena uuid := '00000000-0000-4000-a000-000000000002';
  fette uuid := '00000000-0000-4000-a000-000000000003'; yogurt uuid := '00000000-0000-4000-a000-000000000004';
  mela uuid := '00000000-0000-4000-a000-000000000005';  mandorle uuid := '00000000-0000-4000-a000-000000000006';
  pasta uuid := '00000000-0000-4000-a000-000000000007'; riso uuid := '00000000-0000-4000-a000-000000000008';
  pollo uuid := '00000000-0000-4000-a000-000000000009'; salmone uuid := '00000000-0000-4000-a000-000000000010';
  zucchine uuid := '00000000-0000-4000-a000-000000000011'; olio uuid := '00000000-0000-4000-a000-000000000012';
  pane uuid := '00000000-0000-4000-a000-000000000013';  ceci uuid := '00000000-0000-4000-a000-000000000014';
  merluzzo uuid := '00000000-0000-4000-a000-000000000015'; banana uuid := '00000000-0000-4000-a000-000000000016';
begin
  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
  values (p_paziente, p_nut, 1, 'corrente', p_inizio) returning id into v_piano;

  for d in 1..7 loop
    insert into public.giorni (piano_id, giorno_settimana) values (v_piano, d) returning id into v_giorno;

    -- Colazione: latte e fiocchi d'avena (alternativa: fette biscottate)
    insert into public.pasti (giorno_id, tipo, orario, ordine) values (v_giorno, 'colazione', '08:00', 1) returning id into v_pasto;
    perform pg_temp.voce(v_pasto, latte, 200, 1);
    v := pg_temp.voce(v_pasto, avena, 40, 2);
    perform pg_temp.alt(v, fette, 35);

    -- Spuntino: yogurt greco (alternativa: mela) e mandorle
    insert into public.pasti (giorno_id, tipo, orario, ordine) values (v_giorno, 'spuntino', '10:30', 2) returning id into v_pasto;
    v := pg_temp.voce(v_pasto, yogurt, 150, 1);
    perform pg_temp.alt(v, mela, 200);
    perform pg_temp.alt(v, banana, 120);
    perform pg_temp.voce(v_pasto, mandorle, 15, 2);

    -- Pranzo: pasta o riso a giorni alterni, con verdure e olio
    insert into public.pasti (giorno_id, tipo, orario, ordine) values (v_giorno, 'pranzo', '13:00', 3) returning id into v_pasto;
    if d % 2 = 1 then
      v := pg_temp.voce(v_pasto, pasta, 80, 1);
      perform pg_temp.alt(v, pane, 100);
    else
      v := pg_temp.voce(v_pasto, riso, 80, 1);
      perform pg_temp.alt(v, pasta, 80);
      perform pg_temp.voce(v_pasto, ceci, 150, 2);
    end if;
    perform pg_temp.voce(v_pasto, zucchine, 200, 3);
    perform pg_temp.voce(v_pasto, olio, 10, 4);

    -- Cena: secondo a rotazione (alternativa: merluzzo o pollo), verdure, pane
    insert into public.pasti (giorno_id, tipo, orario, ordine) values (v_giorno, 'cena', '20:00', 4) returning id into v_pasto;
    if d % 3 = 0 then
      v := pg_temp.voce(v_pasto, salmone, 150, 1);
      perform pg_temp.alt(v, merluzzo, 200);
    elsif d % 3 = 1 then
      v := pg_temp.voce(v_pasto, pollo, 150, 1);
      perform pg_temp.alt(v, merluzzo, 200);
    else
      v := pg_temp.voce(v_pasto, merluzzo, 200, 1);
      perform pg_temp.alt(v, pollo, 150);
    end if;
    perform pg_temp.voce(v_pasto, zucchine, 200, 2);
    perform pg_temp.voce(v_pasto, pane, 50, 3);
    perform pg_temp.voce(v_pasto, olio, 10, 4);
  end loop;
  return v_piano;
end $f$;

-- Check-in di un pasto del piano corrente nel giorno indicato.
create or replace function pg_temp.check_in(p_paziente uuid, p_data date, p_tipo text, p_stato text, p_etichetta text default null)
returns uuid language plpgsql as $f$
declare v_pasto uuid; v_alt uuid; v_id uuid;
begin
  select pa.id into v_pasto
  from public.piani p join public.giorni g on g.piano_id = p.id join public.pasti pa on pa.giorno_id = g.id
  where p.paziente_id = p_paziente and p.stato = 'corrente'
    and g.giorno_settimana = extract(isodow from p_data) and pa.tipo::text = p_tipo
  limit 1;
  if p_stato = 'alternativa' then
    select a.id into v_alt from public.alternative a join public.voci_pasto v on v.id = a.voce_id
    where v.pasto_id = v_pasto limit 1;
  end if;
  insert into public.check_in (paziente_id, pasto_id, data, stato, alternativa_id, etichetta, creato_il)
  values (p_paziente, v_pasto, p_data, p_stato::public.stato_checkin, v_alt, p_etichetta,
          p_data + case p_tipo when 'colazione' then time '08:20' when 'spuntino' then time '10:45'
                               when 'pranzo' then time '13:40' else time '20:50' end)
  returning id into v_id;
  return v_id;
end $f$;

-- =============================================================================
-- 3. DATI
-- =============================================================================
do $$
declare
  giulia uuid := '00000000-0000-4000-8000-000000000001';
  elena  uuid := '00000000-0000-4000-8000-000000000002';
  u_marco uuid := '00000000-0000-4000-8000-000000000011';
  u_sara  uuid := '00000000-0000-4000-8000-000000000012';
  u_luca  uuid := '00000000-0000-4000-8000-000000000013';
  u_paolo uuid := '00000000-0000-4000-8000-000000000014';
  u_anna  uuid := '00000000-0000-4000-8000-000000000015';
  marco uuid; sara uuid; luca uuid; paolo uuid; anna uuid; invitato uuid;
  pasti text[] := array['colazione', 'spuntino', 'pranzo', 'cena'];
  etichette text[] := array['pizza', 'ristorante', 'dolce', 'aperitivo'];
  d int; m int; dt date; stato text; ci uuid;
  ci_sara_pizza uuid; ci_marco_alt uuid; ci_paolo_pranzo uuid;
begin
  -- ----------------------------------------------------------- account
  perform pg_temp.crea_utente(u.id, u.email, u.ruolo, u.nome) from demo_utenti u;

  -- Giulia: piano Pro annuale (pagamento simulato), visita da 45 minuti.
  update public.nutrizionisti
    set piano_abbonamento = 'pro', periodo_fatturazione = 'annuale',
        titolo = 'Biologa nutrizionista', durata_visita_min = 45
    where id = giulia;
  update public.abbonamenti set fine = now() - interval '30 days' where nutrizionista_id = giulia;
  insert into public.abbonamenti (nutrizionista_id, piano, periodo_fatturazione, importo_cent, inizio)
    values (giulia, 'pro', 'annuale', 25000, now() - interval '30 days');
  -- Elena: piano Free con 1 paziente già collegato → mostra l'errore al limite.
  update public.nutrizionisti set titolo = 'Dietista' where id = elena;

  -- ----------------------------------------------------------- alimenti in cache
  insert into public.alimenti (id, nome, marca, kcal_100g, proteine_100g, carboidrati_100g, grassi_100g, fonte) values
    ('00000000-0000-4000-a000-000000000001', 'Latte parzialmente scremato', null, 46, 3.3, 4.9, 1.6, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000002', 'Fiocchi d''avena', null, 372, 13.5, 58.7, 7.0, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000003', 'Fette biscottate integrali', null, 380, 12.0, 68.0, 5.5, 'open_food_facts'),
    ('00000000-0000-4000-a000-000000000004', 'Yogurt greco 0%', null, 57, 10.0, 3.6, 0.2, 'open_food_facts'),
    ('00000000-0000-4000-a000-000000000005', 'Mela', null, 52, 0.3, 13.8, 0.2, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000006', 'Mandorle', null, 579, 21.2, 21.6, 49.9, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000007', 'Pasta integrale', null, 348, 13.0, 66.0, 2.5, 'open_food_facts'),
    ('00000000-0000-4000-a000-000000000008', 'Riso basmati', null, 350, 8.0, 78.0, 1.0, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000009', 'Petto di pollo', null, 110, 23.3, 0.0, 1.2, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000010', 'Salmone', null, 208, 20.0, 0.0, 13.0, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000011', 'Zucchine', null, 17, 1.2, 3.1, 0.3, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000012', 'Olio extravergine d''oliva', null, 884, 0.0, 0.0, 100.0, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000013', 'Pane integrale', null, 247, 13.0, 41.0, 3.4, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000014', 'Ceci lessati', null, 164, 8.9, 27.4, 2.6, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000015', 'Merluzzo', null, 82, 17.8, 0.0, 0.7, 'personalizzato'),
    ('00000000-0000-4000-a000-000000000016', 'Banana', null, 89, 1.1, 22.8, 0.3, 'personalizzato')
  on conflict (id) do nothing;

  -- ----------------------------------------------------------- pazienti
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_nascita, altezza_cm, obiettivo, data_collegamento, creato_il)
    values (giulia, u_marco, 'attivo', '1991-03-12', 178, 'Perdere 4 kg e mangiare a orari regolari', now() - interval '45 days', now() - interval '46 days')
    returning id into marco;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_nascita, altezza_cm, obiettivo, data_collegamento, creato_il)
    values (giulia, u_sara, 'attivo', '1995-07-28', 165, 'Ridurre gli spuntini fuori pasto', now() - interval '40 days', now() - interval '41 days')
    returning id into sara;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_nascita, altezza_cm, obiettivo, data_collegamento, data_archiviazione, archiviato_da, creato_il)
    values (giulia, u_luca, 'archiviato', '1987-11-02', 182, 'Percorso concluso: mantenimento', now() - interval '90 days', now() - interval '12 days', 'nutrizionista', now() - interval '91 days')
    returning id into luca;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_nascita, altezza_cm, obiettivo, data_collegamento, creato_il)
    values (giulia, u_paolo, 'attivo', '1983-01-19', 175, 'Perdere peso e regolarizzare il pranzo', now() - interval '35 days', now() - interval '36 days')
    returning id into paolo;
  insert into public.pazienti (nutrizionista_id, utente_id, stato, data_nascita, altezza_cm, obiettivo, data_collegamento, creato_il)
    values (elena, u_anna, 'attivo', '1999-09-09', 160, 'Alimentazione equilibrata', now() - interval '20 days', now() - interval '21 days')
    returning id into anna;

  -- Un invito in attesa di Giulia (codice da mostrare nella demo, RF_GI_1).
  insert into public.pazienti (nutrizionista_id, stato, nome) values (giulia, 'invitato', 'Chiara') returning id into invitato;
  insert into public.inviti (nutrizionista_id, paziente_id, codice, scadenza)
    values (giulia, invitato, 'GIULIA26', now() + interval '6 days');

  -- ----------------------------------------------------------- obiettivi (SC_GP_4: Marco 2000/110/230/65)
  insert into public.obiettivi (paziente_id, kcal, proteine_g, carboidrati_g, grassi_g, data_inizio) values
    (marco, 2000, 110, 230, 65, current_date - 44),
    (sara,  1700,  90, 200, 55, current_date - 39),
    (luca,  1900, 100, 220, 60, current_date - 89),
    (paolo, 2300, 130, 260, 75, current_date - 34),
    (anna,  1800,  95, 210, 60, current_date - 19);

  -- ----------------------------------------------------------- piani
  perform pg_temp.crea_piano(marco, giulia, current_date - 44);
  perform pg_temp.crea_piano(sara,  giulia, current_date - 39);
  perform pg_temp.crea_piano(luca,  giulia, current_date - 89);
  perform pg_temp.crea_piano(paolo, giulia, current_date - 34);
  perform pg_temp.crea_piano(anna,  elena,  current_date - 19);

  -- ----------------------------------------------------------- check-in degli ultimi 10 giorni
  for d in 1..10 loop
    dt := current_date - d;
    for m in 1..4 loop
      -- Marco → VERDE: quasi sempre Seguito, Alternativa a colazione ogni 3 giorni.
      stato := case
        when m = 1 and d % 3 = 0 then 'alternativa'
        when d = 4 and m = 4 then 'fuori_piano'
        when d = 8 and m = 2 then 'saltato'
        else 'seguito' end;
      ci := pg_temp.check_in(marco, dt, pasti[m], stato, case when stato = 'fuori_piano' then 'pizza' end);
      if d = 3 and m = 1 then ci_marco_alt := ci; end if;

      -- Sara → GIALLO: spuntino saltato a giorni alterni, cena fuori piano.
      stato := case
        when m = 1 and d % 2 = 0 then 'alternativa'
        when m = 2 and d % 2 = 1 then 'saltato'
        when m = 4 then 'fuori_piano'
        else 'seguito' end;
      ci := pg_temp.check_in(sara, dt, pasti[m], stato,
                             case when stato = 'fuori_piano' then etichette[1 + d % 4] end);
      if d = 1 and m = 4 then ci_sara_pizza := ci; end if;

      -- Paolo → ROSSO: molti pasti saltati o non registrati.
      stato := case
        when m = 1 and d % 2 = 0 then 'seguito'
        when m = 3 then 'saltato'
        when m = 4 and d % 3 = 0 then 'fuori_piano'
        when m = 4 then 'saltato'
        else null end;    -- null = pasto non registrato (vale 0)
      if stato is not null then
        ci := pg_temp.check_in(paolo, dt, pasti[m], stato, case when stato = 'fuori_piano' then 'ristorante' end);
        if d = 2 and m = 3 then ci_paolo_pranzo := ci; end if;
      end if;

      -- Anna (paziente di Elena): costante.
      if d <= 7 then
        perform pg_temp.check_in(anna, dt, pasti[m], case when m = 2 and d = 5 then 'saltato' else 'seguito' end);
      end if;
    end loop;
  end loop;

  -- Oggi: Marco ha già registrato la colazione (schermata Oggi con un pasto fatto).
  perform pg_temp.check_in(marco, current_date, 'colazione', 'seguito');

  -- Luca: storico prima dell'archiviazione.
  for d in 20..30 loop
    for m in 1..4 loop
      perform pg_temp.check_in(luca, current_date - d, pasti[m], case when m = 2 and d % 4 = 0 then 'alternativa' else 'seguito' end);
    end loop;
  end loop;

  -- Pasti extra (RF_GD_6): non contano nell'aderenza.
  insert into public.pasti_extra (paziente_id, data, etichetta, nota) values
    (sara,  current_date - 2, 'aperitivo', 'Aperitivo con colleghi'),
    (marco, current_date - 5, null, 'Gelato con i bambini');

  -- ----------------------------------------------------------- commenti (RF_GC_1)
  insert into public.commenti (check_in_id, nutrizionista_id, testo, creato_il, letto_il) values
    (ci_marco_alt, giulia, 'Ottima scelta l''alternativa: continua così!', now() - interval '2 days', now() - interval '2 days'),
    (ci_sara_pizza, giulia, 'Capita! Domani torna al piano; la prossima volta prova una margherita con verdure.', now() - interval '20 hours', null),
    (ci_paolo_pranzo, giulia, 'Vedo che il pranzo salta spesso: ne parliamo alla prossima visita?', now() - interval '1 day', null);

  -- ----------------------------------------------------------- peso (RF_GM_1)
  insert into public.misure_peso (paziente_id, data, valore_kg, inserita_da)
  select marco, current_date - 7 * i, (array[81.2, 81.6, 82.1, 82.5, 83.0, 83.4, 84.0])[i + 1], u_marco from generate_series(0, 6) i;
  insert into public.misure_peso (paziente_id, data, valore_kg, inserita_da)
  select sara, current_date - 1 - 7 * i, (array[66.9, 67.0, 67.4, 67.6, 68.1, 68.5])[i + 1], u_sara from generate_series(0, 5) i;
  insert into public.misure_peso (paziente_id, data, valore_kg, inserita_da)
  select paolo, current_date - 3 - 7 * i, (array[95.0, 95.4, 94.9, 95.3, 95.6, 95.2])[i + 1], u_paolo from generate_series(0, 5) i;
  insert into public.misure_peso (paziente_id, data, valore_kg, inserita_da)
  select luca, current_date - 15 - 14 * i, (array[76.0, 76.4, 77.1, 78.0])[i + 1], giulia from generate_series(0, 3) i;
  insert into public.misure_peso (paziente_id, data, valore_kg, inserita_da)
  select anna, current_date - 7 * i, (array[58.3, 58.6, 58.8])[i + 1], u_anna from generate_series(0, 2) i;

  -- ----------------------------------------------------------- agenda (RF_GV_*)
  -- Giulia riceve lun-ven 9-13 e mar/gio anche 15-19 (slot da 45 minuti).
  insert into public.disponibilita (nutrizionista_id, giorno_settimana, ora_inizio, ora_fine)
  select giulia, g, time '09:00', time '13:00' from generate_series(1, 5) g
  union all select giulia, 2, time '15:00', time '19:00'
  union all select giulia, 4, time '15:00', time '19:00';
  insert into public.disponibilita (nutrizionista_id, giorno_settimana, ora_inizio, ora_fine)
  select elena, g, '14:00', '18:00' from generate_series(1, 3) g;

  -- Visite: svolte (passate), una fissata da Giulia e una prenotata da Paolo.
  insert into public.visite (nutrizionista_id, paziente_id, inizio, durata_min, stato, origine, nota) values
    (giulia, marco, pg_temp.alle(pg_temp.feriale(current_date - 30), '10:30'), 45, 'svolta', 'nutrizionista', 'Prima visita'),
    (giulia, luca,  pg_temp.alle(pg_temp.feriale(current_date - 40), '09:45'), 45, 'svolta', 'nutrizionista', 'Visita di chiusura'),
    (giulia, paolo, pg_temp.alle(pg_temp.feriale(current_date - 20), '11:15'), 45, 'svolta', 'nutrizionista', null),
    (giulia, sara,  pg_temp.alle(pg_temp.feriale(current_date + 7),  '09:45'), 45, 'fissata', 'nutrizionista', 'Controllo mensile'),
    (giulia, paolo, pg_temp.alle(pg_temp.feriale(current_date + 10), '11:15'), 45, 'prenotata', 'paziente', null);

  -- Finestre di prenotazione: Marco può prenotare ora (demo di SC_GV_*).
  insert into public.finestre_prenotazione (paziente_id, dal, al) values
    (marco, current_date, current_date + 21),
    (sara,  current_date + 20, current_date + 40),
    (paolo, current_date, current_date + 30);

  -- Preferenze dei promemoria (valori predefiniti).
  insert into public.preferenze_notifiche (utente_id)
  select id from demo_utenti where ruolo = 'paziente';
end;
$$;

-- =============================================================================
-- 4. Controllo: semaforo per paziente (media degli ultimi 3 giorni completi)
--    Punti: Seguito 1, Alternativa 1, Fuori piano 0.5, Saltato 0, non registrato 0.
--    Soglie: verde >= 0.8, giallo 0.4-0.8, rosso < 0.4 (CLAUDE.md, RF_GAD_1).
-- =============================================================================
with giorni as (
  select p.id as paziente_id, p.nutrizionista_id, current_date - g as data
  from public.pazienti p, generate_series(1, 3) g
  where p.utente_id in (select id from demo_utenti) and p.stato = 'attivo'
),
previsti as (
  select gi.paziente_id, gi.data, pa.id as pasto_id
  from giorni gi
  join public.piani pi on pi.paziente_id = gi.paziente_id and pi.stato = 'corrente'
  join public.giorni gg on gg.piano_id = pi.id and gg.giorno_settimana = extract(isodow from gi.data)
  join public.pasti pa on pa.giorno_id = gg.id
),
indici as (
  select pr.paziente_id, pr.data,
         avg(case ci.stato when 'seguito' then 1 when 'alternativa' then 1 when 'fuori_piano' then 0.5 else 0 end) as indice
  from previsti pr
  left join public.check_in ci on ci.paziente_id = pr.paziente_id and ci.pasto_id = pr.pasto_id and ci.data = pr.data
  group by pr.paziente_id, pr.data
)
select pr.nome as paziente, n.nome as nutrizionista,
       round(avg(i.indice), 2) as media_3_giorni,
       case when avg(i.indice) >= 0.8 then 'verde' when avg(i.indice) >= 0.4 then 'giallo' else 'rosso' end as semaforo,
       (select max(data) from public.check_in c where c.paziente_id = i.paziente_id) as ultimo_check_in
from indici i
join public.pazienti p on p.id = i.paziente_id
join public.profili pr on pr.id = p.utente_id
join public.profili n on n.id = p.nutrizionista_id
group by i.paziente_id, pr.nome, n.nome
order by media_3_giorni desc;
