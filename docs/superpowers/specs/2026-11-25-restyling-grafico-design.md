# Restyling grafico di Cenato – design

Data: 2026-11-25 · Branch: `claude/practical-cannon-b9qm8o` (partito da `main` @ `7eb9627`)

## Intento e perché

Portare l'aspetto dell'app a un'estetica **professionale e attuale**, vicina a Mio Dottore e alle app salute di Apple (Salute, Fitness): sfondo chiaro, titolo grande, card bianche con ombra morbida, icone in tondini tonali, controlli a pillola. Serve a far fare bella figura ai mock-up e alla **live demo su smartphone**.

## Obiettivi

- Nuovo linguaggio visivo applicato a **tutte le schermate esistenti** (auth, nutrizionista, paziente, comuni).
- Font più curati, **incorporati nell'app** (la demo non deve dipendere dalla rete).
- Colori letti da un set che segue il tema, non da costanti fisse, così in futuro si aggiunge il tema scuro.
- Componenti riusabili al posto di stile ripetuto nelle pagine.

## Non-obiettivi

- Nessuna modifica a logica, repository, database, RLS, testi dell'interfaccia o requisiti.
- Nessuna nuova funzione. Le schermate delle fasi successive (check-in, dieta, andamento) nasceranno già col nuovo stile, ma non le implemento qui.
- Modalità scura e animazioni elaborate non sono in questo giro (vedi "Strada verso C").

## Anti-obiettivi (sarebbe un fallimento anche se "bello")

- Contrasto sotto AA o aree di tocco sotto 48 dp (RNF_U_3).
- Testo che non segue la dimensione scelta nelle impostazioni del telefono.
- Cambiare i colori del semaforo (verde/giallo/rosso, soglie e significato).
- Test esistenti che si rompono, o un'app che non compila.

## Vincoli

- Flutter/Dart, Material 3, pacchetti già in uso. Nessuna dipendenza che scarichi font a runtime.
- I font sono OFL: includere le licenze accanto ai file.
- Il look si distacca dai mock-up del RAD (fascia verde piena): **deroga da annotare** in `docs/registro-decisioni.md`. Le immagini in `docs/rad/img/` non si rigenerano qui.
- 21st.dev è React/Tailwind: serve solo come ispirazione per le forme, niente codice copiato.

## Approcci considerati

- **A. Solo tema** (font, colori, forme in `tema.dart`). Rischio basso, ma la struttura delle schermate resta quella di oggi.
- **B. Tema + libreria di componenti, poi applicata alle schermate.** Scelta dall'utente.
- **C. Redesign completo con modalità scura e animazioni.** Troppo per il tempo disponibile; si raggiunge per gradi partendo da B.

Scelta: **B**, perché dà il look "app salute" senza toccare ciò che funziona, ed è la base di C.

## Decisioni (mie scelte, da correggere)

- **Font:** *Plus Jakarta Sans* per titoli ed etichette forti, *Inter* per il testo. Incorporati in `assets/fonts/`.
- **Colori:** resta il verde del marchio, ma con sfondo grigio-verde molto chiaro, card bianche, verde tonale per icone e badge. Tutti i colori passano da un `ThemeExtension` (`CenatoColori`) con la palette chiara; le pagine non usano più `ColoriCenato.*` direttamente.
- **Forme:** card con raggio 20 e ombra leggera al posto del bordino; campi di testo e bottoni con raggio 14; chip e filtri a pillola.
- **Intestazione:** titolo grande su sfondo chiaro al posto della fascia verde piena (`IntestazioneSezione` viene riscritta; la firma resta compatibile).
- **Navigazione:** barra in basso chiara con indicatore tonale e icone piene per la voce attiva.
- **Componenti nuovi** in `lib/presentation/comuni/`: titolo grande, card a sezioni, icona tonale, badge di stato, riga elenco. Gli stati caricamento/vuoto/errore esistenti vengono restilizzati.

## Tappe (un commit ciascuna)

1. Font incorporati, `CenatoColori`, `temaCenato()` aggiornato.
2. Componenti comuni e stati restilizzati.
3. Schermate di accesso, registrazione, recupero password.
4. Area nutrizionista (pazienti, invito, calendario, disponibilità, abbonamento, sponsor).
5. Area paziente (oggi, dieta, andamento, visite, collegamento) e profilo.
6. Voce in `docs/registro-decisioni.md`.

## Strada verso C

Dopo B, la modalità scura è: palette scura in `CenatoColori`, `darkTheme` e interruttore nel profilo. Le animazioni (transizioni, feedback del check-in, contatori) si aggiungono come interventi isolati sui componenti comuni.

## Come verifico

Installo Flutter nel container (non fa parte del repository), poi: `flutter analyze`, `flutter test`, e uno screenshot delle schermate principali con i dati finti (`dipendenze_finte.dart`) in versione web. Descrivo cosa ho provato e cosa no. Il test su telefono vero resta a voi.

## Lasciato al costruttore

Pesi e dimensioni esatte dei font, valori precisi di ombre e spaziature, tonalità esatte della palette entro i vincoli di contrasto.
