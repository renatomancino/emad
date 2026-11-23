-- =============================================================================
-- Cenato · 001_schema.sql
-- Schema del database dalle Entity e dal Class Diagram del RAD (§3.4.3).
-- Le policy RLS sono in 002_rls.sql: questa migrazione abilita la RLS su ogni
-- tabella (quindi, finché non c'è 002, nessuno legge nulla dall'app).
-- Scheda Trello: [RM] Schema del database.
-- =============================================================================

create extension if not exists btree_gist with schema extensions;

-- Schema per le funzioni interne (supporto alle policy e alle RPC): non è
-- esposto dall'API REST di Supabase, quindi non si chiama dall'app.
create schema if not exists privato;
revoke all on schema privato from public, anon;
grant usage on schema privato to authenticated;

-- -----------------------------------------------------------------------------
-- Costanti modificabili in un solo punto (valori [DA CONFERMARE] nel RAD)
-- -----------------------------------------------------------------------------

-- RF_GAD_4: Free 1 paziente a vita, Start 5 attivi, Pro illimitati (null).
create or replace function public.limite_pazienti(p_piano text)
returns integer
language sql
immutable
set search_path = ''
as $$
  select case p_piano when 'free' then 1 when 'start' then 5 else null end;
$$;

-- UC_GI_1: validità del codice di invito [DA CONFERMARE: 7 giorni].
create or replace function public.giorni_validita_invito()
returns integer language sql immutable set search_path = '' as $$ select 7 $$;

-- RF_GV_9: annullamento della visita da parte del paziente fino a 24 ore prima
-- [DA CONFERMARE].
create or replace function public.ore_minime_annullamento()
returns integer language sql immutable set search_path = '' as $$ select 24 $$;

-- -----------------------------------------------------------------------------
-- Enum degli stati (RAD §3.4.3 e StateChart §3.4.4.2)
-- -----------------------------------------------------------------------------
create type public.stato_paziente        as enum ('invitato', 'attivo', 'archiviato');           -- SCD_3
create type public.stato_invito          as enum ('creato', 'utilizzato', 'scaduto', 'revocato'); -- SCD_1
create type public.stato_checkin         as enum ('seguito', 'alternativa', 'fuori_piano', 'saltato'); -- RF_GD_1
create type public.stato_visita          as enum ('fissata', 'prenotata', 'annullata', 'svolta'); -- SCD_2
create type public.origine_visita        as enum ('nutrizionista', 'paziente');                  -- Entity Appuntamento
create type public.piano_abbonamento     as enum ('free', 'start', 'pro');                       -- RF_GAD_4
create type public.periodo_fatturazione  as enum ('mensile', 'annuale');                         -- RF_GAD_5
-- Entity PastoPrevisto (RAD §3.4.3): colazione, spuntino, pranzo, merenda, cena.
create type public.tipo_pasto            as enum ('colazione', 'spuntino', 'pranzo', 'merenda', 'cena');
create type public.stato_piano           as enum ('bozza', 'corrente', 'superato');              -- RF_GP_7, RF_GP_11
create type public.fonte_alimento        as enum ('open_food_facts', 'personalizzato');          -- RF_GP_3, RF_GP_5
create type public.tipo_modello          as enum ('pasto', 'piano');                             -- RF_GP_9
create type public.colore_semaforo       as enum ('verde', 'giallo', 'rosso');                   -- RF_GAD_1
create type public.tipo_notifica         as enum (                                               -- GN
  'promemoria_pasto', 'promemoria_visita', 'commento', 'nuovo_piano',
  'visita_fissata', 'visita_spostata', 'visita_annullata', 'visita_prenotata',
  'finestra_prenotazione', 'inattivita'
);

-- -----------------------------------------------------------------------------
-- Funzioni di servizio
-- -----------------------------------------------------------------------------
create or replace function public.imposta_aggiornato_il()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.aggiornato_il := now();
  return new;
end;
$$;

