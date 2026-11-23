# Test delle policy RLS e delle RPC

Esito dei test di `supabase/tests/rls.sql` sulle migrazioni `000_profili.sql`, `001_schema.sql` e `002_rls.sql`.
Requisiti: RNF_L_1, RNF_L_2, RNF_A_6, RNF_S_3; regole 3, 5, 6 e 7 di `CLAUDE.md`.

- **Data**: 23/11/2026, progetto Supabase del gruppo (regione `eu-west-1`), Postgres 17
- **Esito**: **50 controlli su 50 OK**. Nella prima esecuzione (49 controlli) 48 erano OK; il n. 30 è stato corretto (vedi sotto) e riverificato insieme al nuovo n. 31 con una prova mirata.
- **Come si ripete**: SQL Editor → incolla `supabase/tests/rls.sql` → *Run*. Lo script lavora in una transazione annullata (`ROLLBACK`): crea utenti e dati di prova, esegue le query **come** ciascun utente (ruolo `authenticated` + JWT con il suo id, come fa l'app) e non lascia nulla nel database. Ogni riga del risultato deve avere `esito = OK`.

Utenti di prova creati dallo script: **NUT A** (piano Pro, pazienti A1 e A2), **NUT B** (piano Free, paziente B1), **PAZ A1**, **PAZ A2**, **PAZ B1**, un **paziente nuovo** senza nutrizionista e l'utente **anonimo** (senza login).

## Risultati

| # | Utente | Prova | Atteso | Ottenuto |
|---|---|---|---|---|
| 1 | anonimo | Non legge i pazienti | negato | permesso negato |
| 2 | anonimo | Non legge i check-in | negato | permesso negato |
| 3 | anonimo | Non legge i profili | negato | permesso negato |
| 4 | anonimo | Non legge la cache alimenti | negato | permesso negato |
| 5 | NUT A | Vede solo i propri pazienti | 2 | 2 |
| 6 | NUT A | Non legge i check-in di un paziente non suo | 0 | 0 |
| 7 | NUT A | Legge i check-in del proprio paziente | 1 | 1 |
| 8 | NUT A | Non legge il peso di un paziente non suo | 0 | 0 |
| 9 | NUT A | Non legge il profilo di un paziente non suo | 0 | 0 |
| 10 | NUT A | Legge il nome del proprio paziente | 1 | 1 |
| 11 | NUT A | Non legge il piano di un paziente non suo | 0 | 0 |
| 12 | NUT A | Non scrive obiettivi per un paziente non suo | negato | 42501 (RLS) |
| 13 | NUT A | Scrive obiettivi per il proprio paziente | ok | ok |
| 14 | NUT A | Non cancella dati clinici (check-in) | negato | 42501 (permesso) |
| 15 | NUT A | Non modifica i check-in del paziente | 0 righe | 0 righe |
| 16 | NUT A | Non cambia lo stato del paziente senza RPC | negato | 42501 (colonna) |
| 17 | NUT A | Non cambia il proprio piano di abbonamento senza RPC | negato | 42501 (colonna) |
| 18 | NUT B | Non legge i commenti di un altro nutrizionista | 0 | 0 |
| 19 | NUT B | Free con 1 paziente: invito bloccato (RF_GAD_7) | CN001 | CN001 "Hai raggiunto il limite del piano Free (1 paziente)." |
| 20 | NUT A | Pro: invito creato | ok | ok |
| 21 | PAZ A1 | Vede solo i propri check-in | 1 | 1 |
| 22 | PAZ A1 | Vede solo il proprio peso | 1 | 1 |
| 23 | PAZ A1 | Non vede gli altri pazienti | 1 (sé stesso) | 1 |
| 24 | PAZ A1 | Non legge il profilo di un altro paziente | 0 | 0 |
| 25 | PAZ A1 | Legge il nome del proprio nutrizionista | 1 | 1 |
| 26 | PAZ A1 | Non legge un altro nutrizionista | 0 | 0 |
| 27 | PAZ A1 | Legge solo il proprio piano | 1 | 1 |
| 28 | PAZ A1 | Legge i commenti ai propri check-in | 1 | 1 |
| 29 | PAZ A1 | Non legge gli inviti | 0 | 0 |
| 30 | PAZ A1 | Non scrive check-in per un altro paziente | negato | 23514 (pasto non suo) |
| 31 | NUT B | Il check-in di B1 è rimasto uno solo | 1 | 1 |
| 32 | PAZ A1 | Non registra check-in di 3 giorni fa (RF_GD_3) | negato | 42501 (RLS) |
| 33 | PAZ A1 | Registra il check-in di ieri | ok | ok |
| 34 | PAZ A1 | Non cambia il proprio ruolo | negato | 42501 (colonna) |
| 35 | PAZ A1 | Non cambia il proprio nutrizionista | negato | 42501 (colonna) |
| 36 | PAZ A1 | Non inserisce visite senza RPC | negato | 42501 (RLS) |
| 37 | PAZ A1 | Prenotazione fuori finestra rifiutata | CN005 | CN005 |
| 38 | PAZ A1 | Orario non allineato agli slot rifiutato | CN005 | CN005 |
| 39 | PAZ A1 | Prenota uno slot libero (RF_GV_8) | ok | ok |
| 40 | PAZ A1 | Seconda visita futura rifiutata | CN004 | CN004 |
| 41 | PAZ A2 | Slot già preso da A1 rifiutato (RNF_A_6) | CN003 | CN003 |
| 42 | PAZ A2 | Non vede la visita di A1 | 0 | 0 |
| 43 | Paz. nuovo | Codice di invito inesistente rifiutato | CN002 | CN002 |
| 44 | Paz. nuovo | Accetta l'invito di NUT A | ok | ok |
| 45 | NUT A | Vede il nuovo paziente Attivo | 3 | 3 |
| 46 | PAZ A1 | Si scollega (RF_GI_7) | ok | ok |
| 47 | PAZ A1 | Dopo lo scollegamento non scrive check-in | negato | 42501 (RLS) |
| 48 | NUT A | Conserva lo storico del paziente archiviato | 2 | 2 |
| 49 | NUT A | Visita futura annullata allo scollegamento (SCD_2) | 1 | 1 |
| 50 | NUT A | Non riattiva chi si è scollegato da solo | CN009 | CN009 |

Il controllo n. 30 nella prima esecuzione attendeva solo `42501`. Il rifiuto è arrivato prima, dal trigger di verifica dei check-in (`23514`: il paziente non vede il pasto altrui). La scrittura è comunque negata: il test ora accetta entrambi i codici e il n. 31 verifica che la riga non sia stata scritta.

I vincoli dello schema hanno un test a parte, `supabase/tests/schema_vincoli.sql`: 14 controlli su 14 OK.

Piani, limiti e inviti (migrazione `003_abbonamento.sql`) sono provati con gli account demo da `supabase/tests/abbonamento.sql`: **16 controlli su 16 OK** (23/11/2026), più la scadenza verificata a parte: un codice scaduto è rifiutato (CN002) e l'invito passa a *scaduto* (SCD_1); il caso è stato poi aggiunto in fondo al file. Tra questi: Free bloccato al 2° invito con il messaggio di RF_GAD_7, passaggio a Start con pagamento simulato e invito riuscito, ritorno a Free bloccato, revoca dell'invito, riattivazione e archiviazione con i limiti di Start, codice revocato non più valido. La stessa regola è provata in Dart da `test/limiti_piano_test.dart`.

## Policy per tabella

`anon` non ha alcun privilegio su nessuna tabella. Per `authenticated` le colonne scrivibili sono limitate con `GRANT` per colonna; la RLS decide quali righe.

| Tabella | Nutrizionista | Paziente |
|---|---|---|
| `profili` | legge il proprio e quelli dei propri pazienti; modifica solo `nome` | legge il proprio e quello del proprio nutrizionista; modifica solo `nome` |
| `nutrizionisti` | legge e modifica (titolo, durata visita) il proprio | legge il proprio nutrizionista |
| `abbonamenti` | legge i propri | — |
| `pazienti` | legge i propri (tutti gli stati); modifica solo i dati anagrafici | legge i propri collegamenti; modifica i propri dati se Attivo |
| `inviti` | legge i propri | — (usa `anteprima_invito` e `accetta_invito`) |
| `obiettivi` | legge e inserisce per i propri pazienti | legge i propri |
| `alimenti` | legge tutto; inserisce; aggiorna cache OFF e i propri personalizzati | legge tutto (nomi nel piano) |
| `piani` | legge, crea e aggiorna per i propri pazienti; cancella solo bozze | legge le versioni assegnate (non le bozze) |
| `giorni`, `pasti`, `voci_pasto`, `alternative` | legge; scrive solo se il piano è in **bozza** (RF_GP_7) | legge quelli dei piani assegnati |
| `modelli_piano` | tutto sui propri | — |
| `check_in` | **solo lettura** dei propri pazienti | legge i propri; inserisce e corregge oggi o ieri (RF_GD_3) se Attivo |
| `pasti_extra` | solo lettura | legge e inserisce i propri se Attivo |
| `commenti` | legge, scrive e modifica i propri sui check-in dei propri pazienti | legge quelli sui propri check-in |
| `misure_peso` | legge; inserisce per i propri pazienti (RF_GM_1) | legge e inserisce i propri se Attivo |
| `stati_aderenza` | solo lettura | solo lettura |
| `notifiche` | legge le proprie e le segna come lette | idem |
| `preferenze_notifiche` | proprie | proprie |
| `disponibilita` | tutto sulle proprie | legge quelle del proprio nutrizionista |
| `finestre_prenotazione` | legge, crea e aggiorna per i propri pazienti | legge la propria |
| `visite` | legge, fissa (solo pazienti attivi), sposta e annulla le proprie | legge le proprie; prenota e annulla **solo** con le RPC |

## Funzioni RPC

Tutte `security definer` con controllo del chiamante; errori con codice e messaggio in italiano.

| Funzione | Chi | Cosa fa | Errori |
|---|---|---|---|
| `crea_invito(nome)` | NUT | Verifica il limite del piano (Free: pazienti mai collegati + inviti in attesa; Start: attivi + inviti) e crea codice e paziente Invitato | CN001, CN007 |
| `revoca_invito(id)` | NUT | Invito Creato → Revocato (RF_GI_8) | CN007 |
| `anteprima_invito(codice)` | PAZ | Nome del nutrizionista prima di confermare (UC_GI_2, passo 3) | CN002 |
| `accetta_invito(codice)` | PAZ | Verifica codice e limite, collega il paziente (Attivo) | CN001, CN002, CN007, CN008 |
| `archivia_paziente(id)` | NUT | Attivo → Archiviato, annulla le visite future (UC_GI_4) | CN007 |
| `riattiva_paziente(id)` | NUT | Archiviato → Attivo se il piano lo consente; non se il paziente si è scollegato da solo | CN001, CN007, CN008, CN009 |
| `scollega_paziente()` | PAZ | Il paziente interrompe il collegamento (UC_GI_5); nel Free resta contato | CN007 |
| `prenota_visita(inizio)` | PAZ | Verifica finestra, disponibilità, allineamento allo slot, una sola visita futura e slot libero (RNF_A_6) | CN003, CN004, CN005, CN007 |
| `annulla_visita(id)` | PAZ | Annulla fino a 24 ore prima (RF_GV_9, costante `ore_minime_annullamento()`) | CN006, CN007 |

Le funzioni di supporto alle policy stanno nello schema `privato`, non esposto dall'API. Il **Security Advisor** di Supabase segnala solo le 9 RPC qui sopra come "eseguibili da utenti autenticati": è il comportamento voluto.

## Da completare in fase 6

La scheda "Test di sicurezza RLS (accessi consentiti e negati)" estenderà questi casi a tutte le tabelle e a tutte le combinazioni, compresi i pazienti archiviati con storico e la cancellazione dell'account (RF_GA_7).
