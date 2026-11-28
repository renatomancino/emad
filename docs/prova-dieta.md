# Prova della sezione Dieta del paziente

Cosa provare a schermo (telefono Android o emulatore). Tempo: circa 10 minuti. Requisiti: `RF_GP_8`, `RF_GP_16`, `RNF_U_3`, `RNF_U_6`; caso d'uso `UC_GP_4`; navigazione `NP_1_PAZ`; mock-up `UI_GP_1` (`docs/rad/img/ui_paz.png`, sezione Dieta). Decisioni in `docs/decisioni-sviluppo.md` (D32–D36).

Stanotte sono passati **solo i test automatici** (`flutter analyze` e `flutter test`, compreso `test/dieta_test.dart`). Nessuna di queste prove a schermo è stata fatta.

## 0. Database (prima della prova con Supabase)

Nessuna migrazione nuova. Per confermare che il paziente non legge piani altrui, esegui nel SQL Editor `supabase/tests/rls.sql` e controlla la riga **"PAZ A1 · Legge solo il proprio piano" = OK**, insieme alle altre righe tutte OK. Stanotte non è stato eseguito.

## 1. Senza Supabase (dati fittizi)

### 1a. Con piano

```bash
flutter run --dart-define=CENATO_RUOLO_FINTO=paziente
```

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Tocca **Dieta** nella barra inferiore | Intestazione "Dieta" con "Piano versione 1 · dal gg/mm/aaaa" (una settimana fa) |
| 2 | Guarda la parte alta | Card "I tuoi obiettivi giornalieri": **2000 kcal, 110 g proteine, 230 g carboidrati, 65 g grassi**; sotto, "Piano aggiornato il …" con la data di oggi |
| 3 | Guarda le pillole dei giorni | Lun…Dom; quella di oggi dice "**· oggi**" ed è già selezionata; il riepilogo dice "Giorno (oggi)" |
| 4 | Guarda il riepilogo del giorno | Totale kcal "su 2000 di obiettivo", chip con lo scostamento ("In linea" o "+/-N kcal (…%)"), proteine/carboidrati/grassi "totale / obiettivo g" |
| 5 | Scorri i pasti | Colazione, Spuntino, Pranzo, Cena, con orario e kcal; sotto, proteine/carboidrati/grassi del pasto; ogni alimento con grammi e kcal |
| 6 | Tocca **Alternative (1)** sotto "Cereali integrali" | Si apre "Al posto di Cereali integrali puoi scegliere: • Fette biscottate · 35 g · 144 kcal"; ritocca e si chiude |
| 7 | Tocca **Mer** (o Sab) | Pranzo con riso e verdure, cena con petto di pollo: i giorni sono diversi |
| 8 | Cerca un modo per modificare | Nessun pulsante per aggiungere, eliminare, spostare o salvare; nessun campo di testo |
| 9 | Trascina la lista verso il basso | Appare la rotellina del "tira per aggiornare" e il piano resta |
| 10 | Impostazioni di Android → Accessibilità → Dimensione carattere al massimo, poi torna in Dieta | Testi più grandi, valori degli obiettivi e chip vanno a capo, niente bande gialle/nere di overflow |
| 11 | TalkBack acceso, scorri la card obiettivi e un pulsante "Alternative" | Legge "2000 kcal" come un elemento solo; il pulsante dice se è espanso o compresso |
| 12 | Confronta con il mock-up UI_GP_1 | Stessi contenuti: obiettivi in alto, giorni, pasti con kcal e alternative |

### 1b. Senza piano

Ferma l'app e riavviala con:

```bash
flutter run --dart-define=CENATO_RUOLO_FINTO=paziente --dart-define=CENATO_DIETA_FINTA=senza_piano
```

(Un hot restart non basta: i `--dart-define` si leggono all'avvio.)

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Tocca **Dieta** | Intestazione "Dieta · Piano e obiettivi" |
| 2 | Guarda la pagina | Card obiettivi (2000/110/230/65) e sotto "**Il tuo nutrizionista sta preparando il piano**" con il messaggio |
| 3 | Trascina verso il basso | "Tira per aggiornare" funziona anche qui, nessun errore |
| 4 | Testo al massimo | Nessun overflow |

## 2. Con Supabase (paziente di prova)

### 2a. Con piano: `marco@example.com` (`docs/demo-dati.md`)

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Accedi come Marco → **Dieta** | Piano del seed: 7 giorni × colazione, spuntino, pranzo, cena, con alternative (es. avena → fette biscottate); obiettivi **2000 / 110 / 230 / 65** |
| 2 | Controlla versione e data | "Piano versione N · dal …" uguale allo storico versioni di Giulia per Marco |
| 3 | Su un altro telefono (o dopo aver fatto logout) entra come `giulia@example.com`, modifica il piano di Marco e salva (nuova versione) | — |
| 4 | Torna sul telefono di Marco, in Dieta, e **tira verso il basso** | Compare la nuova versione ("Piano versione N+1") con la modifica. Senza tirare non si aggiorna da sola tra due telefoni (D34) |
| 5 | Modalità aereo, poi tira verso il basso | Avviso "Aggiornamento non riuscito: vedi l'ultimo piano scaricato"; il piano resta |
| 6 | Modalità aereo, chiudi e riapri l'app, poi apri Dieta | Errore con **Riprova**. Il piano non viene salvato sul telefono: limite noto (D34). Disattiva la modalità aereo e tocca Riprova: torna il piano |

### 2b. Senza piano: un paziente nuovo

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Registra un paziente nuovo (email fittizia) con il codice `GIULIA26` | Arriva su Oggi |
| 2 | Apri **Dieta** | "Il tuo nutrizionista sta preparando il piano"; card obiettivi con "non ha ancora impostato gli obiettivi" |
| 3 | Come Giulia imposta gli obiettivi del nuovo paziente; poi su Dieta tira verso il basso | Compaiono gli obiettivi, resta lo stato vuoto del piano |
| 4 | Come Giulia crea e salva un piano; poi tira verso il basso | Compare il piano, versione 1 |
| 5 | Dopo la prova, archivia il paziente di prova | Non resta tra gli attivi di Giulia |

Se qualcosa non torna, annota passo e schermata: le scelte da rivedere sono D32–D36.
