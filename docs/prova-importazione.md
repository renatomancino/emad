# Prova dell'importazione del piano da CSV

Requisiti `RF_GP_10`, `RF_GP_11`, `RNF_IN_4`, `RNF_P_4`; caso d'uso `UC_GP_5`, scenario `SC_GP_3`. Account `giulia@example.com` (`docs/demo-dati.md`). Decisioni D37–D40.

**Non toccare ✓ sul piano di un paziente demo** se non vuoi creare una nuova versione. Anche **Crea bozza** scrive qualcosa: segna gli alimenti tra i recenti di chi importa.

In **modalità finta** (`CENATO_RUOLO_FINTO`) il modello non si abbina da solo: i suoi nomi vengono dai dati di prova del seed, non dal catalogo finto, quindi molti risultano "da abbinare". Non è un errore.

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Pazienti → un paziente attivo → Piano alimentare → menu ⋮ (o schermata del piano nuovo) → **Importa da file** | Schermata "Importa piano" |
| 2 | **Scarica modello CSV** e salvalo in Download | Messaggio "Modello salvato" |
| 3 | **Scegli file CSV** → il modello appena salvato | Anteprima: 14 righe riconosciute, 0 con errori; gli alimenti si abbinano uno alla volta con la barra di avanzamento; con i dati di prova del seed restano 0 da abbinare. Cronometrare (RNF_P_4, 5 s): vedi "Tempi misurati" |
| 4 | **Crea bozza** | Editor con lunedì e martedì, messaggio "Bozza pronta: 14 righe importate, 0 ignorate" |
| 5 | Freccia indietro → **Esci** | Nessuna nuova versione nello storico |
| 6 | Importa un file con 3 righe errate (`test/fixtures/piano_con_errori.csv`) | Le 3 righe con numero, colonna e motivo; "Crea bozza" spento finché non le ignori |
| 7 | Importa un file con un nome inventato | "Non trovato" con **Scegli**, **Crea**, **Ignora** |
| 8 | **Scegli** | La ricerca si apre con il nome già scritto |
| 9 | Importa un file `.xlsx` o un file vuoto | Messaggio chiaro, nessuna anteprima |
| 10 | Testo di sistema al massimo | Nessun taglio o overflow |

Per copiare i file di prova sull'emulatore:

```bash
adb push test/fixtures/piano_con_errori.csv /sdcard/Download/
```

## Tempi misurati (28/11/2026, emulatore Android, Supabase del gruppo, modello da 14 righe)

Dal tocco sul file alla fine dell'abbinamento, con catture ripetute dello schermo (precisione 1-2 s). Comprende la chiusura della finestra di sistema che sceglie il file.

| Versione | Abbinamento (anteprima visibile → finito) | Totale dal tocco |
|---|---|---|
| Ricerche una alla volta | circa 10 s a caldo; oltre 20 s la prima volta | 16 s e oltre |
| Ricerche in cache a gruppi di 8 | circa 9 s, 3 s e 6 s in tre prove | 20 s, 6 s e 13 s |

L'anteprima con righe ed errori compare subito dopo la lettura del file. **Il limite di 5 s per l'abbinamento completo non è confermato**: va misurato su un telefono vero. Se non bastasse, il passo successivo è chiedere tutti i nomi con una sola interrogazione.
