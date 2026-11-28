# Decisioni di sviluppo

Scelte prese durante l'implementazione che il RAD non fissa. Non modificano i requisiti: li completano. Se una di queste va in contrasto con il RAD, prevale il RAD e la scelta va rivista. Il registro delle decisioni di progetto resta `docs/registro-decisioni.md`.

## Fase 1 · Account, inviti e profilo

### D1 · Eliminazione dell'account (UC_GA_5, RF_GA_7, GDPR art. 17)

Scelte confermate da Renato Mancino.

| Chi elimina | Cosa succede |
|---|---|
| **Paziente** | Si cancellano account, profilo, piano, obiettivi, check-in, pasti extra, peso, commenti, finestre e visite. Nell'elenco del nutrizionista resta una sola riga **"Account eliminato"**, archiviata, senza alcun dato personale. |
| **Nutrizionista** | Si cancellano il suo account, i piani, gli inviti, le visite, i commenti, le disponibilità **e tutti i dati dei suoi pazienti**. Gli account dei pazienti restano, scollegati: possono accettare l'invito di un altro nutrizionista. |

Motivazioni:

- La regola 3 di `CLAUDE.md` ("i pazienti non si eliminano, si archiviano") riguarda l'uso normale. La cancellazione **su richiesta** (regola 6) è un diritto dell'interessato e prevale.
- Il guscio anonimo tiene vero il conteggio del piano **Free** ("1 paziente a vita", regola 4): se chi elimina liberasse il posto, il limite si aggirerebbe creando e cancellando account. Il guscio non contiene dati personali (nome, altezza, obiettivo e data di nascita sono azzerati).
- Per il nutrizionista, i dati dei pazienti sono trattati per suo conto: senza di lui non c'è più titolare del trattamento, quindi si cancellano. Il paziente resta con il proprio account e può continuare con un altro nutrizionista.
- Nella schermata l'utente vede le conseguenze nel suo ruolo e deve scrivere `ELIMINA` per confermare.

Implementazione: `public.elimina_account()` (migrazione `005_elimina_account.sql`), `security definer`, agisce **solo** su chi la chiama. La cancellazione di un paziente collegato è normalmente vietata da un trigger: la funzione la consente con il parametro di transazione `cenato.consenti_reset`, valido solo dentro la funzione. Test: `supabase/tests/elimina_account.sql`.

### D2 · Il codice di invito si controlla prima di registrarsi (UC_GI_2, RF_GI_3)

La funzione `verifica_invito(codice)` è eseguibile anche da utenti **non autenticati** e restituisce solo nome del nutrizionista e scadenza. Così nella registrazione il paziente vede il nome del nutrizionista che lo ha invitato prima di creare l'account, e un codice sbagliato, scaduto, usato o revocato dà un messaggio distinto (CN010 … CN013) invece di far registrare un utente che poi non può collegarsi.

Non espone alcun dato del paziente invitato né l'elenco dei codici: serve conoscere il codice (8 caratteri casuali) e c'è la scadenza. Il controllo del limite del piano resta nel database, in `accetta_invito` (regola 5).

Il codice scelto in registrazione viene salvato nei metadati dell'utente (`codice_invito`) e **accettato in automatico al primo accesso confermato**: con la conferma email attiva il paziente registra l'account dal telefono, conferma dalla posta e trova già il collegamento fatto. Dopo il collegamento il campo si cancella.

### D3 · Consenso GDPR imposto dal database (RF_GA_1, art. 9)

Il consenso al trattamento dei dati sanitari non è solo una casella dell'app: il trigger di registrazione (`crea_profilo_da_auth`) **rifiuta** la creazione dell'utente senza `consenso_dati = true`, e salva data (`consenso_dati_il`) e versione (`versione_informativa`). La versione corrente è la costante `Informativa.versione` (`lib/core/costanti/informativa.dart`).

Il testo dell'informativa è una **bozza** per l'MVP e va rivisto da una persona competente prima di un uso reale.

### D4 · Registrazione con "Confirm email" attivo

Con la conferma email attiva (`docs/supabase.md`) `signUp` non restituisce una sessione: l'app mostra la schermata "Controlla la tua email" invece di entrare. Per un'email già registrata Supabase non dà errore (per non rivelare chi è iscritto), ma restituisce un utente senza `identities`: l'app lo riconosce e mostra "Esiste già un account con questa email.".

Il servizio email integrato di Supabase ha un limite orario di invii (errore 429): se si presenta in prova, basta attendere o usare un indirizzo con `+alias`. Per la demo si usano gli account già confermati di `docs/demo-dati.md`.

### D5 · Deep link per conferma email e nuova password (UC_GA_4)

