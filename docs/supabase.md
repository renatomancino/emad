# Supabase: configurazione del back-end

Come rifare da zero la configurazione di Supabase per Cenato.
Requisiti: RNF_I_2 (back-end cloud con autenticazione), RNF_I_4 (regione UE), RNF_I_5 (chiavi fuori dal repository), RNF_I_6 (riattivazione prima della demo), RNF_L_1 e RNF_L_2 (dati sanitari e accessi).

## 1. Creare il progetto in regione UE

1. Accedi a [supabase.com](https://supabase.com) → **New project**.
2. Scegli l'organizzazione, un nome (es. `cenato`) e una password del database robusta. La password **non va nel repository** e all'app non serve.
3. **Region**: una regione UE: *West EU (Ireland)* `eu-west-1`, *Central EU (Frankfurt)* `eu-central-1` o *West EU (Paris)* `eu-west-3`. La regione **non si cambia dopo la creazione**.
4. Piano **Free** → *Create new project* e attendi che lo stato diventi *Healthy*.

Progetto attuale del gruppo: regione `eu-west-1` (Irlanda), Postgres 17.

## 2. Autenticazione email e password

In **Authentication → Sign In / Providers**:

| Impostazione | Valore | Perché |
|---|---|---|
| Email provider | attivo | Accesso con email e password (RF_GA_1, RF_GA_2) |
| Confirm email | **attivo** | Verifica che l'email sia del paziente o del nutrizionista. Per lo sviluppo si può disattivare, ma va riattivato e annotato nel registro delle decisioni |
| Minimum password length | 8 | Coerente con il messaggio dell'app ("almeno 8 caratteri") |

In **Authentication → URL Configuration**:

- **Redirect URLs**: aggiungi `it.unisa.cenato://login-callback`. È il deep link registrato in `AndroidManifest.xml`: lo usano i link di conferma email e di reimpostazione password (UC_GA_1, UC_GA_4). **Senza questa voce il link nella email non riapre l'app** e Supabase ripiega sul Site URL.
- **Site URL**: lascia il valore predefinito (l'app è mobile, non c'è un sito).

In **Authentication → Emails**:

- Il servizio email integrato è pensato solo per le prove: ha un limite di pochi invii all'ora. Per la demo bastano gli account di prova già confermati (vedi `docs/demo-dati.md`). Per un uso reale serve un SMTP proprio (*Authentication → Emails → SMTP Settings*).
- I testi delle email (conferma, reset password) si possono tradurre in italiano da *Email Templates*.

> Il **reset password** funziona con l'email integrata: l'app chiama `resetPasswordForEmail` (UC_GA_4); il link riapre l'app (deep link sopra) sulla schermata "Nuova password". Con "Confirm email" attivo, anche la registrazione manda una email: l'utente la apre dal telefono per confermare l'account. Il servizio integrato ha un limite orario di invii: se compare l'errore 429 ("troppe richieste") basta attendere.

## 3. Eseguire le migrazioni

Le migrazioni sono in `supabase/migrations/` e vanno eseguite **in ordine**:

| File | Contenuto | Scheda Trello |
|---|---|---|
| `000_profili.sql` | Tabella `profili` con ruolo, trigger su `auth.users`, ruolo non modificabile | Progetto Supabase (UE) e autenticazione |
| `001_schema.sql` | Tutte le tabelle del Class Diagram, enum e vincoli | Schema del database |
| `002_rls.sql` | Row Level Security, policy per ruolo e funzioni RPC | Policy RLS per ruolo |
| `003_abbonamento.sql` | Regola dei posti occupati in un solo punto, stato dell'abbonamento, cambio piano simulato | Piani Free/Start/Pro, limiti e abbonamento simulato |
| `004_account_inviti.sql` | Consenso GDPR obbligatorio e versione dell'informativa alla registrazione; verifica del codice di invito prima di registrarsi (`verifica_invito`, anche da non autenticati) con errori distinti CN010…CN013; `accetta_invito` rinnovata | Registrazione con ruolo e consenso, Accettazione invito |
| `005_elimina_account.sql` | `elimina_account()`: cancella i dati clinici e l'account (art. 17 GDPR) | Profilo ed eliminazione account |
| `008_salva_piano.sql` | `salva_piano()`: salva e assegna il piano come **nuova versione** in una sola transazione (tutto o niente), con controlli sulla struttura e kcal/macro ricalcolati dal database; errori CN020…CN024 | Editor del piano |
| `009_codice_barre_personalizzati.sql` | Codice a barre unico tra gli alimenti di Open Food Facts e, tra i personalizzati, unico **per nutrizionista** (prima era unico in tutta la tabella); indice per la ricerca per codice | Scansione barcode |

Due modi:

- **SQL Editor** (consigliato per il gruppo): *SQL Editor → New query*, incolla il contenuto del file e premi **Run**. Ripeti per ogni file, in ordine.
- **Supabase CLI**: `supabase link --project-ref <id>` e poi `supabase db push`.

Poi i dati di prova: vedi `docs/demo-dati.md`.

## 4. Collegare l'app (file `.env`)

In **Project Settings → API Keys**:

- **Project URL** → `SUPABASE_URL`
- chiave **publishable** (`sb_publishable_...`) oppure la legacy **anon** → `SUPABASE_ANON_KEY`

Scrivile nel file `.env` sulla radice del progetto (creato da `.env.example`). Il file è ignorato da Git.

**Mai** usare nell'app la chiave **secret** / **service_role**: scavalca tutte le policy RLS. Se per errore finisce in un commit va considerata compromessa e rigenerata (*API Keys → Roll*). L'app rifiuta di partire se riconosce una chiave segreta in `.env`.

## 5. Come funziona il ruolo

1. L'app registra l'utente con `supabase.auth.signUp(..., data: {'ruolo': 'nutrizionista' | 'paziente', 'nome': ..., 'consenso_dati': true, 'versione_informativa': '1.0', 'codice_invito': ...})`.
2. Il trigger `su_nuovo_utente_crea_profilo` su `auth.users` crea la riga in `profili` con quel ruolo e salva data e versione del consenso. Senza un ruolo valido **o senza il consenso** la registrazione fallisce anche se si aggira l'app (GDPR art. 9).
3. Il trigger `profili_ruolo_immutabile` impedisce di cambiare il ruolo dopo la creazione, anche dal pannello: per un ruolo diverso serve un nuovo account.
4. L'app legge il ruolo da `profili` dopo il login e apre la home corrispondente (UC_GA_2, passo 5).

## 6. Pausa del piano gratuito (RNF_I_6)

Il progetto Free **va in pausa dopo 7 giorni senza attività**. In pausa l'app non riesce ad accedere e mostra un errore di connessione.

- Per riattivarlo: dashboard → progetto → **Restore project** (o *Resume*). Servono alcuni minuti.
- **Prima della demo**: riattiva il progetto almeno il giorno prima, rigenera i dati di prova (`docs/demo-dati.md`) e prova login, check-in e dashboard dal telefono.
- Per non andare in pausa durante lo sviluppo basta usare l'app o la dashboard almeno una volta a settimana.

## 7. Controlli di sicurezza

- **Advisors → Security Advisor**: dopo ogni migrazione non deve segnalare tabelle senza RLS.
- I test delle policy sono in `supabase/tests/rls.sql`, con l'esito in `docs/test-rls.md`.
