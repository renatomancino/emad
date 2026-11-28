# Formato del CSV per importare un piano

Requisiti `RF_GP_10`, `RF_GP_11`, `RNF_IN_4`; caso d'uso `UC_GP_5`, scenario `SC_GP_3`. Il modello scaricabile dall'app è [`assets/modello_piano.csv`](../assets/modello_piano.csv); il parser è `lib/data/csv_piano_parser.dart`.

## File

| Aspetto | Valore |
|---|---|
| Formato | CSV (i file `.xlsx`, PDF e foto non si importano: `RF_GP_12` è priorità B) |
| Codifica | **UTF-8**, con o senza BOM. Un file in Windows-1252 viene rifiutato con la spiegazione |
| Separatore | `;` (modello) oppure `,`, riconosciuto dalla riga di intestazione |
| Decimali | virgola o punto. Con il separatore `,` i decimali con la virgola vanno tra virgolette: `"12,5"` |
| Testo con il separatore | tra virgolette: `"Pane, integrale"` |
| Dimensione | al massimo 1000 righe di dati e 1 MB |

## Colonne

La prima riga è l'intestazione. Ordine e maiuscole sono liberi; altre colonne vengono ignorate.

| Colonna | Obbligatoria | Valori ammessi |
|---|---|---|
| `giorno` | sì | `Lunedì`…`Domenica` (anche senza accento), `Lun`…`Dom` oppure `1`…`7` |
| `pasto` | sì | `Colazione`, `Spuntino`, `Pranzo`, `Merenda`, `Cena` |
| `alimento` | sì | nome, fino a 200 caratteri |
| `quantita_g` | sì | grammi, maggiori di zero e al massimo 5000 (come nell'editor) |
| `note` | no | si vedono in anteprima ma **non si salvano** |

Esempio:

```csv
giorno;pasto;alimento;quantita_g;note
Lunedì;Colazione;Latte parzialmente scremato;200;
Lunedì;Pranzo;Olio extravergine d'oliva;12,5;a crudo
```

## Da Excel

*File → Salva con nome → CSV UTF-8*. Il formato "CSV" semplice di Excel su Windows usa un'altra codifica e viene rifiutato.

## Cosa succede all'importazione

1. **File non utilizzabile** (vuoto, solo intestazione, colonne mancanti, codifica diversa, troppe righe): messaggio e nessuna anteprima.
2. **Anteprima**: righe riconosciute, righe con errori (numero di riga, colonna, motivo) e alimenti. Il numero di riga è quello del foglio, con l'intestazione alla riga 1.
3. **Abbinamento**: l'app abbina da sola solo i nomi **identici** (ignorando maiuscole, accenti, spazi doppi e tipo di apostrofo) con tutti i valori nutrizionali, prima tra gli alimenti salvati e poi su Open Food Facts. Gli altri si scelgono a mano, si creano o si ignorano.
4. La conferma è possibile solo quando ogni riga errata è ignorata e ogni alimento è abbinato o ignorato.
5. La conferma apre una **bozza** nell'editor. Il piano viene assegnato al paziente solo con *Salva e assegna* (✓).