-- =============================================================================
-- Gestione Account e Abbonamento
-- =============================================================================

-- Entity Nutrizionista (+ PianoAbbonamento corrente) · UC_GA_1, UC_GAD_3
create table public.nutrizionisti (
  id                     uuid primary key references public.profili (id) on delete cascade,
  titolo                 text check (char_length(titolo) <= 80),
  piano_abbonamento      public.piano_abbonamento not null default 'free',
  periodo_fatturazione   public.periodo_fatturazione,
  durata_visita_min      integer not null default 45 check (durata_visita_min between 10 and 240),
  creato_il              timestamptz not null default now(),
  aggiornato_il          timestamptz not null default now(),
  -- Il Free non ha periodo di fatturazione; Start e Pro sì.
  constraint nutrizionisti_periodo_coerente check (
    (piano_abbonamento = 'free') = (periodo_fatturazione is null)
  )
);
comment on table public.nutrizionisti is
  'Entity Nutrizionista e piano di abbonamento corrente (RAD 3.4.3). UC_GA_1, UC_GAD_3, RF_GAD_4.';

-- Storico dei cambi di piano con pagamento simulato · RF_GAD_5, UC_GAD_3
create table public.abbonamenti (
  id                     uuid primary key default gen_random_uuid(),
  nutrizionista_id       uuid not null references public.nutrizionisti (id) on delete cascade,
  piano                  public.piano_abbonamento not null,
  periodo_fatturazione   public.periodo_fatturazione,
  importo_cent           integer not null default 0 check (importo_cent >= 0),
  pagamento_simulato     boolean not null default true check (pagamento_simulato),
  inizio                 timestamptz not null default now(),
  fine                   timestamptz,
  creato_il              timestamptz not null default now()
);
comment on table public.abbonamenti is
  'Entity PianoAbbonamento: storico dei piani con pagamento SIMULATO (RF_GAD_5).';
create index abbonamenti_nutrizionista_idx on public.abbonamenti (nutrizionista_id, inizio desc);

-- Alla registrazione il nutrizionista ha il piano Free (UC_GA_1, uscita).
create or replace function public.crea_nutrizionista_da_profilo()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.ruolo = 'nutrizionista' then
    insert into public.nutrizionisti (id) values (new.id);
    insert into public.abbonamenti (nutrizionista_id, piano) values (new.id, 'free');
  end if;
  return new;
end;
$$;

create trigger su_nuovo_profilo_crea_nutrizionista
  after insert on public.profili
  for each row execute function public.crea_nutrizionista_da_profilo();

-- =============================================================================
-- Gestione Inviti e Pazienti
-- =============================================================================

-- Entity Paziente: il collegamento di una persona a un nutrizionista, con stato.
-- Riga creata all'invito (stato Invitato, utente ancora sconosciuto), collegata
-- all'utente quando accetta (Attivo). Un paziente collegato non si elimina mai.
-- UC_GI_1..5, SCD_3, RF_GI_4, RF_GI_7
create table public.pazienti (
  id                  uuid primary key default gen_random_uuid(),
  nutrizionista_id    uuid not null references public.nutrizionisti (id),
  utente_id           uuid references public.profili (id),
  stato               public.stato_paziente not null default 'invitato',
  nome                text check (char_length(nome) <= 100),   -- nome indicato dal NUT all'invito
  data_nascita        date,
  altezza_cm          numeric(4,1) check (altezza_cm between 50 and 250),
  obiettivo           text check (char_length(obiettivo) <= 500),
  data_collegamento   timestamptz,   -- invito accettato: conta per il limite Free (RF_GAD_4)
  data_archiviazione  timestamptz,
  creato_il           timestamptz not null default now(),
  aggiornato_il       timestamptz not null default now(),
  constraint pazienti_attivo_collegato check (
    stato <> 'attivo' or (utente_id is not null and data_collegamento is not null)
  ),
  constraint pazienti_archiviato_coerente check (
    stato <> 'archiviato' or (data_collegamento is not null and data_archiviazione is not null)
  )
);
comment on table public.pazienti is
  'Entity Paziente (collegamento a un nutrizionista con stato Invitato/Attivo/Archiviato). UC_GI_1-5, SCD_3. Mai eliminato dopo il collegamento.';
