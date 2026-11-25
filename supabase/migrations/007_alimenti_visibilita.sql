-- =============================================================================
-- Cenato · 007_alimenti_visibilita.sql
-- Chi vede e chi modifica gli alimenti della cache · RF_GP_3, RF_GP_5, RNF_IN_1
-- Scheda Trello: [MC] Ricerca alimenti (Open Food Facts) con cache.
-- Scelte annotate in docs/decisioni-sviluppo.md (D15), confermate da Mario Celzo.
--
-- Prima (002): tutti gli utenti autenticati leggevano ogni alimento e qualsiasi
-- nutrizionista poteva modificare i valori di quelli di Open Food Facts, cioè di
-- una cache condivisa. Ora:
--   * gli alimenti di Open Food Facts li legge chiunque sia autenticato (sono la
--     cache condivisa, dati pubblici sotto licenza ODbL) e nessun client li
--     modifica: l'app li inserisce e basta;
--   * un alimento PERSONALIZZATO lo vede e lo modifica solo chi lo ha creato.
--     Lo vede anche il paziente, ma soltanto se compare (come voce o come
--     alternativa) in un piano che può leggere: gli serve per la sezione Dieta;
--   * gli alimenti senza proprietario (`creato_da` nullo: i dati di prova del
--     seed) restano leggibili da tutti, così la demo non cambia.
-- =============================================================================

-- L'alimento compare in un piano che l'utente può leggere? (security definer:
-- non passa dalla RLS di voci e alternative, e rispetta quella dei piani.)
create or replace function privato.alimento_in_piano_leggibile(p_alimento uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
           select 1 from public.voci_pasto v
           where v.alimento_id = p_alimento
             and privato.piano_leggibile(privato.piano_del_pasto(v.pasto_id))
         )
      or exists (
           select 1 from public.alternative a
           where a.alimento_id = p_alimento
             and privato.piano_leggibile(privato.piano_della_voce(a.voce_id))
         );
$$;
grant execute on function privato.alimento_in_piano_leggibile(uuid) to authenticated;

drop policy alimenti_select on public.alimenti;
create policy alimenti_select on public.alimenti
  for select to authenticated
  using (
    fonte = 'open_food_facts'
    or creato_da is null
    or creato_da = (select auth.uid())
    or privato.alimento_in_piano_leggibile(id)
  );

drop policy alimenti_insert_nut on public.alimenti;
create policy alimenti_insert_nut on public.alimenti
  for insert to authenticated
  with check (
    privato.e_nutrizionista()
    and (
      (fonte = 'open_food_facts' and (creato_da is null or creato_da = (select auth.uid())))
      or (fonte = 'personalizzato' and creato_da = (select auth.uid()))
    )
  );

drop policy alimenti_update_nut on public.alimenti;
create policy alimenti_update_nut on public.alimenti
  for update to authenticated
  using (
    privato.e_nutrizionista() and fonte = 'personalizzato' and creato_da = (select auth.uid())
  )
  with check (
    privato.e_nutrizionista() and fonte = 'personalizzato' and creato_da = (select auth.uid())
  );
