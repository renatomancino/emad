-- =============================================================================
-- Cenato · 006_alimenti_nutrizionista.sql
-- Alimenti recenti e preferiti di ogni nutrizionista · RF_GP_14 · UC_GP_3
-- Scheda Trello: [MC] Ricerca alimenti (Open Food Facts) con cache.
--
-- La tabella `alimenti` è la cache condivisa (RF_GP_3, RNF_IN_1). Qui si tiene,
-- per ciascun nutrizionista, quali alimenti ha usato di recente (`ultimo_uso`)
-- e quali ha segnato con la stella (`preferito`). Una riga per coppia
-- nutrizionista-alimento; si crea la prima volta che l'alimento viene scelto.
-- Ogni nutrizionista vede e modifica solo le proprie righe (regola 6).
-- =============================================================================

create table public.alimenti_nutrizionista (
  nutrizionista_id  uuid not null references public.nutrizionisti (id) on delete cascade,
  alimento_id       uuid not null references public.alimenti (id) on delete cascade,
  preferito         boolean not null default false,
  ultimo_uso        timestamptz not null default now(),
  primary key (nutrizionista_id, alimento_id)
);
comment on table public.alimenti_nutrizionista is
  'Alimenti recenti (ultimo_uso) e preferiti di un nutrizionista. RF_GP_14, UC_GP_3.';
create index alimenti_nutrizionista_uso_idx
  on public.alimenti_nutrizionista (nutrizionista_id, ultimo_uso desc);

alter table public.alimenti_nutrizionista enable row level security;

-- Privilegi di base: niente ad anon; ad authenticated solo ciò che serve.
revoke all on public.alimenti_nutrizionista from anon, authenticated;
grant select, insert, update, delete on public.alimenti_nutrizionista to authenticated;

create policy alimenti_nutrizionista_nut on public.alimenti_nutrizionista
  for all to authenticated
  using (nutrizionista_id = (select auth.uid()))
  with check (nutrizionista_id = (select auth.uid()) and privato.e_nutrizionista());
