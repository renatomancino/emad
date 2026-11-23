-- =============================================================================
-- Cenato · 000_profili.sql
-- Profilo dell'utente collegato ad auth.users, con il ruolo.
-- Entity Utente (RAD §3.4.3) · UC_GA_1, UC_GA_2 · RF_GA_1, RF_GA_6 · RNF_L_2
-- =============================================================================

-- Ruolo dell'utente: scelto alla registrazione, non modificabile dopo.
create type public.ruolo_utente as enum ('nutrizionista', 'paziente');

-- Entity Utente: una riga per ogni account di auth.users.
create table public.profili (
  id                uuid primary key references auth.users (id) on delete cascade,
  ruolo             public.ruolo_utente not null,
  nome              text not null check (char_length(trim(nome)) between 1 and 100),
  -- RF_GA_6 / RNF_L_1: momento del consenso esplicito al trattamento dei dati
  -- sanitari (GDPR art. 9). La schermata di consenso è nella fase 1.
  consenso_dati_il  timestamptz,
  creato_il         timestamptz not null default now()
);

comment on table public.profili is
  'Entity Utente (RAD 3.4.3): profilo con ruolo, creato dal trigger su auth.users. UC_GA_1.';

-- Crea il profilo alla registrazione leggendo ruolo, nome e consenso dai
-- metadati passati da supabase.auth.signUp(data: {...}).
create or replace function public.crea_profilo_da_auth()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ruolo text := new.raw_user_meta_data ->> 'ruolo';
  v_nome  text := nullif(trim(coalesce(new.raw_user_meta_data ->> 'nome', '')), '');
begin
  if v_ruolo is null or v_ruolo not in ('nutrizionista', 'paziente') then
    raise exception 'Ruolo mancante o non valido: usa nutrizionista o paziente'
      using errcode = '22023';
  end if;

  insert into public.profili (id, ruolo, nome, consenso_dati_il)
  values (
    new.id,
    v_ruolo::public.ruolo_utente,
    coalesce(v_nome, split_part(new.email, '@', 1)),
    case when (new.raw_user_meta_data ->> 'consenso_dati')::boolean then now() end
  );
  return new;
end;
$$;

create trigger su_nuovo_utente_crea_profilo
  after insert on auth.users
  for each row execute function public.crea_profilo_da_auth();

-- Il ruolo (e l'id) non si cambiano dopo la creazione. Vale per chiunque,
-- anche per chi scrive con la service_role: per cambiare ruolo si crea un
-- nuovo account. La verifica completa con RLS è in 002_rls.sql.
create or replace function public.blocca_cambio_ruolo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.ruolo is distinct from old.ruolo then
    raise exception 'Il ruolo non può essere modificato dopo la registrazione'
      using errcode = '42501';
  end if;
  if new.id is distinct from old.id then
    raise exception 'L''identificativo del profilo non può essere modificato'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profili_ruolo_immutabile
  before update on public.profili
  for each row execute function public.blocca_cambio_ruolo();

-- RLS minima per questa migrazione: ognuno legge e aggiorna solo il proprio
-- profilo. Le policy complete (es. il nutrizionista legge i nomi dei propri
-- pazienti) sono in 002_rls.sql.
alter table public.profili enable row level security;

create policy profili_select_proprio on public.profili
  for select to authenticated
  using (id = (select auth.uid()));

create policy profili_update_proprio on public.profili
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- Le righe si creano solo dal trigger e non si cancellano dall'app.
revoke insert, delete on public.profili from anon, authenticated;
revoke all on public.profili from anon;
