# 3.3 Requisiti non funzionali (Nonfunctional requirements)

## 3.3.1 Usabilità (Usability)
- RNF_U_1: il check-in di un pasto richiede al massimo 3 tap.
- RNF_U_2: l'interfaccia è in lingua italiana (inglese: sviluppo futuro).
- RNF_U_3: l'interfaccia rispetta linee guida di accessibilità di base (contrasto adeguato, testo ridimensionabile, aree di tocco di almeno 48 dp).
- RNF_U_4: l'onboarding del paziente (invito, registrazione, consenso) richiede al massimo 3 schermate.
- RNF_U_5: l'editor del piano è utilizzabile da smartphone: giorno tipo con copia, pasti salvati, alimenti recenti e quantità rapide riducono la digitazione (RF_GP_9, 13–15).
- RNF_U_6: la navigazione del paziente è organizzata in quattro sezioni (Oggi, Dieta, Andamento, Visite) raggiungibili con un tocco dalla barra inferiore.

## 3.3.2 Affidabilità (Reliability)
- RNF_A_1: un check-in è considerato registrato solo dopo la conferma di salvataggio dal back-end; in caso di errore l'utente è avvisato e può riprovare.
- RNF_A_2: errori di rete e del servizio alimenti producono messaggi chiari, senza chiusura dell'app.
- RNF_A_3: backup del database secondo le funzioni del provider [DA CONFERMARE in base al piano scelto].
- RNF_A_4: le password non sono mai salvate in chiaro (gestione delegata al servizio di autenticazione).
- RNF_A_5: l'importazione da CSV non crea alcun dato se il file contiene errori bloccanti: l'utente vede l'elenco degli errori e può correggere il file.
- RNF_A_6: una prenotazione è confermata solo se lo slot è ancora libero: due pazienti non possono prenotare lo stesso slot (controllo lato back-end).

## 3.3.3 Prestazioni (Performance)
- RNF_P_1: avvio dell'app in meno di 3 secondi su dispositivo di fascia media.
- RNF_P_2: caricamento della dashboard con 30 pazienti in meno di 2 secondi con connessione 4G.
- RNF_P_3: risposta della ricerca alimenti in meno di 2 secondi.
- RNF_P_4: anteprima di un file CSV con un piano settimanale in meno di 5 secondi [DA CONFERMARE].

## 3.3.4 Manutenibilità (Supportability)
- RNF_S_1: codice organizzato in livelli (presentazione, logica, dati) e commentato dove non banale.
- RNF_S_2: analisi statica (lint) senza errori.
- RNF_S_3: test automatici sulla logica di calcolo dell'aderenza, sui limiti dei piani e sulle policy di accesso.

## 3.3.5 Implementazione (Implementation)
- RNF_I_1: app sviluppata con Flutter/Dart, singola codebase.
- RNF_I_2: back-end cloud con database relazionale e autenticazione (Supabase, regione UE; da confermare con il docente, vedi Registro delle decisioni §2).
- RNF_I_3: repository Git condiviso con revisione del codice tra i due membri.
- RNF_I_4: dati ospitati in una regione UE specifica (Francoforte, Irlanda o Parigi).
- RNF_I_5: chiavi e credenziali del back-end fuori dal repository (file `.env` non versionato, con `.env.example` senza chiavi).
- RNF_I_6: il progetto del back-end in pausa (piano gratuito) va riattivato e testato prima della demo.

## 3.3.6 Interfacce (Interface)
- RNF_IN_1: integrazione con l'API di Open Food Facts per ricerca e barcode, usata nell'editor del piano. Si usa uno `User-Agent` che identifica l'app, si rispettano i limiti di richieste e i risultati scelti sono salvati nella tabella `alimenti` con il campo `fonte`. La ricerca per nome è meno affidabile del barcode.
- RNF_IN_2: notifiche push [DA CONFERMARE: servizio utilizzato].
- RNF_IN_3: uso della fotocamera del dispositivo per la scansione barcode (nutrizionista) e per l'eventuale foto del pasto, con richiesta del permesso.
- RNF_IN_4: formato CSV del piano documentato dal modello scaricabile (RF_GP_10), con separatore e codifica indicati.

## 3.3.7 Packaging
- RNF_PA_1: build Android (APK) installabile per la live demo; build iOS [DA CONFERMARE: richiede macOS].
- RNF_PA_2: consegna in archivio .zip con codice, RAD, BMC, Business Case, pitch e materiali, con i nomi dei componenti.

## 3.3.8 Legali (Legal)
- RNF_L_1: i dati alimentari e le misure del paziente sono dati relativi alla salute (GDPR, art. 9): serve consenso esplicito e informativa.
- RNF_L_2: ogni utente accede solo ai dati a cui ha diritto (NUT: solo i pazienti collegati; PAZ: solo i propri dati).
- RNF_L_3: diritto alla cancellazione dei dati (RF_GA_7) e minimizzazione dei dati raccolti; i dati non sono venduti.
- RNF_L_4: avviso in app: Cenato non fornisce diagnosi né consigli medici e non sostituisce il professionista.
- RNF_L_5: i dati di Open Food Facts sono sotto licenza ODbL: l'app mostra l'attribuzione e rispetta la condivisione allo stesso modo per i dati derivati.
- RNF_L_6: lo spazio sponsor (RF_GAD_6) è statico, solo nella dashboard del nutrizionista Free, senza librerie pubblicitarie di terze parti, senza tracciamento e senza uso di dati sanitari; non è mai mostrato ai pazienti.
- RNF_L_7: i pagamenti reali non sono presenti nell'MVP; prima di un lancio reale vanno verificate le regole degli store sui pagamenti esterni e gli obblighi fiscali.

# 3.4 Modelli di sistema (System models)