L'app registra lo schema `it.unisa.cenato://login-callback` (`AndroidManifest.xml`) e lo passa a Supabase come `emailRedirectTo` / `redirectTo`. L'indirizzo va aggiunto ai **Redirect URLs** del progetto Supabase (`docs/supabase.md`). Quando arriva l'evento `passwordRecovery` il router porta alla schermata "Nuova password" e non lascia uscire finché non si salva.

### D6 · Password

Minimo 8 caratteri, con almeno una lettera e una cifra (`Validazione.password`). Il minimo di 8 è impostato anche in Supabase; la regola lettera + cifra vale solo nell'app. Messaggi di errore generici all'accesso ("email o password non corrette"), senza dire quale dei due è sbagliato.

### D7 · Primo accesso del nutrizionista e paziente non collegato

- Il nutrizionista che accede per la prima volta passa dalla schermata **Disponibilità** (UC_GV_3, "Più tardi" la salta): senza orari i pazienti non potrebbero prenotare.
- Il paziente non ancora collegato vede solo l'inserimento del codice invito, il profilo e l'eliminazione dell'account; il resto dell'app è bloccato dal router finché non è collegato. Dopo lo scollegamento (UC_GI_5) torna a quella schermata.

### D8 · Profilo

Il nutrizionista modifica nome e titolo; il paziente nome, altezza, data di nascita e obiettivo (dati usati dalle altre sezioni). Il ruolo e l'email non si cambiano: il ruolo è immutabile per trigger (`docs/supabase.md`).

## Fase 2 · Ricerca alimenti (Open Food Facts) con cache

Scheda Trello: *Ricerca alimenti (Open Food Facts) con cache* (UC_GP_3, UC_GP_2, RF_GP_3, RF_GP_5, RF_GP_14, RNF_IN_1, RNF_P_3, RNF_L_5). Decisioni 1–5 del 25/11/2026 confermate da Mario Celzo ("ok proposte").

### D9 · Alimenti con dati incompleti non finiscono in cache

Lo schema obbliga kcal e macro (`NOT NULL` in `alimenti`). Un risultato di Open Food Facts senza tutti i valori si **mostra con "Dati incompleti"**, non si può scegliere e non si salva; l'app propone **"Completa a mano"**, che apre il modulo dell'alimento personalizzato con il nome già scritto. Così la cache contiene solo alimenti completi ("non salvare in cache come completi", ticket). Valori fuori scala (kcal oltre 900, macro oltre 100 g su 100 g) contano come mancanti; se le kcal mancano o sono assurde si ricavano dai kJ (1 kcal = 4,184 kJ). Caso vero trovato: un pane con 1289 kcal e 950 kJ.

### D10 · Prima la cache, poi online

La ricerca guarda prima la cache (`alimenti`, per nome); con **almeno 5 risultati** non chiama Open Food Facts e offre "Cerca anche online". Con meno di 5 li completa con i risultati online, senza duplicati (stesso codice a barre, o stesso nome e marca). Si salva in cache **solo l'alimento scelto**. Se il servizio non risponde si mostrano i risultati della cache e lo si dice, senza bloccare nulla (UC_GP_3, flusso 2.2). Se il servizio è **lento**, i risultati della cache si vedono subito (barra di avanzamento accesa) e quelli online si aggiungono appena arrivano; una risposta di una ricerca superata dal testo nuovo non compare.

### D11 · Rispetto di Open Food Facts

- `User-Agent: Cenato/1.0 (Cenato)`: come contatto, il nome dell'app (scelta di Mario).
- Una richiesta per volta, timeout di 4 s; le ricerche in coda superate da una più nuova non partono e non pesano sul limite, attesa di 400 ms dopo l'ultima lettera, pagina di 20 prodotti, solo i campi necessari.
- **Al massimo 8 ricerche al minuto** (Open Food Facts ne accetta circa 10 per indirizzo): oltre, si usa la cache senza chiamare il servizio.
- Ricerca solo di prodotti **venduti in Italia** (`countries = italy`, `lc=it`) e ordinati per pertinenza: i risultati di "pane" non sono più crocchette "panate" e prodotti spagnoli. Il filtro è nel client perché la ricerca di Open Food Facts guarda anche gli ingredienti.
- Attribuzione "Dati: Open Food Facts (ODbL)" sempre visibile nella ricerca, con link (`url_launcher`; sul manifest Android la query per `https`).

### D12 · Recenti e preferiti (RF_GP_14)

Tabella `alimenti_nutrizionista` (migrazione `006`): una riga per nutrizionista e alimento con `preferito` e `ultimo_uso`; RLS sulle sole righe proprie. Si segna l'uso quando l'alimento viene scelto, creato o quando se ne tocca la stella.

