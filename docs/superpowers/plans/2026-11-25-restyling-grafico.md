# Restyling grafico di Cenato – piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dare a tutte le schermate esistenti un aspetto professionale in stile app salute (titolo grande, card bianche con ombra morbida, icone tonali, controlli a pillola), senza cambiare logica, testi o requisiti.

**Architecture:** i colori passano da un `ThemeExtension` (`CenatoColori`, per ora solo palette chiara) e non più da costanti fisse; `temaCenato()` applica font, forme e colori; pochi componenti comuni in `lib/presentation/comuni/` sostituiscono lo stile ripetuto nelle pagine. Le pagine vengono migrate a tappe, un commit per tappa.

**Tech Stack:** Flutter 3.50 / Dart 3.14, Material 3 (`material_ui`), `go_router`, font incorporati (Plus Jakarta Sans, Inter).

**Spec:** `docs/superpowers/specs/2026-11-25-restyling-grafico-design.md`

## Global Constraints

- Nessuna modifica a logica, repository, database, RLS, **testi dell'interfaccia** (stringhe identiche) o requisiti.
- Contrasto almeno AA: 4,5:1 per il testo normale (RNF_U_3). Aree di tocco almeno 48 dp (`areaToccoMinima`).
- Il testo segue la dimensione scelta nel telefono: nessuna scala fissata nel codice.
- Colori del semaforo invariati: `semaforoVerde 0xFF2E7D4F`, `semaforoGiallo 0xFFB7791F`, `semaforoRosso 0xFFC0392B`.
- Font solo incorporati in `assets/fonts/` (licenza OFL accanto ai file); nessun download a runtime, nessun pacchetto `google_fonts`.
- I test esistenti cercano testi esatti (`find.text('Marco')`, `'Archiviati'`, `'Riprova'`, `'Invita'`, ...) e tipi (`FilledButton`, `OutlinedButton`, `NavigationBar`, `TextField`, `CircularProgressIndicator`): vanno mantenuti.
- Nessuna chiave nel repository; `.env` resta ignorato da Git.
- Commit in italiano con prefisso `Restyling:`, citando `RNF_U_3`, e chiusi con le righe di attribuzione richieste dalla sessione.
- Comandi: `export PATH=/root/sdk/flutter/bin:$PATH` prima di ogni `flutter`.

## Review Focus

1. Testo al 200% (impostazioni del telefono): intestazione, riga elenco, etichetta di stato e schermata di accesso non devono andare in overflow.
2. Nome paziente molto lungo (60+ caratteri): la riga elenco tronca con puntini e non va in overflow.
3. Telefono stretto (320 dp di larghezza): accesso e Pazienti senza overflow.
4. Ogni coppia testo/sfondo della palette rispetta il contrasto AA (test automatico sui valori).
5. Gli stati caricamento, vuoto ed errore mantengono pulsante "Riprova"/azione e i testi originali.

---

### Task 1: Font, colori `CenatoColori` e tema

**Files:**
- Create: `assets/fonts/` (file font + `OFL-PlusJakartaSans.txt`, `OFL-Inter.txt`)
- Create: `test/tema_test.dart`
- Modify: `pubspec.yaml` (sezione `fonts:`), `lib/core/tema/tema.dart`

**Interfaces:**
- Produces, in `lib/core/tema/tema.dart`:
  - `class CenatoColori extends ThemeExtension<CenatoColori>` con campi `Color` `sfondo`, `superficie`, `bordo`, `testo`, `testoSecondario`, `primario`, `sulPrimario`, `primarioTonale`, `errore`, `avviso`, `avvisoTonale`, `semaforoVerde`, `semaforoGiallo`, `semaforoRosso`; `static const chiaro`; `copyWith` e `lerp`.
  - `extension CenatoColoriContesto on BuildContext { CenatoColori get colori; }`
  - `const String fontTitoli = 'PlusJakartaSans'`, `const String fontTesto = 'Inter'`.
  - `ThemeData temaCenato()` (stessa firma) con l'estensione registrata.
  - `ColoriCenato` e `areaToccoMinima` restano finché le tappe 3-5 non migrano le pagine; `ColoriCenato` legge i valori da `CenatoColori.chiaro`.

