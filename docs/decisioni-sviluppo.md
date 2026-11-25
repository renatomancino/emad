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

