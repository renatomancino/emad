# Passaggio di consegne: prova di `006` e `007` sul Supabase del gruppo

Per chi apre una sessione di Claude Code **sul computer di Mario**, con Chrome collegato (`claude --chrome`). Leggi anche `CLAUDE.md` (regole di prodotto) e `docs/prova-alimenti.md` (checklist completa).

## Contesto in breve

- App Flutter **Cenato** (coaching nutrizionista ↔ paziente), esame EMAD. Supabase in regione UE con RLS su ogni tabella.
- Branch di lavoro: `mario/fase-2-ricerca-alimenti-open-food-facts-con-cache` ([PR #2](https://github.com/renatomancino/emad/pull/2), in **bozza**), che parte da `mario/estetical-fix` ([PR #1](https://github.com/renatomancino/emad/pull/1), restyling grafico).
- La PR #2 aggiunge la ricerca alimenti (Open Food Facts con cache) e **due migrazioni nuove** che finora sono state provate **solo su un PostgreSQL locale con lo schema `auth` simulato**, mai sul progetto Supabase vero:
  - `supabase/migrations/006_alimenti_nutrizionista.sql`: nuova tabella `alimenti_nutrizionista` (recenti e preferiti), con RLS.
  - `supabase/migrations/007_alimenti_visibilita.sql`: **sostituisce tre policy esistenti su `alimenti`** (`alimenti_select`, `alimenti_insert_nut`, `alimenti_update_nut`) e crea la funzione `privato.alimento_in_piano_leggibile`. Gli alimenti personalizzati diventano visibili solo a chi li ha creato (e al paziente se stanno nel suo piano); quelli di Open Food Facts non si modificano più dai client.
- Le migrazioni `000`–`005` sono già applicate sul progetto del gruppo (verifica, vedi sotto).

## Il compito

1. Apri in Chrome la dashboard Supabase e scegli **il progetto di Cenato** (regione `eu-west-1`, Postgres 17; ha le tabelle `profili`, `pazienti`, `alimenti`, `piani`...). **Non** usare un progetto di altro nome (nell'account di Mario esiste anche "Subly": non è questo). Se il progetto è in pausa, riattivalo dalla dashboard e aspetta che sia attivo.
2. **Controllo preliminare** (SQL Editor, sola lettura): le tabelle `public.alimenti`, `public.piani`, `public.voci_pasto`, `public.alternative` esistono, la funzione `privato.piano_leggibile(uuid)` esiste, e `alimenti_nutrizionista` **non** esiste ancora. Se qualcosa non torna, **fermati e riferisci**.
3. Esegui nel SQL Editor, **in questo ordine e uno per volta**, il contenuto di:
   - `supabase/migrations/006_alimenti_nutrizionista.sql`
   - `supabase/migrations/007_alimenti_visibilita.sql`

   Ogni file deve terminare senza errori. Se uno dà errore, **fermati**, non ritentare a caso e non modificare le migrazioni: riporta il messaggio.
4. Esegui, **uno alla volta**, il contenuto di questi script (lavorano in una transazione annullata con `ROLLBACK`, quindi non lasciano dati):
   - `supabase/tests/rls.sql` → attesi **50 OK**
   - `supabase/tests/alimenti_nutrizionista.sql` → attesi **21 OK**
   - `supabase/tests/alimenti_visibilita.sql` → attesi **23 OK**

   Per ogni script riporta: numero di righe `OK`, numero di righe `KO` e, se ce ne sono, la riga intera (colonne `utente`, `prova`, `atteso`, `ottenuto`).
5. *Security Advisor* (Reports → Advisors): riporta se compaiono avvisi nuovi su `alimenti`, `alimenti_nutrizionista` o la funzione `privato.alimento_in_piano_leggibile`.

## Facoltativo: il giro vero nell'app

Solo se c'è un `.env` con `SUPABASE_URL` e `SUPABASE_ANON_KEY` del progetto (non va mai committato) e Flutter installato: avvia l'app, accedi come `giulia@example.com` (password in `docs/demo-dati.md`) e segui i passaggi 1-8 di `docs/prova-alimenti.md`. Dopo, il passaggio 10 con `elena@example.com`: l'alimento personalizzato di Giulia **non** deve comparire.

## Regole

- Non modificare codice, migrazioni o test: se qualcosa non va, **riferisci** e basta.
- Non eseguire altro sul database oltre a quanto scritto qui. Niente `DROP`, niente cancellazioni, niente seed.
- Nessuna chiave o password nei messaggi, nei commit o nei log.
- Non cambiare lo stato delle PR e non fare commit: la decisione se togliere la bozza è di Mario.

## Come riferire

Una tabella con una riga per passo (1-5): esito, e per i test il conteggio `OK`/`KO`. Se tutto è come atteso, dillo in una riga: "006 e 007 applicate, 50/21/23 OK, nessun avviso nuovo". Mario aggiornerà la PR di conseguenza.
