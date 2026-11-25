# Prova della ricerca alimenti prima della demo

Cosa non si può provare da un ambiente di sviluppo senza il progetto Supabase del gruppo e senza un telefono. Tempo: circa 15 minuti. Requisiti: `RF_GP_3`, `RF_GP_5`, `RF_GP_14`, `RNF_P_3`, `RNF_L_5`.

## 1. Database (SQL Editor del progetto Supabase del gruppo)

1. Esegui `supabase/migrations/006_alimenti_nutrizionista.sql`, poi `007_alimenti_visibilita.sql`. Controlla in *Table Editor* che esista `alimenti_nutrizionista` e in *Authentication → Policies* le tre policy di `alimenti` (`alimenti_select`, `alimenti_insert_nut`, `alimenti_update_nut`).
2. Esegui uno per volta, ciascuno in una transazione annullata, e controlla che **ogni riga abbia esito `OK`**:
   - `supabase/tests/rls.sql` (50 controlli)
   - `supabase/tests/alimenti_nutrizionista.sql` (21 controlli)
   - `supabase/tests/alimenti_visibilita.sql` (23 controlli)
3. *Reports → Security Advisor*: nessun avviso nuovo (la funzione `privato.alimento_in_piano_leggibile` è nello schema privato).

## 2. Giro vero con l'app (account di prova di `docs/demo-dati.md`)

Accedi come `giulia@example.com` (password `CenatoDemo2026!`), poi **Profilo → Alimenti**.

| # | Cosa fai | Atteso |
|---|---|---|
| 1 | Scrivi "pane" e aspetta | Dopo circa mezzo secondo compaiono risultati con kcal e macro per 100 g (prodotti italiani, quelli che iniziano per "Pane" per primi). Tempo totale sotto i 2 s |
| 2 | Tocca un risultato | Messaggio "«…» salvato tra i recenti" |
| 3 | Cancella il testo | Compare "Usati di recente" con quell'alimento |
| 4 | Scrivi di nuovo "pane" | L'alimento scelto è **il primo** (viene dalla cache) |
| 5 | Tocca la stella su un risultato, poi cancella il testo | Compare "Preferiti" |
| 6 | Scrivi "xyzxyz" → "Crea alimento personalizzato" | Modulo; compila nome, kcal (es. 380) e macro (anche con la virgola), salva; ricerca il nome: lo ritrovi |
| 7 | Scrivi una parola con dati incompleti nel nome (se capita) | Etichetta "Dati incompleti"; toccandolo, "Completa a mano" |
| 8 | Riga in fondo | "Dati: Open Food Facts (ODbL)" visibile; toccandola si apre il sito |
| 9 | Spegni il Wi-Fi e cerca un nome già scelto | Compare l'avviso "Non riesco a contattare Open Food Facts" e i risultati della cache; l'app non si blocca |
| 10 | Accedi come `elena@example.com` e cerca il nome dell'alimento personalizzato di Giulia | **Non** lo trova (gli alimenti personalizzati sono privati) |
| 11 | Accedi come `marco@example.com` (paziente) → Dieta | Il piano (quando arriverà la sezione) mostra anche gli alimenti personalizzati di Giulia che contiene |

Se il passaggio 1 non mostra risultati o impiega più di 2 s, avvia `dart run tool/misura_ricerca.dart` sullo stesso PC: Open Food Facts limita le ricerche (circa 10 al minuto per indirizzo) e a volte risponde 503; l'app in quel caso usa la cache.

## 3. Telefono

Ripeti i passaggi 1-6 e 9 su un telefono Android con l'APK di debug o di release. Controlla in particolare che il link di attribuzione si apra nel browser e che con il testo di sistema ingrandito niente venga tagliato.

## Pulizia

I passaggi 2 e 6 lasciano nel database un alimento di Open Food Facts e uno personalizzato di Giulia: puoi lasciarli (la cache serve proprio a questo) oppure cancellarli dal *Table Editor* di `alimenti`.
