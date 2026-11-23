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