- [ ] **Step 1: Preparare l'ambiente.** Flutter è in `/root/sdk/flutter`. Eseguire `cp .env.example .env` (serve perché `.env` è un asset), `flutter pub get`, `flutter analyze`, `flutter test`. Annotare l'esito di base: i test esistenti devono essere verdi; se qualcosa fallisce già ora, segnalarlo prima di proseguire.
- [ ] **Step 2: Scrivere il test fallito** in `test/tema_test.dart`:
  - `'i titoli usano Plus Jakarta Sans e il testo Inter'`: `temaCenato().textTheme.titleLarge!.fontFamily == fontTitoli`, `bodyMedium!.fontFamily == fontTesto`.
  - `'CenatoColori è registrato nel tema'`: `temaCenato().extension<CenatoColori>()` non nullo.
  - `'palette: contrasto AA'`: calcolare il rapporto di contrasto WCAG con `computeLuminance()`; devono essere ≥ 4,5 le coppie `testo/superficie`, `testo/sfondo`, `testoSecondario/superficie`, `testoSecondario/sfondo`, `sulPrimario/primario`, `primario/primarioTonale`, `errore/superficie`, `semaforoGiallo/avvisoTonale`.
  - `'le card non hanno bordo e hanno raggio 20'`: leggere `temaCenato().cardTheme`.
- [ ] **Step 3: Eseguire** `flutter test test/tema_test.dart` — atteso: FAIL (simboli non definiti).
- [ ] **Step 4: Procurare i font** (SIL OFL) da Google Fonts: Plus Jakarta Sans pesi 600, 700, 800; Inter pesi 400, 500, 600, 700. Preferire file TTF statici; se disponibile solo il file variabile, dichiararlo una volta con le varianti `weight` e verificarne il rendering allo Step 8. Salvarli in `assets/fonts/` con le licenze, e dichiarare le due famiglie in `pubspec.yaml` (`family: PlusJakartaSans`, `family: Inter`). Uscita da Google Fonts: `fonts.googleapis.com`/`fonts.gstatic.com` sono raggiungibili dal container.
- [ ] **Step 5: Implementare** `CenatoColori`, l'estensione sul contesto e `temaCenato()`. Valori palette chiara: `sfondo 0xFFF3F6F4`, `superficie 0xFFFFFFFF`, `bordo 0xFFE1E8E3`, `testo 0xFF16211C`, `testoSecondario 0xFF55645C`, `primario 0xFF2F6B4F`, `sulPrimario 0xFFFFFFFF`, `primarioTonale 0xFFE2F1E8`, `errore 0xFFB3261E`, `avviso 0xFF8A5A00`, `avvisoTonale 0xFFFFF3D6`, semafori invariati. Se un contrasto del test non basta, scurire il colore del testo (non cambiare i semafori). Tema: `textTheme` con `fontTesto` per body/label e `fontTitoli` per display/headline/title; `AppBar` su `sfondo`, testo scuro, `scrolledUnderElevation: 0`, senza tinta; `CardThemeData` raggio 20, senza bordo, elevazione 2 con ombra tenue e `surfaceTintColor` trasparente; campi di testo, bottoni e `SegmentedButton`/chip a pillola con raggio 14 / `StadiumBorder`; `NavigationBar` chiara con indicatore `primarioTonale` e altezza ≥ 72; `FloatingActionButton` e `SnackBar` (floating) coerenti. Dimensioni minime dei bottoni invariate (`areaToccoMinima`).
- [ ] **Step 6: Eseguire** `flutter test` completo e `flutter analyze` — atteso: tutto verde, nessun avviso.
- [ ] **Step 7: Commit e push**
  ```bash
  git add assets pubspec.yaml lib/core/tema test/tema_test.dart
  git commit -m "Restyling: font incorporati, colori CenatoColori e tema (RNF_U_3)"
  git push -u origin claude/practical-cannon-b9qm8o
  ```