### D13 · Dove si prova senza l'editor del piano

L'editor non esiste ancora. Finché non c'è, la ricerca si raggiunge dal **profilo del nutrizionista → "Alimenti"** (`/nutrizionista/profilo/alimenti`) con il widget `RicercaAlimento`, che l'editor riuserà.

### D14 · Struttura dei file

Il ticket indica `lib/data/open_food_facts_client.dart` e `lib/data/alimenti_repository.dart`. Si è seguita la struttura a livelli del repository: interfacce e modello in `domain/`, client in `data/open_food_facts/` (cartella già prevista), logica in `data/alimenti_repository.dart`, cache su Supabase in `data/supabase/`, versioni finte in `data/finto/`.

### D15 · Chi vede e chi modifica gli alimenti (migrazione 007)

Scelta di Mario Celzo ("completamente d'accordo"). Prima (002) ogni utente autenticato leggeva ogni alimento e **qualsiasi nutrizionista poteva modificare i valori degli alimenti di Open Food Facts**, cioè di una cache condivisa. Ora:

- **Open Food Facts:** li legge chiunque sia autenticato (dati pubblici ODbL); nessun client li modifica, l'app li inserisce soltanto.
- **Personalizzati:** li vede e li modifica solo chi li ha creato. Il **paziente** li vede solo se compaiono, come voce o come alternativa, in un piano che può leggere (gli servono per la sezione Dieta); una bozza non conta.
- **Senza proprietario** (`creato_da` nullo, i dati di prova del seed): restano leggibili da tutti, così la demo non cambia.
- Inserimenti: un alimento di Open Food Facts con `creato_da` nullo (o proprio); uno personalizzato solo a proprio nome.

Prove in `supabase/tests/alimenti_visibilita.sql`: 23 controlli, con le vecchie policy 7 falliscono.

### Tempi misurati (25/11/2026, dal container di sviluppo, `dart run tool/misura_ricerca.dart`)

| Ricerca | Esito | Tempo |
|---|---|---|
| "pane" | 10 risultati | 1318 ms |
| "latte" | 10 risultati | 1392 ms |
| "mela" | 10 risultati | 1241 ms |
| codice a barre (Nutella) | trovato | 581–647 ms |
| "pasta", "riso" e altre, a raffica | **503** di Open Food Facts | 500–740 ms |

I tempi sono quelli del solo client verso Open Food Facts (non comprendono l'attesa di 400 ms né le due letture su Supabase). Quando risponde, la ricerca per nome sta **sotto i 2 secondi** (RNF_P_3), ma da questo indirizzo il servizio rifiuta molte richieste con 503 (limite di ricerche o sovraccarico): è il caso "servizio non disponibile" e l'app ripiega sulla cache. **Da ripetere dal PC di Mario e da telefono**: `dart run tool/misura_ricerca.dart`.


## Obiettivi nutrizionali (UC_GP_6, RF_GP_16, SC_GP_4)

### D16 · Limiti dei valori e tolleranza (costanti in `lib/domain/regole/obiettivi.dart`)

| Costante | Valore | Note |
|---|---|---|
| `kcalMin` / `kcalMax` | 800 / 6000 | Il database accetta già 500–6000 (`obiettivi_kcal_check`): l'app è più prudente, come chiede la scheda. |
| `macroMaxG` | 1000 g | Soglia di plausibilità per ogni macronutriente; i macro devono essere > 0 e con un decimale (colonna `numeric(5,1)`). |
| `tolleranzaKcal` | 10 % | Scarto tra le kcal indicate e quelle dei macro (4/4/9 kcal per grammo) oltre il quale compare un **avviso non bloccante**. **[DA CONFERMARE]** con i nutrizionisti. |

Con i valori di SC_GP_4 (110 g P, 230 g C, 65 g G) i macro danno 1945 kcal contro 2000 indicate: scarto 2,75 %, nessun avviso.

### D17 · Storico e "nessuna modifica"

Ogni salvataggio inserisce una **nuova riga** in `obiettivi` (`data_inizio` = oggi); l'obiettivo corrente è l'ultima per `data_inizio` e, a parità, per `creato_il`. Se i valori inviati sono identici a quelli correnti non si crea una riga (si avvisa "Nessuna modifica"), per non gonfiare lo storico. Modificare gli obiettivi **non tocca i piani già assegnati**: cambia solo lo scostamento che l'editor calcolerà.

### D18 · Dove si raggiungono

Il dettaglio paziente non esiste ancora (scheda di Fase 3). Finché non c'è, "Obiettivi nutrizionali" è il primo pulsante nel pannello che si apre toccando un paziente **Attivo** (`/nutrizionista/pazienti/:id/obiettivi`). Per i pazienti archiviati il pulsante non c'è: gli obiettivi restano nello storico, ma non si modificano.

### Per le schede successive

- **Editor del piano (RM):** usare `ObiettiviRepository.corrente(pazienteId)` o `osserva(pazienteId)` (stream che riemette dopo ogni salvataggio). Se è `null`, invitare a impostarli senza bloccare l'editor.
- **Sezione Dieta (MC):** la stessa interfaccia vale per il paziente, perché la policy `obiettivi_select` gli consente di leggere i propri; serve però l'`id` della sua riga in `pazienti` (non l'id utente). Se non è già esposto dal repository del collegamento, aggiungerlo lì.

