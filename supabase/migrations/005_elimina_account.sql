-- =============================================================================
-- Cenato · 005_elimina_account.sql
-- Cancellazione dell'account su richiesta dell'interessato (GDPR art. 17).
-- RF_GA_7 · UC_GA_5 · RNF_L_3 · CLAUDE.md regole 3 e 6
-- Scheda Trello: [MC] Profilo ed eliminazione account.
-- Scelte annotate in docs/decisioni-sviluppo.md (confermate da Renato).
--
-- "I pazienti non si eliminano, si archiviano" (regola 3) vale per
-- l'archiviazione fatta dal nutrizionista. La cancellazione chiesta
-- dall'interessato è un'altra cosa: i dati si cancellano davvero.
--
-- PAZIENTE: si cancellano tutti i suoi dati personali e clinici (nome, altezza,
--   data di nascita, obiettivo, piani, obiettivi nutrizionali, check-in, pasti
--   extra, peso, commenti, visite, aderenza) e l'account. Resta una riga SENZA
--   dati personali ("Account eliminato", archiviata) che nel piano Free
--   continua a occupare il posto: la regola "1 paziente a vita" non si aggira.
-- NUTRIZIONISTA: si cancellano i suoi dati (profilo, abbonamenti, disponibilità,
--   modelli, inviti, visite, commenti) e i dati clinici di TUTTI i suoi
--   pazienti, comprese le righe di collegamento. Gli account dei pazienti
--   restano, non sono più collegati e possono accettare un nuovo invito.
-- =============================================================================

-- Cancella i dati clinici dei pazienti indicati (le righe di `pazienti` si
-- trattano a parte). L'ordine rispetta le chiavi esterne.
create or replace function privato.cancella_dati_clinici(p_pazienti uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.commenti
    where check_in_id in (select id from public.check_in where paziente_id = any (p_pazienti));
  delete from public.check_in             where paziente_id = any (p_pazienti);
  delete from public.pasti_extra          where paziente_id = any (p_pazienti);
  delete from public.misure_peso          where paziente_id = any (p_pazienti);
  delete from public.stati_aderenza       where paziente_id = any (p_pazienti);
  delete from public.visite               where paziente_id = any (p_pazienti);
  delete from public.finestre_prenotazione where paziente_id = any (p_pazienti);
  delete from public.obiettivi            where paziente_id = any (p_pazienti);
  -- giorni, pasti, voci e alternative seguono a cascata
  delete from public.piani                where paziente_id = any (p_pazienti);
end;
$$;

-- UC_GA_5 · RF_GA_7: elimina l'account di chi chiama.
create or replace function public.elimina_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_utente uuid := (select auth.uid());
  v_ruolo public.ruolo_utente;
  v_pazienti uuid[];
begin
  if v_utente is null then
    raise exception using errcode = 'CN007', message = 'Devi essere autenticato.';
  end if;
  select ruolo into v_ruolo from public.profili where id = v_utente;
  if not found then
    raise exception using errcode = 'CN007', message = 'Account non trovato.';
  end if;

  -- Consente di cancellare righe di pazienti collegati solo in questa
  -- transazione (trigger pazienti_non_eliminabili, RF_GI_4).
  perform set_config('cenato.consenti_reset', 'on', true);

  if v_ruolo = 'paziente' then
    select coalesce(array_agg(id), '{}') into v_pazienti
    from public.pazienti where utente_id = v_utente;

    perform privato.cancella_dati_clinici(v_pazienti);

    -- Guscio anonimo: nessun dato personale, ma il posto nel Free resta occupato.
    update public.pazienti
    set utente_id = null, nome = 'Account eliminato', data_nascita = null,
        altezza_cm = null, obiettivo = null, stato = 'archiviato',
        data_archiviazione = coalesce(data_archiviazione, now()),
        archiviato_da = 'paziente'
    where utente_id = v_utente and data_collegamento is not null;
    -- Righe mai collegate (nessun invito accettato): nulla da conservare.
    delete from public.pazienti where utente_id = v_utente;
  else
    select coalesce(array_agg(id), '{}') into v_pazienti
    from public.pazienti where nutrizionista_id = v_utente;

    perform privato.cancella_dati_clinici(v_pazienti);
    delete from public.inviti   where nutrizionista_id = v_utente;
    delete from public.visite   where nutrizionista_id = v_utente;
    delete from public.commenti where nutrizionista_id = v_utente;
    delete from public.piani    where nutrizionista_id = v_utente;
    delete from public.pazienti where nutrizionista_id = v_utente;
  end if;

  -- Profilo, abbonamenti, disponibilità, modelli, notifiche e preferenze
  -- seguono a cascata; il nutrizionista resta come autore anonimo degli
  -- alimenti in cache (creato_da diventa null).
  delete from auth.users where id = v_utente;
end;
$$;

revoke execute on function public.elimina_account(), privato.cancella_dati_clinici(uuid[])
  from public, anon, authenticated;
grant execute on function public.elimina_account() to authenticated;