- [ ] **Step 8: Verifica visiva.** Costruire una prima schermata di prova con `flutter build web --dart-define=CENATO_RUOLO_FINTO=nutrizionista` (usare l'opzione per non dipendere dal CDN di CanvasKit se serve), servirla con `python3 -m http.server` da una cartella fuori dal repository e scattare uno screenshot con Playwright (viewport 390×844, `deviceScaleFactor: 2`) in una cartella dello scratchpad. Controllare che font e pesi si vedano distinti. Questa procedura è riusata dalle tappe successive.

### Task 2: Componenti comuni e stati

**Files:**
- Create: `lib/presentation/comuni/componenti.dart`, `test/componenti_test.dart`
- Modify: `lib/presentation/comuni/segnaposto_page.dart` (`IntestazioneSezione`, `EtichettaStato`), `lib/presentation/comuni/stati_view.dart`, `lib/presentation/comuni/controlli.dart` (solo `MessaggioErrore`)

**Interfaces:**
- Consumes: `CenatoColori`, `context.colori` (Task 1).
- Produces, in `componenti.dart`:
  - `class IconaTonale extends StatelessWidget` — `IconaTonale({super.key, required IconData icona, Color? colore, Color? sfondo, double dimensione = 44})`: quadrato arrotondato (raggio = dimensione/3.5) con icona al centro; i colori di default sono `primario` su `primarioTonale`.
  - `class SchedaSezione extends StatelessWidget` — `SchedaSezione({super.key, String? titolo, required Widget child, EdgeInsetsGeometry padding = const EdgeInsets.all(16), VoidCallback? onTap})`: `Card` con titolo opzionale (`titleMedium`) sopra il contenuto.
  - `class RigaElenco extends StatelessWidget` — `RigaElenco({super.key, required String titolo, String? sottotitolo, Widget? leading, Widget? trailing, VoidCallback? onTap})`: card con altezza minima 64 dp; titolo e sottotitolo con `maxLines` e puntini; il testo del titolo è un unico `Text(titolo)`.
  - `enum TonoStato { positivo, attenzione, errore, neutro }`
- Produces, in `segnaposto_page.dart`: `EtichettaStato({super.key, required String testo, TonoStato tono = TonoStato.positivo})` (compatibile con gli usi attuali); `IntestazioneSezione` con la stessa firma di oggi ma resa come titolo grande su sfondo chiaro (`preferredSize` altezza 96, azioni a destra).

- [ ] **Step 1: Scrivere i test falliti** in `test/componenti_test.dart` (helper `_inApp` come in `comuni_test.dart`):
  - `'IntestazioneSezione mostra titolo e sottotitolo e non ha fascia colorata'`: `AppBar.backgroundColor` uguale a `sfondo`.
  - `'RigaElenco ha altezza minima 64 e richiama onTap'`.
  - `'RigaElenco tronca un nome di 80 caratteri senza overflow'` (larghezza 320, `tester.takeException()` nullo).
  - `'a testo 200% intestazione, RigaElenco ed EtichettaStato non vanno in overflow'` con `MediaQuery(textScaler: TextScaler.linear(2.0))`.
  - `'EtichettaStato usa colori diversi per tono'` (positivo ≠ errore) e mostra sempre il testo.
  - `'IconaTonale rispetta la dimensione richiesta'`.
  - `'StatoVuotoView ed ErroreView mantengono testi e azioni'` (i test esistenti in `comuni_test.dart` devono restare verdi).
- [ ] **Step 2: Eseguire** `flutter test test/componenti_test.dart` — atteso: FAIL.
- [ ] **Step 3: Implementare** i componenti con i colori da `context.colori`. `StatoVuotoView`: icona dentro un cerchio tonale da 72 dp, titolo `titleLarge`, messaggio `bodyLarge` in `testoSecondario`; `ErroreView`: stesso schema con tono `errore`; `CaricamentoView`: invariato nel contenuto. `MessaggioErrore`: colori da `context.colori.errore`, raggio 14. Nessuna stringa cambia.
- [ ] **Step 4: Eseguire** `flutter test` completo e `flutter analyze` — atteso: verde.
- [ ] **Step 5: Commit e push** (`Restyling: componenti comuni e stati (RNF_U_3)`).

### Task 3: Schermate di accesso

**Files:**
- Modify: `lib/presentation/auth/accesso_page.dart`, `registrazione_page.dart`, `recupero_password_page.dart`, `nuova_password_page.dart`
- Test: aggiungere a `test/auth_test.dart`

**Interfaces:**
- Consumes: `IconaTonale`, `SchedaSezione`, `context.colori`.

- [ ] **Step 1: Scrivere i test falliti** in `test/auth_test.dart`: `'accesso a 320 dp e testo 200% senza overflow'`; `'registrazione a 320 dp senza overflow'` (usare gli helper di avvio già presenti nel file).
- [ ] **Step 2: Eseguire** i due test — atteso: FAIL solo se l'attuale schermata va in overflow; altrimenti restano come rete di sicurezza e si procede.
- [ ] **Step 3: Migrare** le pagine: sostituire ogni `ColoriCenato.*` con `context.colori.*`; nell'accesso, al posto di `Icons.restaurant` nudo, un marchio con `IconaTonale` grande (dimensione 72) sopra il nome app; campi e pulsanti dal tema; nella registrazione, le `Card` con consenso e informativa diventano `SchedaSezione`. Gli `AppBar` semplici ereditano il nuovo tema. Non toccare logica, validazioni, chiavi dei widget (`Key`) né testi.
- [ ] **Step 4: Eseguire** `flutter test` e `flutter analyze` — atteso: verde.
- [ ] **Step 5: Verifica visiva** con la procedura del Task 1: accesso, registrazione. Salvare gli screenshot nello scratchpad.
- [ ] **Step 6: Commit e push** (`Restyling: schermate di accesso (RNF_U_3)`).

### Task 4: Area nutrizionista

**Files:**
- Modify: `lib/presentation/nutrizionista/pazienti_page.dart`, `invito_page.dart`, `calendario_page.dart`, `disponibilita_page.dart`, `abbonamento_view.dart`, `sponsor_card.dart`, `nutrizionista_shell.dart`
- Test: `test/pazienti_test.dart` (aggiunte)

**Interfaces:**
- Consumes: `RigaElenco`, `EtichettaStato`, `IconaTonale`, `SchedaSezione`, `IntestazioneSezione`.

- [ ] **Step 1: Scrivere i test falliti**: in `pazienti_test.dart` `'la riga paziente tronca un nome lunghissimo senza overflow'` (paziente con nome di 60+ caratteri, larghezza 320) e `'Pazienti a testo 200% senza overflow'`.
- [ ] **Step 2: Eseguire** — atteso: FAIL finché le righe non usano `RigaElenco`.
- [ ] **Step 3: Migrare** `pazienti_page.dart`: `_RigaPaziente` e la riga degli inviti usano `RigaElenco` (il nome resta un unico `Text(paziente.nome)`), avatar iniziale in cerchio tonale (grigio per archiviato), filtro `SegmentedButton` a pillola con le stesse etichette, campo ricerca con icona, FAB esteso come ora. `abbonamento_view.dart`: schede dei piani con `SchedaSezione`, etichetta "Attuale" come `EtichettaStato`. `sponsor_card.dart`: fondo `avvisoTonale`, icona in `IconaTonale` con tono `avviso`; resta statica, senza immagini né rete. `invito_page.dart`, `disponibilita_page.dart`, `calendario_page.dart`: `Card` → `SchedaSezione` dove ha senso, colori dal contesto. `nutrizionista_shell.dart`: tema della barra già in `temaCenato()`; verificare che le icone selezionate siano quelle piene.
- [ ] **Step 4: Eseguire** `flutter test` completo (inclusi `navigazione_test`, `pazienti_test`, `profilo_test`) e `flutter analyze` — atteso: verde.
- [ ] **Step 5: Verifica visiva**: elenco pazienti (piano Free con sponsor, vuoto, con inviti), invito, abbonamento. Screenshot nello scratchpad.
- [ ] **Step 6: Commit e push** (`Restyling: area nutrizionista (RNF_U_3)`).

### Task 5: Area paziente, profilo e pagine comuni

**Files:**
- Modify: `lib/presentation/paziente/oggi_page.dart`, `dieta_page.dart`, `andamento_page.dart`, `visite_page.dart`, `collegamento_page.dart`, `paziente_shell.dart`; `lib/presentation/comuni/profilo_page.dart`, `elimina_account_page.dart`, `errore_configurazione_page.dart`, `errore_limite_dialog.dart`

**Interfaces:**
- Consumes: componenti del Task 2.

- [ ] **Step 1: Scrivere i test falliti** in `test/profilo_test.dart`: `'profilo a testo 200% senza overflow'`; `'collegamento a 320 dp senza overflow'` (con gli helper di avvio presenti).
- [ ] **Step 2: Eseguire** — atteso: FAIL solo se oggi va in overflow; altrimenti restano come rete di sicurezza.
- [ ] **Step 3: Migrare** le pagine: `ListTile` dentro `Card` del profilo → `RigaElenco` con `IconaTonale`; pulsante "Elimina account" e dialoghi con i colori d'errore dal contesto (nessun `Colors.white` fisso, usare `sulPrimario`/`colorScheme.onError`); `errore_limite_dialog.dart`: dialogo con angoli 24 e bottoni dal tema, stessi testi; schermate segnaposto delle sezioni paziente (Dieta, Andamento, Visite) e stato vuoto di Oggi con l'icona tonale. Barra di navigazione del paziente: stesso stile del nutrizionista.
- [ ] **Step 4: Eseguire** `flutter test` e `flutter analyze` — atteso: verde.
- [ ] **Step 5: Verifica visiva** con `CENATO_RUOLO_FINTO=paziente`: Oggi, Dieta, Andamento, Visite, Profilo, Collegamento. Screenshot nello scratchpad.
- [ ] **Step 6: Commit e push** (`Restyling: area paziente e pagine comuni (RNF_U_3)`).

### Task 6: Pulizia, documentazione e verifica finale

**Files:**
- Modify: `lib/core/tema/tema.dart` (rimuovere `ColoriCenato`), `docs/registro-decisioni.md`
- Test: `test/tema_test.dart` (aggiunta)

- [ ] **Step 1: Verificare** che nessun file in `lib/` oltre `tema.dart` usi più `ColoriCenato` (`grep -rn "ColoriCenato" lib` mostra solo `tema.dart`). Se restano usi, migrarli.
- [ ] **Step 2: Rimuovere** la classe `ColoriCenato` da `tema.dart` e sistemare gli import; `areaToccoMinima` resta.
- [ ] **Step 3: Documentare** in `docs/registro-decisioni.md`, seguendo il formato delle voci esistenti: restyling grafico, motivazione, deroga rispetto ai mock-up del RAD (fascia verde sostituita da titolo grande, immagini in `docs/rad/img/` non aggiornate), scelta dei font e licenza OFL, e nota che `CenatoColori` prepara il tema scuro.
- [ ] **Step 4: Eseguire** `flutter analyze` e `flutter test` — atteso: verde. Rifare gli screenshot delle schermate principali e controllarli.
- [ ] **Step 5: Commit e push** (`Restyling: pulizia, registro decisioni e verifica finale (RNF_U_3)`). Nella risposta finale all'utente: cosa è stato provato (analisi, test, screenshot web) e cosa no (prova su telefono vero).