## Editor del piano (UC_GP_1, UC_GP_2, RF_GP_1, RF_GP_2, RF_GP_7, RF_GP_15, RF_GP_16)

### D19 · Salvataggio con una RPC transazionale (migrazione 008)

Le policy RLS (002) permettono di scrivere giorni, pasti e voci **solo su una versione in `bozza`**, e per assegnarla bisogna scambiare la versione `corrente`. Fatto dall'app sarebbero decine di chiamate: se la rete cade a metà, il paziente potrebbe restare senza piano. Per questo `salva_piano(paziente, data_inizio, struttura)` fa tutto in una transazione: controlla che il chiamante sia il nutrizionista di un paziente **attivo**, valida la struttura, crea la versione n+1, **ricalcola kcal e macro di ogni voce dai valori per 100 g** (l'app non può falsarli), porta la precedente a `superato` e la nuova a `corrente`. Le versioni vecchie restano e i check-in restano legati ai loro pasti. L'app non usa mai lo stato `bozza` per l'editor (la bozza serve all'importazione CSV, scheda di Mario).

Codici di errore nuovi: CN020 paziente non tuo o non attivo · CN021 struttura non valida · CN022 pasto senza alimenti · CN023 alimento non disponibile · CN024 quantità non valida.

### D20 · Costanti dell'editor (`lib/domain/regole/calcoli_piano.dart`)

| Costante | Valore | Decisione |
|---|---|---|
| `tolleranzaScostamento` | 10 % | **Confermata come ipotesi di lavoro.** Il registro delle decisioni (domande aperte, punto 13) indica 10% e il RAD (UC_GP_6, flusso 3.3) usa lo stesso 10% [DA CONFERMARE] per la coerenza kcal/macro; il README del RAD chiede di tenere questi valori come costanti. Oltre lo scarto il totale è "fuori obiettivo" (giallo, mai rosso: non è un giudizio clinico). Resta da validare con un nutrizionista, ma si cambia in un solo punto. |
| `quantitaRapideG` | 50, 100, 150, 200 | RF_GP_15 ("es. 50, 100, 150 g"): aggiunto 200 g, perché è la quantità di SC_GP_1 (200 ml di latte). |
| `quantitaMaxG` | 5000 g | **Deroga annotata.** Il RAD chiede solo "quantità maggiore di zero" (UC_GP_2, flusso 4.1) e non fissa un massimo. Il tetto è una guardia tecnica contro i refusi (200 digitato come 20000), non un requisito: nessun alimento di un piano reale si avvicina a 5 kg per voce. Il database accetta fino a 10000 g (`salva_piano`). Da segnalare a chi cura i documenti, perché il RAD non lo cita. |

Kcal e macro di una voce sono **arrotondati a un decimale** come `round(…, 1)` del database, così i totali mostrati prima di salvare coincidono con quelli salvati.

### D21 · Modifica = nuova versione; alternative conservate

Aprendo l'editor su un paziente con un piano in uso, si parte da quel piano e il salvataggio crea la **versione successiva** (mostrata nell'editor: "Versione N · dal …", con data di inizio modificabile). Le **alternative** (RF_GP_6) non si modificano ancora (scheda successiva) ma si **conservano**: passano nella nuova versione e si leggono nell'editor, così modificare un piano del seed non le perde. Lo storico (icona orologio) mostra le versioni e permette di **consultare, non ripristinare** una vecchia versione.

### D22 · Cosa blocca il salvataggio, cosa no

Bloccano: piano senza giorni, giorno senza pasti, pasto senza alimenti (UC_GP_1, flusso 8.1): l'avviso elenca i primi 4 problemi e riassume gli altri ("…e altri N"). **Non bloccano**: obiettivi mancanti (banner con "Imposta obiettivi") e totali fuori obiettivo. Uscendo con modifiche non salvate si chiede conferma.

### D23 · Dove si raggiunge e cosa riusare

Come per gli obiettivi, finché non c'è il dettaglio paziente (Fase 3) il pulsante **Piano alimentare** è nel pannello di un paziente Attivo (`/nutrizionista/pazienti/:id/piano`). Per le altre schede:

