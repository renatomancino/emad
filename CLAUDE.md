# Cenato – contesto per lo sviluppo

Questo file va nella **radice del repository** (come `CLAUDE.md`): Claude lo legge a ogni sessione. Se un prompt dice "leggi CLAUDE.md", si intende questo file.

## Che cos'è Cenato

App mobile **Flutter** di coaching nutrizionale **Nutrizionista (NUT) ↔ Paziente (PAZ)**. Il paziente non registra alimenti né macro: il nutrizionista imposta gli obiettivi nutrizionali e il piano, il paziente fa il **check-in di ogni pasto** e il nutrizionista vede lo stato di tutti i pazienti con un **semaforo**. Modello **B2B2C**: paga il nutrizionista con abbonamento, il paziente usa l'app gratis su invito.

È il progetto d'esame del corso *Enterprise Mobile Application Development* (UNISA, Prof. Sabato Nocera) di Renato Mancino (RM) e Mario Celzo (MC). L'app viene mostrata in **live demo su smartphone**: tutto ciò che è promesso nei documenti deve funzionare, con dati di prova.

## Stack e ambiente

- **Flutter / Dart** per l'app (Android per la demo; iOS solo se si dispone di un Mac).
- **Supabase** (Postgres + Row Level Security + Auth) in **regione UE**. Il piano gratuito va in pausa dopo una settimana di inattività: riattivarlo prima della demo.
- **Open Food Facts** (API gratuita, licenza ODbL) per la ricerca alimenti, con cache nella tabella `alimenti` (campo `fonte`). Attribuzione obbligatoria nell'app.
- Nessuna chiave nel repository: `SUPABASE_URL` e `SUPABASE_ANON_KEY` stanno in `.env` (ignorato da Git); nel repository solo `.env.example`. La chiave `service_role` non va mai nell'app.
- Dati di prova solo **fittizi** (`supabase/seed.sql`). Nessun dato sanitario reale, nessun dato sanitario nei log.

## Struttura consigliata del repository

```
cenato/
├─ CLAUDE.md                      questo file
├─ docs/
│  ├─ rad/                        RAD in Markdown (01…11, README.md, img/)
│  └─ registro-decisioni.md       decisioni con motivazione
├─ supabase/
│  ├─ migrations/                 001_schema.sql, 002_rls.sql, ...
│  └─ seed.sql
└─ lib/
   ├─ presentation/               schermate e widget (una cartella per sezione)
   ├─ domain/                     modelli e regole (aderenza, semaforo, limiti piano)
   └─ data/                       accesso a Supabase e a Open Food Facts
```

## Dove trovare i requisiti

Tutto il RAD è in `docs/rad/` (leggi `docs/rad/README.md` per l'indice). Ordine di lettura per una funzione: **requisiti** (`04`, `05`) → **scenario** (`06`) → **caso d'uso** (`07`, il file più importante) → **oggetti e class diagram** (`08`) → **sequence e statechart** (`09`) → **mock-up e navigazione** (`10`). Le decisioni con motivazione sono in `docs/registro-decisioni.md`.

Nei commit e nelle descrizioni delle pull request cita sempre gli identificatori (`UC_GD_1`, `RF_GD_2`...).

## Regole di prodotto da non violare

1. **Check-in a quattro stati** per ogni pasto: Seguito (1 punto), Alternativa (1), Fuori piano (0,5), Saltato (0). Il **pasto extra non conta** nel punteggio; un pasto non registrato vale 0.
2. **Indice di aderenza** giornaliero = media dei punti dei pasti previsti. **Semaforo** sulla media degli ultimi 3 giorni: verde ≥ 0,8, giallo tra 0,4 e 0,8, rosso < 0,4 (**soglie da validare: costanti modificabili in un solo punto**). Il semaforo è un indicatore di attenzione per il triage, non una misura clinica.
3. **Stati del paziente**: Invitato, Attivo, Archiviato. **I pazienti non si eliminano, si archiviano.** Il paziente può scollegarsi dal nutrizionista.
4. **Piani** (prezzi IVA esclusa): **Free** 1 paziente a vita (conta chi ha accettato un invito, anche se poi archiviato); **Start** fino a 5 pazienti attivi, 12 €/mese o 120 €/anno; **Pro** illimitati, 25 €/mese o 250 €/anno. Tutte le funzioni in tutti i piani. **Pagamento simulato** nell'MVP (nessun addebito), ma limiti e cambio piano sono reali.
5. **Limite del piano**: se raggiunto, l'invito è **bloccato con un errore che spiega il motivo** e propone cambio piano o archiviazione (RF_GAD_7). Il controllo va fatto anche nel database, non solo nell'interfaccia.
6. **Sicurezza**: RLS su ogni tabella. Il nutrizionista vede solo i propri pazienti; il paziente solo i propri dati. Consenso esplicito al trattamento dei dati sanitari alla registrazione (GDPR art. 9) e cancellazione dell'account su richiesta.
7. **Agenda completa** (priorità Alta): disponibilità del nutrizionista, finestra di prenotazione per paziente, prenotazione di uno slot libero con conferma immediata, **una sola visita futura**, annullamento fino a 24 ore prima, visite future annullate se il paziente è archiviato. Questi valori sono **[DA CONFERMARE]**: tienili come costanti. La doppia prenotazione dello stesso slot si impedisce **nel database**.
8. **App paziente in quattro sezioni**: Oggi (check-in), Dieta (piano e obiettivi), Andamento (peso, aderenza, commenti, storico), Visite. Il nutrizionista ha: Pazienti (dashboard), Calendario, Profilo e abbonamento.
9. **Nessuna pubblicità né uso dei dati dei pazienti.** Nel piano Free c'è solo uno **spazio sponsor statico** nella dashboard del nutrizionista, senza tracciamento.

## Ambito dell'MVP

L'MVP comprende **tutti i requisiti di priorità A e M** del RAD (`docs/rad/04-requisiti-funzionali.md`). I requisiti **B non si implementano**. Se il tempo non basta, si rinviano per primi: **scansione barcode** (resta la ricerca testuale), poi **spazio sponsor** e **quantità rapide**; in quel caso si avvisa chi cura i documenti perché non si prometta ciò che non si mostra.

## Come lavorare

- Una funzione alla volta, a **fette verticali**: schermata + logica + tabelle e policy RLS + prova con i dati di prova.
- Prima di scrivere codice, leggi i file del RAD citati nel prompt e **riassumi in poche righe** cosa farai; se un requisito è ambiguo o contraddittorio, **chiedi** invece di inventare.
- Ogni funzione ha un **criterio di "fatto"** nella scheda Trello: verificalo e descrivi come l'hai provato.
- Gestisci sempre: caricamento, stato vuoto, errore di rete con "Riprova" senza perdere ciò che l'utente ha inserito.
- Testi dell'interfaccia in **italiano**, chiari e brevi; nomi di codice in inglese o italiano coerenti con il glossario (`docs/rad/11-glossario.md`).
- Non cambiare i requisiti per comodità implementativa: se serve una deroga, spiegala e annotala.
