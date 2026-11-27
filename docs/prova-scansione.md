# Prova della scansione barcode prima della demo

Cosa provare su un telefono Android vero (l'emulatore non inquadra prodotti veri). Tempo: circa 10 minuti. Requisiti: `RF_GP_4`, `RF_GP_5`, `RNF_IN_3`, `RNF_L_5`; casi d'uso `UC_GP_3`, scenario `SC_GP_2`, sequence `SD_2`. Decisioni in `docs/decisioni-sviluppo.md` (D28–D31).

## 0. Database

Esegui nel SQL Editor `supabase/migrations/009_codice_barre_personalizzati.sql`, poi `supabase/tests/codice_barre.sql`: **12 righe OK**.

## 1. Giro sul telefono (account `giulia@example.com`, `docs/demo-dati.md`)

Pazienti → un paziente **Attivo** → **Piano alimentare** → in un pasto **Aggiungi alimento** → icona di scansione nel campo di ricerca.

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Prima apertura | Schermata "Serve la fotocamera" con la spiegazione; "Consenti fotocamera" apre il dialogo di Android |
| 2 | Consenti e inquadra un prodotto noto (es. Nutella 3017620422003, pasta Barilla) | Vibrazione, fotocamera chiusa, "Prodotto trovato" con nome, marca e kcal/P/C/G per 100 g, "Dati: Open Food Facts (ODbL)" in fondo |
| 3 | "Aggiungi al pasto", poi 125 g | L'alimento è nel pasto, kcal e macro del pasto e del giorno aggiornati |
| 4 | Scansiona di nuovo lo stesso prodotto | Trovato subito ("già tra gli alimenti salvati"): non è stato chiamato Open Food Facts |
| 5 | Torcia (in alto a destra), in una stanza buia | Si accende e si spegne |
| 6 | Inquadra un codice che non è su Open Food Facts (un prodotto da supermercato locale o un'etichetta stampata) | "Prodotto non trovato" con il codice → "Inserisci a mano": modulo con "Codice a barre: …"; salva → torna all'editor e chiede la quantità |
| 7 | Scansiona di nuovo il prodotto del passo 6 | Trovato come "tuo alimento personalizzato" |
| 8 | Wi-Fi e dati spenti, codice mai scansionato | "Open Food Facts non risponde" con "Riprova" e "Inserisci a mano"; l'app non si chiude |
| 9 | Impostazioni di Android → App → Cenato → Autorizzazioni → Fotocamera: **Non consentire**; riapri la scansione → "Consenti fotocamera" | "Fotocamera non consentita" con "Cerca per nome" e "Apri impostazioni" |
| 10 | "Cerca per nome" | Si torna alla ricerca con il cursore nel campo |
| 11 | "Apri impostazioni", consenti, torna indietro | La fotocamera riparte da sola |
| 12 | Durante l'anteprima premi Home e poi rientra | La fotocamera si ferma e riparte |

## 2. Senza telefono (browser o emulatore)

`flutter run --dart-define=CENATO_RUOLO_FINTO=nutrizionista`: la fotocamera è **simulata** (pulsanti "Yogurt greco (trovato)", "Prodotto senza dati (incompleto)", "Codice sconosciuto", "Nega il permesso"). Serve per vedere tutte le schermate, non sostituisce il giro del punto 1.