- **Sezione Dieta (MC):** `PianiRepository.corrente(pazienteId)` (con l'id della riga in `pazienti`, come per gli obiettivi) e il widget `PianoSolaLettura(piano, obiettivi)` in `lib/presentation/nutrizionista/piano/`, già pronto per giorni, totali, scostamento, voci e alternative.
- **Alternative / copia giorno / modelli (RM):** `PianoAlimentare` ha già `aggiungiGiorno`, `aggiungiPasto`, `aggiungiVoce`…; la RPC accetta già le alternative.
- **Notifiche:** il punto di aggancio per "nuovo piano" è in fondo a `salva_piano` (commento `>>> Aggancio notifica`) e in `PianiRepository.salva`.
- **Importazione CSV (MC):** costruisce un `PianoAlimentare` e lo passa a `PianiRepository.salva`.

## Alternative, giorno tipo con copia, pasti salvati e modelli (RF_GP_6, RF_GP_9, RF_GP_13–15; UC_GP_1, UC_GP_2; SD_1)

Nessuna migrazione nuova: `alternative` e `modelli_piano` esistevano già con le loro RLS, e `salva_piano` (008) accettava già le alternative.

### D24 · Alternative: per voce, solo alimenti, confronto con l'originale

Lo schema le lega alla **voce** (`alternative.voce_id`), non al pasto: ogni voce ha zero o più alternative, e **si scelgono alimenti** (con quantità), mai testo libero. Dal piano, sotto ogni voce c'è "Aggiungi alternativa" / "Alternative (N)" che apre una pagina con l'originale, le alternative ammesse e, per ognuna, il confronto in kcal ("+52 kcal rispetto all'originale"). L'app rifiuta di aggiungere come alternativa l'alimento della voce stessa o uno già presente (non è un vincolo del database). Le alternative **non entrano nei totali** del pasto.

Per il check-in (SD_1) il repository espone `PianiRepository.alternativePerPasto(pastoId)`: le alternative ammesse di un pasto, ognuna con la voce che sostituisce. **`AlternativaAmmessa.id` è il valore di `check_in.alternativa_id`** e il database rifiuta già (23514) un'alternativa che non è tra quelle del pasto. Ogni nuova versione del piano ha **id nuovi** (anche per pasti e voci): i check-in vecchi restano legati alla versione su cui sono stati fatti.

### D25 · Copia del giorno

"Copia lunedì su…" (menu dei giorni) apre l'elenco degli altri giorni con una casella ciascuno e "Tutti gli altri giorni"; ogni giorno dice se è nuovo, vuoto o ha già dei pasti. La copia è **profonda** (pasti, voci, alternative, orari, con chiavi nuove): modificare il giorno copiato non tocca l'originale. I giorni che mancano nel piano vengono creati. **La conferma "Sostituire i pasti?" si chiede solo se la destinazione ha degli alimenti**: un giorno con soli pasti vuoti non perde nulla e non conta come "ha già pasti" (UC_GP_1, passo 6).

### D26 · Pasti salvati e piani modello: copie con istantanea degli alimenti

Un modello vive in `modelli_piano` (solo del nutrizionista proprietario, RLS già provata) con la struttura in JSON. **Gli alimenti sono salvati per intero** (id, nome e valori per 100 g): il modello si apre senza interrogare la cache e **non cambia mai** se il piano di origine cambia. Usarlo inserisce un'altra copia (chiavi nuove). Conseguenze accettate:

- se un alimento personalizzato venisse modificato dopo, l'anteprima del modello userebbe i valori vecchi; al salvataggio del piano `salva_piano` ricalcola da quelli attuali (l'app oggi non ha una modifica degli alimenti);
- se un alimento non fosse più disponibile, `salva_piano` rifiuta il piano con CN023 e il messaggio lo dice.

Nome del modello: 1–120 caratteri (come il vincolo della tabella). Eliminare un modello non tocca i piani creati con esso. Un piano si salva come modello solo se è completo (senza pasti vuoti). "Parti da un piano modello" è nella schermata di un piano nuovo.

### D27 · Avvisi sopra i fogli

Uno snackbar ancora visibile può coprire il pulsante di un foglio che si apre subito dopo (successo davvero nel test: "Lunedì copiato…" sopra "Copia"). I fogli dell'editor (quantità, copia del giorno, modelli) chiudono gli avvisi aperti prima di mostrarsi.

### Per le altre schede