comment on column public.pazienti.data_collegamento is
  'Momento in cui il paziente ha accettato l''invito. Il piano Free conta tutte le righe con questo campo valorizzato (Nutrizionista.pazientiInvitatiTotali).';

-- Una persona è collegata al massimo a un nutrizionista alla volta.
create unique index pazienti_un_collegamento_aperto
  on public.pazienti (utente_id) where utente_id is not null and stato <> 'archiviato';
create index pazienti_nutrizionista_stato_idx on public.pazienti (nutrizionista_id, stato);

-- I pazienti collegati non si eliminano (RF_GI_4). L'unica eccezione è lo
-- script di reset dei dati di prova, che imposta cenato.consenti_reset = on.
create or replace function public.blocca_eliminazione_paziente()
returns trigger language plpgsql set search_path = '' as $$
begin
  if old.data_collegamento is not null
     and coalesce(current_setting('cenato.consenti_reset', true), 'off') <> 'on' then
    raise exception 'Un paziente collegato non si elimina: archivialo (RF_GI_4)'
      using errcode = '42501';
  end if;
  return old;
end;
$$;

create trigger pazienti_non_eliminabili
  before delete on public.pazienti
  for each row execute function public.blocca_eliminazione_paziente();

-- Numero di pazienti che hanno accettato un invito (anche se poi archiviati):
-- è Nutrizionista.pazientiInvitatiTotali del Class Diagram, per il Free.
create or replace function privato.pazienti_invitati_totali(p_nutrizionista uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.pazienti
  where nutrizionista_id = p_nutrizionista and data_collegamento is not null;
$$;

-- Entity Invito · UC_GI_1, UC_GI_2, SCD_1, RF_GI_8
create table public.inviti (
  id                uuid primary key default gen_random_uuid(),
  nutrizionista_id  uuid not null references public.nutrizionisti (id),
  paziente_id       uuid not null unique references public.pazienti (id) on delete cascade,
  codice            text not null unique check (codice ~ '^[A-Z0-9]{6,12}$'),
  stato             public.stato_invito not null default 'creato',
  scadenza          timestamptz not null default now() + make_interval(days => public.giorni_validita_invito()),
  creato_il         timestamptz not null default now(),
  utilizzato_il     timestamptz,
  revocato_il       timestamptz
);
comment on table public.inviti is 'Entity Invito (codice e link) con stati SCD_1. UC_GI_1, UC_GI_2, RF_GI_8.';
create index inviti_nutrizionista_stato_idx on public.inviti (nutrizionista_id, stato);

-- =============================================================================
-- Gestione Piano
-- =============================================================================

-- Entity ObiettivoNutrizionale, con storico (una riga per ogni modifica) · RF_GP_16, UC_GP_6
create table public.obiettivi (
  id              uuid primary key default gen_random_uuid(),
  paziente_id     uuid not null references public.pazienti (id),
  kcal            integer not null check (kcal between 500 and 6000),
  proteine_g      numeric(5,1) not null check (proteine_g >= 0),
  carboidrati_g   numeric(5,1) not null check (carboidrati_g >= 0),
  grassi_g        numeric(5,1) not null check (grassi_g >= 0),
  data_inizio     date not null default current_date,
  creato_il       timestamptz not null default now()
);
comment on table public.obiettivi is 'Entity ObiettivoNutrizionale con storico. RF_GP_16, UC_GP_6.';
create index obiettivi_paziente_idx on public.obiettivi (paziente_id, data_inizio desc);

-- Entity Alimento: cache di Open Food Facts e alimenti personalizzati · RF_GP_3-5, RNF_IN_1, RNF_L_5
create table public.alimenti (
  id                 uuid primary key default gen_random_uuid(),
  nome               text not null check (char_length(nome) between 1 and 200),
  marca              text check (char_length(marca) <= 120),
  codice_barre       text unique check (codice_barre ~ '^[0-9]{6,14}$'),
  kcal_100g          numeric(6,1) not null check (kcal_100g >= 0),
  proteine_100g      numeric(5,1) not null check (proteine_100g >= 0),
  carboidrati_100g   numeric(5,1) not null check (carboidrati_100g >= 0),
  grassi_100g        numeric(5,1) not null check (grassi_100g >= 0),
  fonte              public.fonte_alimento not null,
  creato_da          uuid references public.nutrizionisti (id) on delete set null,
  creato_il          timestamptz not null default now(),
  aggiornato_il      timestamptz not null default now()
);
comment on table public.alimenti is
  'Entity Alimento: cache Open Food Facts (licenza ODbL, campo fonte) e alimenti personalizzati. RF_GP_3, RF_GP_4, RF_GP_5.';
create index alimenti_nome_idx on public.alimenti (lower(nome) text_pattern_ops);

-- Entity PianoAlimentare con versioni · RF_GP_1, RF_GP_7, UC_GP_1
create table public.piani (
  id                uuid primary key default gen_random_uuid(),
  paziente_id       uuid not null references public.pazienti (id),
  nutrizionista_id  uuid not null references public.nutrizionisti (id),
  versione          integer not null check (versione > 0),
  stato             public.stato_piano not null default 'bozza',
  data_inizio       date,
  data_fine         date,
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  unique (paziente_id, versione),
  constraint piani_date_coerenti check (data_fine is null or data_inizio is null or data_fine >= data_inizio),
  constraint piani_corrente_con_data check (stato <> 'corrente' or data_inizio is not null)
);
comment on table public.piani is
  'Entity PianoAlimentare con versioni: il paziente vede la versione corrente (RF_GP_7). UC_GP_1.';
-- Una sola versione corrente per paziente (RF_GP_7).
create unique index piani_un_corrente_per_paziente on public.piani (paziente_id) where stato = 'corrente';
create index piani_nutrizionista_idx on public.piani (nutrizionista_id);

-- Giorni del piano (1 = lunedì … 7 = domenica) · RF_GP_1, RF_GP_13
create table public.giorni (
  id                 uuid primary key default gen_random_uuid(),
  piano_id           uuid not null references public.piani (id) on delete cascade,
  giorno_settimana   smallint not null check (giorno_settimana between 1 and 7),
  unique (piano_id, giorno_settimana)
);
comment on table public.giorni is 'Giorni del PianoAlimentare (1 = lunedì). RF_GP_1, RF_GP_13.';

-- Entity PastoPrevisto · RF_GP_1, UC_GP_2
create table public.pasti (
  id         uuid primary key default gen_random_uuid(),
  giorno_id  uuid not null references public.giorni (id) on delete cascade,
  tipo       public.tipo_pasto not null,
  orario     time,
  ordine     smallint not null default 0
);
comment on table public.pasti is 'Entity PastoPrevisto. RF_GP_1, UC_GP_2. Un check-in lo rende non eliminabile.';
create index pasti_giorno_idx on public.pasti (giorno_id, ordine);

-- Entity VocePasto: alimento e quantità, con kcal e macro calcolati · RF_GP_2
create table public.voci_pasto (
  id              uuid primary key default gen_random_uuid(),
  pasto_id        uuid not null references public.pasti (id) on delete cascade,
  alimento_id     uuid not null references public.alimenti (id),
  quantita_g      numeric(6,1) not null check (quantita_g > 0),
  kcal            numeric(6,1) not null check (kcal >= 0),
  proteine_g      numeric(5,1) not null check (proteine_g >= 0),
  carboidrati_g   numeric(5,1) not null check (carboidrati_g >= 0),
  grassi_g        numeric(5,1) not null check (grassi_g >= 0),
  ordine          smallint not null default 0
);
comment on table public.voci_pasto is 'Entity VocePasto con kcal e macro calcolati. RF_GP_2, UC_GP_2.';
create index voci_pasto_pasto_idx on public.voci_pasto (pasto_id, ordine);
create index voci_pasto_alimento_idx on public.voci_pasto (alimento_id);

-- Entity Alternativa: sostituto ammesso per una voce · RF_GP_6, RF_GD_2
create table public.alternative (
  id           uuid primary key default gen_random_uuid(),
  voce_id      uuid not null references public.voci_pasto (id) on delete cascade,
  alimento_id  uuid not null references public.alimenti (id),
  quantita_g   numeric(6,1) not null check (quantita_g > 0)
);
comment on table public.alternative is
  'Entity Alternativa: uniche scelte offerte al paziente nel check-in Alternativa. RF_GP_6, RF_GD_2.';
create index alternative_voce_idx on public.alternative (voce_id);
create index alternative_alimento_idx on public.alternative (alimento_id);

-- Entity ModelloPiano: pasto salvato o piano modello riutilizzabile · RF_GP_9
create table public.modelli_piano (
  id                uuid primary key default gen_random_uuid(),
  nutrizionista_id  uuid not null references public.nutrizionisti (id) on delete cascade,
  nome              text not null check (char_length(nome) between 1 and 120),
  tipo              public.tipo_modello not null,
  -- Copia della struttura (giorni/pasti/voci/alternative) in JSON: un modello
  -- non è legato a un paziente e non deve cambiare se il piano originale cambia.
  contenuto         jsonb not null,
  creato_il         timestamptz not null default now()
);
comment on table public.modelli_piano is
  'Entity ModelloPiano: pasti salvati (tipo pasto) e piani modello (tipo piano). RF_GP_9.';
create index modelli_piano_nutrizionista_idx on public.modelli_piano (nutrizionista_id, tipo);

-- =============================================================================
-- Gestione Check-in
-- =============================================================================

-- Entity CheckIn: un solo check-in per paziente, pasto previsto e giorno · RF_GD_1-3, RF_GD_7, UC_GD_1
create table public.check_in (
  id               uuid primary key default gen_random_uuid(),
  paziente_id      uuid not null references public.pazienti (id),
  pasto_id         uuid not null references public.pasti (id),
  data             date not null,
  stato            public.stato_checkin not null,
  alternativa_id   uuid references public.alternative (id),
  etichetta        text check (char_length(etichetta) <= 40),   -- etichetta rapida del Fuori piano (RF_GD_7)
  nota             text check (char_length(nota) <= 280),
  creato_il        timestamptz not null default now(),
  aggiornato_il    timestamptz not null default now(),
  unique (paziente_id, pasto_id, data),
  constraint check_in_alternativa_coerente check ((stato = 'alternativa') = (alternativa_id is not null)),
  constraint check_in_etichetta_solo_fuori_piano check (etichetta is null or stato = 'fuori_piano')
);
comment on table public.check_in is
  'Entity CheckIn a quattro stati (Seguito 1, Alternativa 1, Fuori piano 0.5, Saltato 0). RF_GD_1, UC_GD_1. fotoUrl non incluso: RF_GD_5 è priorità B.';
create index check_in_paziente_data_idx on public.check_in (paziente_id, data desc);
create index check_in_pasto_idx on public.check_in (pasto_id);
create index check_in_alternativa_idx on public.check_in (alternativa_id);

-- Il pasto deve appartenere a un piano del paziente e l'alternativa a quel pasto.
create or replace function public.verifica_check_in()
returns trigger language plpgsql set search_path = '' as $$
begin
  if not exists (
    select 1 from public.pasti pa
    join public.giorni g on g.id = pa.giorno_id
    join public.piani p on p.id = g.piano_id
    where pa.id = new.pasto_id and p.paziente_id = new.paziente_id
  ) then
    raise exception 'Il pasto non appartiene al piano di questo paziente'
      using errcode = '23514';
  end if;

  if new.alternativa_id is not null and not exists (
    select 1 from public.alternative a
    join public.voci_pasto v on v.id = a.voce_id
    where a.id = new.alternativa_id and v.pasto_id = new.pasto_id
  ) then
    raise exception 'L''alternativa scelta non è tra quelle previste per il pasto (RF_GD_2)'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger check_in_verifica
  before insert or update on public.check_in
  for each row execute function public.verifica_check_in();

-- Entity PastoExtra: pasto non previsto, NON entra nell'aderenza · RF_GD_6, UC_GD_2
create table public.pasti_extra (
  id           uuid primary key default gen_random_uuid(),
  paziente_id  uuid not null references public.pazienti (id),
  data         date not null,
  etichetta    text check (char_length(etichetta) <= 40),
  nota         text check (char_length(nota) <= 280),
  creato_il    timestamptz not null default now(),
  constraint pasti_extra_descritto check (etichetta is not null or nota is not null)
);
comment on table public.pasti_extra is
  'Entity PastoExtra: distinto dai check-in, non modifica l''indice di aderenza (RF_GD_6).';
create index pasti_extra_paziente_data_idx on public.pasti_extra (paziente_id, data desc);

-- =============================================================================
-- Gestione Commenti
-- =============================================================================

-- Entity Commento su un check-in · RF_GC_1, RF_GC_2
create table public.commenti (
  id                uuid primary key default gen_random_uuid(),
  check_in_id       uuid not null references public.check_in (id),
  nutrizionista_id  uuid not null references public.nutrizionisti (id),
  testo             text not null check (char_length(trim(testo)) between 1 and 1000),
  creato_il         timestamptz not null default now(),
  letto_il          timestamptz
);
comment on table public.commenti is 'Entity Commento del nutrizionista su un check-in. RF_GC_1, RF_GC_2.';
create index commenti_check_in_idx on public.commenti (check_in_id);
create index commenti_nutrizionista_idx on public.commenti (nutrizionista_id, creato_il desc);

-- =============================================================================
-- Gestione Misure e Andamento
-- =============================================================================

-- Entity MisuraPeso · RF_GM_1, RF_GM_2
create table public.misure_peso (
  id            uuid primary key default gen_random_uuid(),
  paziente_id   uuid not null references public.pazienti (id),
  data          date not null,
  valore_kg     numeric(4,1) not null check (valore_kg between 20 and 400),
  inserita_da   uuid references public.profili (id) on delete set null,
  creato_il     timestamptz not null default now(),
  unique (paziente_id, data)
);
comment on table public.misure_peso is 'Entity MisuraPeso (una per giorno). RF_GM_1. Misure aggiuntive (RF_GM_3) escluse: priorità B.';

-- Entity StatoAderenza: indice giornaliero e colore del semaforo · RF_GAD_1
-- Calcolato dalla scheda "Calcolo aderenza, semaforo e dashboard" (fase 3).
create table public.stati_aderenza (
  paziente_id    uuid not null references public.pazienti (id),
  data           date not null,
  indice         numeric(4,3) not null check (indice between 0 and 1),
  colore         public.colore_semaforo not null,
  calcolato_il   timestamptz not null default now(),
  primary key (paziente_id, data)
);
comment on table public.stati_aderenza is
  'Entity StatoAderenza: indice e semaforo per giorno. Indicatore di attenzione, non misura clinica. RF_GAD_1.';

-- =============================================================================
-- Gestione Notifiche
-- =============================================================================

-- Entity Notifica · UC_GN_1, RF_GN_1-6
create table public.notifiche (
  id            uuid primary key default gen_random_uuid(),
  utente_id     uuid not null references public.profili (id) on delete cascade,
  tipo          public.tipo_notifica not null,
  titolo        text not null check (char_length(titolo) <= 120),
  testo         text check (char_length(testo) <= 500),
  riferimento   jsonb,      -- es. {"visita_id": "..."} per aprire la schermata giusta
  orario        timestamptz not null default now(),
  esito         text not null default 'programmata' check (esito in ('programmata', 'inviata', 'errore')),
  letta_il      timestamptz,
  creato_il     timestamptz not null default now()
);
comment on table public.notifiche is 'Entity Notifica: tipo, orario, esito. UC_GN_1. Nessun dato sanitario nel testo.';
create index notifiche_utente_orario_idx on public.notifiche (utente_id, orario desc);

-- Entity PreferenzeNotifiche · RF_GN_2, UC_GN_2
create table public.preferenze_notifiche (
  utente_id            uuid primary key references public.profili (id) on delete cascade,
  promemoria_pasti     boolean not null default true,
  promemoria_visite    boolean not null default true,
  orari                jsonb not null default '{"colazione": "08:00", "pranzo": "13:00", "cena": "20:00"}',
  aggiornato_il        timestamptz not null default now()
);
comment on table public.preferenze_notifiche is 'Entity PreferenzeNotifiche: orari e attivazione dei promemoria. RF_GN_2.';

-- =============================================================================
-- Gestione Visite (Agenda)
-- =============================================================================

-- Entity Disponibilita: fasce orarie settimanali · RF_GV_6, UC_GV_3
create table public.disponibilita (
  id                 uuid primary key default gen_random_uuid(),
  nutrizionista_id   uuid not null references public.nutrizionisti (id) on delete cascade,
  giorno_settimana   smallint not null check (giorno_settimana between 1 and 7),
  ora_inizio         time not null,
  ora_fine           time not null,
  constraint disponibilita_orari_coerenti check (ora_fine > ora_inizio)
);
comment on table public.disponibilita is
  'Entity Disponibilita (1 = lunedì). Gli Slot si ricavano da qui e dalla durata della visita. RF_GV_6.';
create index disponibilita_nutrizionista_idx on public.disponibilita (nutrizionista_id, giorno_settimana);

-- Finestra di prenotazione del paziente (Paziente.finestraPrenotazioneDal/Al) · RF_GV_7
create table public.finestre_prenotazione (
  paziente_id     uuid primary key references public.pazienti (id),
  dal             date not null,
  al              date not null,
  aggiornato_il   timestamptz not null default now(),
  constraint finestre_date_coerenti check (al >= dal)
);
comment on table public.finestre_prenotazione is
  'Periodo in cui il paziente può prenotare la prossima visita (RF_GV_7, [DA CONFERMARE]).';

-- Entity Appuntamento · RF_GV_1-9, SCD_2, RNF_A_6
create table public.visite (
  id                uuid primary key default gen_random_uuid(),
  nutrizionista_id  uuid not null references public.nutrizionisti (id),
  paziente_id       uuid not null references public.pazienti (id),
  inizio            timestamptz not null,
  durata_min        integer not null check (durata_min between 10 and 240),
  fine              timestamptz not null,   -- calcolata dal trigger: inizio + durata
  stato             public.stato_visita not null,
  origine           public.origine_visita not null,
  nota              text check (char_length(nota) <= 500),
  creato_il         timestamptz not null default now(),
  aggiornato_il     timestamptz not null default now(),
  annullata_il      timestamptz,
  constraint visite_fine_dopo_inizio check (fine > inizio),
  -- RNF_A_6: lo stesso slot del nutrizionista non può essere occupato da due
  -- visite non annullate (anche solo in parte sovrapposte).
  constraint visite_slot_unico exclude using gist (
    nutrizionista_id with =,
    tstzrange(inizio, fine) with &&
  ) where (stato in ('fissata', 'prenotata'))
);
comment on table public.visite is
  'Entity Appuntamento con stati SCD_2. Vincoli: slot unico (RNF_A_6) e una sola visita futura per paziente (RF_GV_8).';
create index visite_paziente_inizio_idx on public.visite (paziente_id, inizio desc);
create index visite_nutrizionista_inizio_idx on public.visite (nutrizionista_id, inizio);
create index visite_stato_idx on public.visite (stato);

-- Calcola la fine, verifica che il paziente sia del nutrizionista e che non
-- abbia già un'altra visita futura attiva (RF_GV_8, SCD_2).
create or replace function public.verifica_visita()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.fine := new.inizio + make_interval(mins => new.durata_min);

  if not exists (
    select 1 from public.pazienti
    where id = new.paziente_id and nutrizionista_id = new.nutrizionista_id
  ) then
    raise exception 'Il paziente non è seguito da questo nutrizionista'
      using errcode = '23514';
  end if;

  if new.stato in ('fissata', 'prenotata') and new.fine > now() then
    -- Serializza le richieste dello stesso paziente (due prenotazioni insieme).
    perform pg_advisory_xact_lock(hashtextextended(new.paziente_id::text, 0));
    if exists (
      select 1 from public.visite v
      where v.paziente_id = new.paziente_id
        and v.id <> new.id
        and v.stato in ('fissata', 'prenotata')
        and v.fine > now()
    ) then
      raise exception 'Il paziente ha già una visita futura: annullala o spostala prima (RF_GV_8)'
        using errcode = '23P01', hint = 'CN004';
    end if;
  end if;
  return new;
end;
$$;

create trigger visite_verifica
  before insert or update on public.visite
  for each row execute function public.verifica_visita();

-- -----------------------------------------------------------------------------
-- aggiornato_il automatico
-- -----------------------------------------------------------------------------
create trigger nutrizionisti_aggiornato_il before update on public.nutrizionisti
  for each row execute function public.imposta_aggiornato_il();
create trigger pazienti_aggiornato_il before update on public.pazienti
  for each row execute function public.imposta_aggiornato_il();
create trigger alimenti_aggiornato_il before update on public.alimenti
  for each row execute function public.imposta_aggiornato_il();
create trigger piani_aggiornato_il before update on public.piani
  for each row execute function public.imposta_aggiornato_il();
create trigger check_in_aggiornato_il before update on public.check_in
  for each row execute function public.imposta_aggiornato_il();
create trigger preferenze_aggiornato_il before update on public.preferenze_notifiche
  for each row execute function public.imposta_aggiornato_il();
create trigger finestre_aggiornato_il before update on public.finestre_prenotazione
  for each row execute function public.imposta_aggiornato_il();
create trigger visite_aggiornato_il before update on public.visite
  for each row execute function public.imposta_aggiornato_il();

-- -----------------------------------------------------------------------------
-- RLS attiva su ogni tabella fin da subito (le policy sono in 002_rls.sql).
-- -----------------------------------------------------------------------------
alter table public.nutrizionisti          enable row level security;
alter table public.abbonamenti            enable row level security;
alter table public.pazienti               enable row level security;
alter table public.inviti                 enable row level security;
alter table public.obiettivi              enable row level security;
alter table public.alimenti               enable row level security;
alter table public.piani                  enable row level security;
alter table public.giorni                 enable row level security;
alter table public.pasti                  enable row level security;
alter table public.voci_pasto             enable row level security;
alter table public.alternative            enable row level security;
alter table public.modelli_piano          enable row level security;
alter table public.check_in               enable row level security;
alter table public.pasti_extra            enable row level security;
alter table public.commenti               enable row level security;
alter table public.misure_peso            enable row level security;
alter table public.stati_aderenza         enable row level security;
alter table public.notifiche              enable row level security;
alter table public.preferenze_notifiche   enable row level security;
alter table public.disponibilita          enable row level security;
alter table public.finestre_prenotazione  enable row level security;
alter table public.visite                 enable row level security;
