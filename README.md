# Cenato

App mobile **Flutter** con back-end **Supabase** per il coaching nutrizionale **Nutrizionista ↔ Paziente**.
Il nutrizionista imposta obiettivi e piano; il paziente fa il **check-in di ogni pasto**; il nutrizionista vede lo stato di tutti i pazienti con un **semaforo** di aderenza.

Progetto d'esame del corso *Enterprise Mobile Application Development* (UNISA) di Renato Mancino e Mario Celzo. L'app viene presentata in live demo su smartphone Android.

- Contesto, regole di prodotto e modo di lavorare: [`CLAUDE.md`](CLAUDE.md)
- Requisiti (RAD in Markdown) e indice: [`docs/rad/README.md`](docs/rad/README.md)
- Decisioni con motivazione: [`docs/registro-decisioni.md`](docs/registro-decisioni.md)

## Requisiti per lo sviluppo

- Flutter stable (Dart ≥ 3.14), con `flutter doctor` senza errori sulla parte **Android toolchain**
- Android SDK con **Platform 37** (richiesta da `flutter_local_notifications`) e le licenze accettate (`flutter doctor --android-licenses`). Se manca, Gradle prova a scaricarla da solo al primo build; altrimenti installala da Android Studio → *SDK Manager*.
- Uno smartphone Android con il debug USB attivo oppure un emulatore
- Accesso al progetto Supabase del gruppo (regione UE)

## Primo avvio

### 1. Clonare il repository

```bash
git clone https://github.com/renatomancino/emad.git cenato
cd cenato
```

### 2. Creare il file `.env`

Le chiavi di Supabase **non sono nel repository** (RNF_I_5). Copia il modello e inserisci i valori:

```bash
cp .env.example .env
```

Su Windows (PowerShell): `Copy-Item .env.example .env`

Poi apri `.env` e compila i due valori, che trovi in Supabase Dashboard → *Project Settings* → *API*:

```
SUPABASE_URL=https://<id-progetto>.supabase.co
SUPABASE_ANON_KEY=<chiave pubblica anon>
```

- Usa **solo** la chiave pubblica `anon` (o `publishable`). La chiave `service_role` (o `secret`) **non va mai nell'app**: se la inserisci per errore, l'app si rifiuta di partire e te lo segnala.
- `.env` è nel `.gitignore`: non va mai committato. Controlla con `git status` che non compaia.
- `.env` è registrato come asset in `pubspec.yaml`, quindi **deve esistere prima di compilare**: senza il file `flutter run` e `flutter test` si fermano con `No file or variants found for asset: .env`.
- Se il file esiste ma è vuoto, incompleto o contiene ancora i valori di esempio, l'app parte e mostra una schermata **"Configurazione mancante"** che spiega cosa correggere.
- `.env` finisce dentro l'APK: è normale, perché contiene solo l'URL e la chiave pubblica anon. I dati sono protetti dalle policy RLS, non dalla segretezza della chiave.
- Con Flutter 3.50.0 Android scarta di default i file che iniziano con un punto, quindi anche `.env` ([flutter/flutter#196444](https://github.com/flutter/flutter/issues/196444)). Il blocco `androidResources` in `android/app/build.gradle.kts` lo evita: non rimuoverlo.

### 3. Scaricare le dipendenze e avviare l'app

```bash
flutter pub get
```

```bash
flutter run
```

Con più dispositivi collegati: `flutter devices` e poi `flutter run -d <id>`.
Se tutto è configurato, compare la schermata di prova con il nome **Cenato**.

### Comandi utili

| Comando | A cosa serve |
|---|---|
| `flutter analyze` | Analisi statica con `flutter_lints` (RNF_S_2: nessun errore) |
| `flutter test` | Test automatici in `test/` |
| `flutter build apk --release` | APK installabile per la demo (RNF_PA_1) |

## Struttura delle cartelle

Il codice è organizzato a livelli (RNF_S_1): presentazione, logica (domain), dati.

```
.
├─ CLAUDE.md                  contesto per lo sviluppo (non modificare senza accordo)
├─ docs/
│  ├─ rad/                    RAD in Markdown (01…11, README.md, img/)
│  └─ registro-decisioni.md   decisioni con motivazione
├─ supabase/
│  ├─ migrations/             migrazioni SQL: 001_schema.sql, 002_rls.sql, ...
│  └─ seed.sql                dati di prova, solo fittizi
├─ lib/
│  ├─ main.dart               avvio: legge .env, inizializza Supabase
│  ├─ core/
│  │  ├─ config/              lettura e controllo di .env
│  │  ├─ tema/                tema grafico
│  │  ├─ router/              navigazione (go_router)
│  │  └─ costanti/            costanti modificabili in un solo punto (soglie, limiti)
│  ├─ presentation/           schermate e widget
│  │  ├─ auth/                accesso, registrazione, consenso
│  │  ├─ paziente/            Oggi, Dieta, Andamento, Visite
│  │  ├─ nutrizionista/       Pazienti, Calendario, Profilo e abbonamento
│  │  └─ comuni/              widget condivisi
│  ├─ domain/                 modelli e regole, senza dipendenze da Flutter o Supabase
│  │  ├─ modelli/
│  │  └─ regole/              aderenza, semaforo, limiti del piano
│  └─ data/                   accesso ai dati
│     ├─ supabase/            tabelle, auth, RLS
│     └─ open_food_facts/     ricerca alimenti e barcode
├─ test/                      test automatici
├─ android/                   progetto Android generato da Flutter
├─ .env.example               modello di configurazione (senza chiavi)
└─ pubspec.yaml               dipendenze
```

Le cartelle ancora vuote contengono un file `.gitkeep`, da eliminare quando si aggiunge il primo file.

## Come lavoriamo con Git

### Rami

- `main` contiene sempre una versione che compila e parte.
- **Un ramo per ogni scheda Trello**, creato da `main` aggiornato. Il nome riprende il tipo e l'ID del RAD:

  | Tipo | Esempio |
  |---|---|
  | `feat/` nuova funzione | `feat/uc-gd-1-checkin` |
  | `fix/` correzione | `fix/uc-gi-1-limite-piano` |
  | `docs/` documentazione | `docs/aggiorna-readme` |
  | `chore/` configurazione, dipendenze | `chore/setup-supabase` |

- Si integra in `main` con una **pull request** rivista dall'altro membro del gruppo (RNF_I_3), dopo `flutter analyze` e `flutter test` senza errori.

### Commit

I messaggi sono in italiano e **citano gli ID del RAD** (`UC_…`, `RF_…`, `RNF_…`):

```
UC_GD_1: check-in del pasto
RF_GAD_7: blocca l'invito oltre il limite del piano
RNF_I_5: carica le chiavi di Supabase da .env
```

Anche il titolo e la descrizione della pull request citano gli ID e spiegano come è stato verificato il criterio di "fatto" della scheda Trello.

## Dati e sicurezza

- Dati di prova **solo fittizi** (`supabase/seed.sql`): nessun dato sanitario reale, nessun dato sanitario nei log.
- Row Level Security su ogni tabella; il controllo dei limiti dei piani si fa anche nel database.
- Il progetto Supabase gratuito va in pausa dopo una settimana di inattività: riattivalo e provalo prima della demo (RNF_I_6).