- **Oggi / check-in (MC):** `alternativePerPasto(pastoId)` dà le uniche scelte del check-in "Alternativa"; salva `AlternativaAmmessa.id` in `check_in.alternativa_id`.
- **Sezione Dieta (MC):** `PianoSolaLettura` mostra già le alternative di ogni voce.
- **`Dipendenze` ha il nuovo campo `modelli`** (richiesto): chi la costruisce a mano deve passarlo. `AlternativaPiano` ha ora un `id` facoltativo.


## Scansione barcode (RF_GP_4, UC_GP_3, SC_GP_2, SD_2, RNF_IN_3)

Scheda Trello: *Scansione barcode*. Funzione **non rinviata**: è nell'MVP e non c'è da avvisare chi cura i documenti. Schermate in `docs/scansione-barcode/` (`flusso-scansione.png` le riassume); checklist per il telefono in `docs/prova-scansione.md`.

### D28 · Codice a barre unico per fonte e per nutrizionista (migrazione 009)

`alimenti.codice_barre` era unico in tutta la tabella (001). Con la scansione, un prodotto che Open Food Facts non conosce si inserisce a mano come **personalizzato con il codice letto** (SC_GP_2, passo 5), e i personalizzati sono privati (D15): se Giulia ha già inserito il codice X, Elena non lo vede e, inserendolo anche lei, avrebbe ricevuto un errore di unicità che le rivela un dato altrui e la blocca. La 009 sostituisce il vincolo con due indici unici parziali: **unico tra gli alimenti di Open Food Facts** (la cache condivisa non si duplica) e **unico per nutrizionista tra i personalizzati**. Un personalizzato e uno di Open Food Facts possono avere lo stesso codice (il prodotto arriva su Open Food Facts dopo); la scansione preferisce **il personalizzato proprio**, perché il nutrizionista lo ha inserito apposta.

Provata su PostgreSQL 16 locale con lo schema `auth` simulato: `supabase/tests/codice_barre.sql` dà **12 OK** (prima della 009 i casi 5, 9 e 10 falliscono, come atteso); `rls.sql` 50, `alimenti_nutrizionista.sql` 21, `alimenti_visibilita.sql` 23, `piano_salva.sql` 37, `modelli_alternative.sql` 32, `schema_vincoli.sql` 16, tutti OK. La 009 si riesegue senza errori. Il **27/11/2026** la 009 è stata **applicata sul Supabase del gruppo** (SQL Editor): lì `codice_barre.sql` dà 12 OK e il Security Advisor non mostra avvisi nuovi su `alimenti`. Senza la 009 l'app funziona lo stesso, ma due nutrizionisti non possono inserire a mano lo stesso prodotto sconosciuto.

### D29 · Prima la cache, poi Open Food Facts; si salva solo ciò che si aggiunge

`AlimentiRepository.perCodiceBarre(codice)` guarda prima la cache (`alimenti`, per codice, con la RLS): se c'è, **Open Food Facts non si chiama**. Altrimenti chiama `/api/v2/product/{codice}`. Esiti: trovato, incompleto (D9: niente cache, si propone "Inserisci a mano" con nome e valori noti già scritti), non trovato (UC_GP_3, flusso 2.1) e servizio non disponibile (flusso 2.2: "Riprova" senza riscansionare, oppure inserimento a mano). Come per la ricerca per nome (D10), l'alimento va in cache con fonte e codice **solo quando si tocca "Aggiungi al pasto"**, poi passa alla quantità come prima (SD_2).

Il codice letto si **normalizza** (`lib/domain/regole/codice_barre.dart`): EAN-13 ed EAN-8 restano come sono; UPC-A diventa EAN-13 con lo 0 davanti, come lo salva Open Food Facts; UPC-E si espande in UPC-A. Una lettura con la cifra di controllo sbagliata si scarta e si continua a inquadrare. Il codice salvato è quello normalizzato, anche se Open Food Facts risponde in un'altra forma: così la scansione successiva lo trova in cache.

### D30 · Permesso della fotocamera senza pacchetti in più

La scheda vieta pacchetti diversi da `mobile_scanner`, che chiede il permesso da solo quando avvia la fotocamera ma non dice prima se c'è già. Per spiegare il permesso **solo quando serve** (RNF_IN_3) e aprire le impostazioni se è stato negato (UC_GP_3, flusso 1.1), `MainActivity.kt` espone un piccolo canale `it.unisa.cenato/fotocamera` con `permessoConcesso` e `apriImpostazioni`. Flusso: permesso già dato → anteprima subito; altrimenti spiegazione → "Consenti fotocamera" → dialogo di Android; se negato, schermata con **"Cerca per nome"** (principale), "Apri impostazioni" e il percorso scritto. Tornando dalle impostazioni con il permesso dato, la fotocamera riparte da sola. Nel manifest: permesso `CAMERA` e `android.hardware.camera` **non obbligatoria** (l'app si installa anche senza fotocamera; resta la ricerca per nome).

### D31 · Letture, fotocamera chiusa, torcia, demo

- **Letture ripetute:** `DetectionSpeed.noDuplicates` di `mobile_scanner`, più un filtro (`FiltroLetture`, 3 s) sullo stesso codice. Alla prima lettura valida l'anteprima **esce dall'albero dei widget**, quindi la fotocamera si chiude subito (e si chiude uscendo dalla schermata). Si sospende anche quando l'app va in secondo piano.
- **Feedback:** vibrazione breve (`HapticFeedback`, nessun pacchetto) e "Cerco il codice…".
- **Torcia:** pulsante in alto a destra, solo se il telefono ce l'ha.
- **Ingresso:** icona nel campo di "Aggiungi alimento" (editor del piano e alternative; dalle alternative il pulsante si chiama "Usa come alternativa"). "Cerca per nome" torna al campo con il cursore. Il profilo → "Alimenti" non ha la scansione: lì non c'è un pasto a cui aggiungere.
- **Fotocamera simulata:** con `--dart-define=CENATO_RUOLO_FINTO=nutrizionista` (demo senza Supabase, browser, emulatore) l'anteprima è sostituita da pulsanti che "leggono" un codice del catalogo finto (trovato, incompleto, sconosciuto) o negano il permesso. **Nell'app vera non compare**: dipende da una costante di compilazione. I codici del catalogo finto ora hanno la cifra di controllo valida.
- **Colori:** il fondo nero e il bianco della fotocamera sono nel tema (`fotocamera`, `sullaFotocamera`), come vuole `tema_test.dart`.

### Per le altre schede

- **Importazione CSV (MC):** per abbinare righe con un codice a barre si può usare `AlimentiRepository.perCodiceBarre` (prima la cache, poi Open Food Facts).
- `AlimentiRepository.creaPersonalizzato` accetta ora `codiceBarre`; `AlimentiCache` ha `perCodiceBarre`; un doppione dello stesso codice tra i propri personalizzati dà `ErroreOperazione` con codice `codice_barre_esistente`.


## Sezione Dieta del paziente (UC_GP_4, RF_GP_8, RF_GP_16, RNF_U_3, RNF_U_6)

Scheda Trello: *[MC] Sezione Dieta del paziente (piano e obiettivi)*. Nessuna migrazione: le policy di lettura c'erano già (vedi D36). Checklist per il telefono in `docs/prova-dieta.md`. Scelte fatte di notte senza poter chiedere: **da rivedere con Mario**.

### D32 · Testo dello stato vuoto e obiettivi senza piano

UC_GP_4, flusso 2.1, scrive *"il tuo nutrizionista non ha ancora assegnato un piano"*; la scheda chiede *"Il tuo nutrizionista sta preparando il piano"*. Si usa il **testo della scheda**, più recente e meno brusco, con sotto "Quando il piano sarà pronto lo troverai qui… Tira verso il basso per controllare". Se mancando il piano gli obiettivi ci sono già (UC_GP_6 viene prima di UC_GP_1), **la card degli obiettivi resta visibile** sopra lo stato vuoto, perché RF_GP_16 li vuole visibili al paziente. Se mancano anche gli obiettivi, la card dice "Il tuo nutrizionista non ha ancora impostato gli obiettivi." Da allineare nel RAD (passo 2.1) se il testo della scheda va bene.

### D33 · Quale riga di `pazienti`: `CollegamentoRepository.mioPazienteId()`

Come chiedevano D18 e D23, piani e obiettivi si leggono con l'**id della riga in `pazienti`**, non con l'id utente. Il nuovo metodo `CollegamentoRepository.mioPazienteId()` legge `pazienti` con `utente_id = utente autenticato` **e `stato = 'attivo'`**: chi si è scollegato e poi ricollegato ha più righe, e quelle archiviate non devono contare. Senza riga attiva restituisce `null` e la sezione mostra lo stato vuoto (di solito il router porta prima alla schermata del codice di invito). Nel finto l'id è `p1` (Marco), diverso apposta dall'id utente `finto-paziente`: un test fallisce se qualcuno usa l'id sbagliato.

### D34 · Versione corrente sempre, aggiornamento e rete assente

- La pagina legge `PianiRepository.corrente` e `ObiettiviRepository.corrente` all'apertura e si **ricarica da sola** quando i repository avvisano di un salvataggio. Sullo stesso telefono succede subito; tra due telefoni diversi l'app oggi **non ha un canale in tempo reale** (Supabase Realtime non è usato), quindi vale il **"tira per aggiornare"** (la scheda lo accetta) oppure riaprire la sezione.
- **UC_GP_4, flusso 2.2:** se l'aggiornamento fallisce e un piano è già a schermo, **resta quello** con l'avviso "Aggiornamento non riuscito: vedi l'ultimo piano scaricato". L'errore a tutta pagina con "Riprova" compare solo se non è mai stato caricato nulla. **Limite:** "l'ultimo piano scaricato" vale finché l'app resta aperta. Una copia sul telefono che sopravviva alla chiusura dell'app (cache offline) **non è stata fatta**: richiederebbe un pacchetto o un file locale con dati sanitari, una scelta da prendere insieme (RNF di sicurezza). Da decidere se serve per la demo.
- Se la nuova versione non ha più il giorno selezionato, la pagina passa al giorno di oggi o al primo del piano. Prima `PianoSolaLettura` avrebbe mostrato "Questo piano non ha giorni".

### D35 · Riuso di `PianoSolaLettura` e niente calcoli nuovi

La sezione usa `PianoSolaLettura` e `RigaVoce` con parametri **facoltativi**, i cui valori predefiniti lasciano lo storico delle versioni e l'editor come prima:

- `giornoIniziale` / `giornoOggi`: si apre sul giorno di oggi; la sua pillola dice **"Lun · oggi"** e il riepilogo **"Lunedì (oggi)"**. L'evidenza è anche **a testo**, non solo a colore (RNF_U_3).
- `intestazione`: la card "I tuoi obiettivi giornalieri" (kcal, proteine, carboidrati, grassi, come nel mock-up UI_GP_1) e "Piano aggiornato il gg/mm/aaaa" (`creato_il` della versione). L'intestazione della pagina dice "Piano versione N · dal gg/mm/aaaa".
- `macroPerPasto`: sotto ogni pasto proteine, carboidrati e grassi (da `macroPasto`).
- `alternativeEspandibili`: le alternative sono dietro **"Alternative (N)"** (pulsante alto 48 dp, stato aperto/chiuso annunciato al lettore di schermo). Aperte, mostrano "Al posto di X puoi scegliere:" e per ognuna alimento, grammi e kcal (da `macroVoce`). Le alternative non entrano nei totali (D24).
- Il totale del giorno e lo scostamento dagli obiettivi sono quelli di `RiepilogoGiorno` (`macroGiorno`, `scostamento`): **nessun totale ricalcolato con codice nuovo**.
- Il selettore mostra i **giorni del piano** (nel seed sono sempre tutti e sette). Se un piano non prevede un giorno, quella pillola non c'è: non si inventa un giorno vuoto.

Nessuna azione di modifica: niente pulsanti di aggiunta, cestini, maniglie o menu. L'unico pulsante a icona è il profilo nell'intestazione, come nelle altre sezioni.

### D36 · Sicurezza: cosa garantisce che il paziente non legga piani altrui

Nessuna migrazione nuova. In `002_rls.sql` la lettura di `piani`, `giorni`, `pasti`, `voci_pasto` e `alternative` passa da `privato.piano_leggibile`: il paziente legge solo le versioni **non in bozza** dei piani legati a una sua riga di `pazienti`. `obiettivi_select` usa `e_mio_collegamento`. Il paziente **non ha policy di scrittura** su queste tabelle, e il salvataggio passa da `salva_piano`, che controlla che il chiamante sia il nutrizionista. Il test esistente `supabase/tests/rls.sql` contiene "PAZ A1 · Legge solo il proprio piano". **Stanotte non è stato eseguito**: sul Mac non c'è PostgreSQL e Supabase non andava toccato. Va rieseguito domattina (`docs/prova-dieta.md`, punto 0).

### Come provarla senza Supabase

- `flutter run --dart-define=CENATO_RUOLO_FINTO=paziente`: Marco con **piano di prova** (7 giorni, alternative a colazione, pranzo e cena) e obiettivi 2000/110/230/65.
- `flutter run --dart-define=CENATO_RUOLO_FINTO=paziente --dart-define=CENATO_DIETA_FINTA=senza_piano`: **solo obiettivi**, stato vuoto.

I dati sono in `lib/data/finto/dieta_finta.dart` e li carica solo `main.dart`, non `DipendenzeFinte`: i test partono sempre senza piani.

### Per le altre schede

- **Oggi / check-in (MC):** `CollegamentoRepository.mioPazienteId()` dà l'id per `check_in.paziente_id` e per `PianiRepository.corrente`. Il piano di prova di `DietaFinta` può servire anche alla sezione Oggi in modalità finta.
- **Notifiche:** il "nuovo piano" visto dal paziente su un altro telefono oggi richiede il "tira per aggiornare" (D34). Una notifica o Realtime lo renderebbero automatico.
