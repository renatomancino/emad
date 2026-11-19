# 1. Introduzione (Introduction)

## 1.1 Scopo del sistema (Purpose of the system)

Cenato è un'applicazione mobile multipiattaforma (Flutter) che collega **nutrizionisti/dietisti** e **pazienti** e li accompagna tra una visita e l'altra.

Il **nutrizionista** usa Cenato per:

- stabilire per ogni paziente gli **obiettivi nutrizionali** (kcal e macronutrienti: proteine, carboidrati, grassi) e costruire il piano alimentare nel rispetto di tali obiettivi;
- vedere come il paziente sta seguendo il piano (check-in dei pasti, peso, andamento) e commentare; con molti pazienti, il **semaforo di aderenza** gli mostra subito chi ha bisogno di attenzione, senza aprire ogni scheda;
- gestire i propri clienti, attivi e archiviati;
- gestire la propria **agenda**: al momento della registrazione indica i giorni e gli orari in cui riceve e la durata della visita; il calendario mostra le visite fissate e gli slot ancora liberi. Il nutrizionista può fissare una visita e il paziente viene avvisato nell'app.

Il **paziente** usa Cenato in quattro sezioni:

- **Oggi:** i pasti del giorno; conferma ogni pasto con un tap (check-in) e riceve i promemoria;
- **Dieta:** il piano alimentare con alimenti, quantità e alternative, e gli obiettivi nutrizionali stabiliti dal professionista;
- **Andamento:** peso e grafici, aderenza dell'ultima settimana, commenti del nutrizionista: il paziente vede se sta migliorando;
- **Visite:** la prossima visita; il paziente può **prenotarla** scegliendo tra gli slot liberi nel periodo indicato dal nutrizionista (di solito circa un mese dopo l'ultima visita) e può annullarla entro un termine.

Il problema di partenza: nutrizionisti e dietisti seguono i pazienti con piani statici (PDF/Excel), WhatsApp e diari cartacei. Tra una visita e l'altra non vedono se il paziente segue il piano e gestiscono clienti e appuntamenti con strumenti sparsi; il paziente non riceve feedback. Le app consumer (Yazio, MyFitnessPal, Lifesum) tracciano i pasti ma non prevedono il professionista; i gestionali per professionisti coprono agenda e fatturazione ma sono meno focalizzati sull'aderenza quotidiana.

**Che vantaggio ha il paziente dal check-in.** Confermare un pasto costa un tap; in cambio il paziente ottiene promemoria al momento giusto, un riscontro visibile sul proprio percorso (sezione Andamento) e un professionista che vede i dati e può commentare, correggere il piano e intervenire prima della visita successiva, invece di scoprire i problemi dopo un mese. Il vantaggio principale è del professionista, che è anche il cliente pagante; per il paziente il check-in ha senso solo se riceve questi riscontri, per questo sono requisiti del sistema (RF_GM_4, RF_GC_2, RF_GN_1).

Il sistema si propone di:

- ridurre il tempo che il professionista dedica a inseguire diari su canali non strutturati;
- permettere al professionista di intervenire tra una visita e l'altra, grazie al monitoraggio dell'aderenza;
- far costruire piani coerenti con gli obiettivi nutrizionali in modo rapido, anche da smartphone (ricerca alimenti, barcode, giorno tipo, pasti salvati, importazione da file);
- offrire al professionista una gestione essenziale di clienti (attivi e archiviati) e di agenda, con prenotazione delle visite da parte del paziente;
- rendere semplice e motivante per il paziente seguire il piano, con un check-in dei pasti in pochi secondi e un riscontro chiaro sul proprio andamento.

## 1.2 Ambito del sistema (Scope of the system)

Cenato è una piattaforma **B2B2C** (business-to-business-to-consumer): Cenato vende l'abbonamento al professionista (il *business*), che porta i propri pazienti (i *consumatori finali*); i pazienti usano l'app gratuitamente, su invito. Il modello di business è descritto nel documento BMC. Funzionalità principali dell'MVP:

- registrazione e accesso con ruoli distinti (Nutrizionista, Paziente); per il nutrizionista, indicazione di giorni e orari di ricevimento e della durata della visita;
- collegamento professionista–paziente tramite invito, con **limiti dipendenti dal piano di abbonamento** (Free, Start, Pro);
- gestione dei pazienti con stati Invitato, Attivo, Archiviato (i pazienti **non si eliminano, si archiviano**);
- **obiettivi nutrizionali** per paziente (kcal e macro), impostati prima del piano;
- creazione e assegnazione del piano alimentare, con kcal e macro calcolati automaticamente e confrontati con gli obiettivi, ricerca alimenti e barcode, giorno tipo con copia, pasti salvati, piani modello e **importazione da file CSV**;
- check-in dei pasti a quattro stati (Seguito, Alternativa, Fuori piano, Saltato);
- registrazione del peso e sezione **Andamento** per il paziente (peso, aderenza, commenti);
- promemoria tramite notifiche;
- dashboard del professionista con semaforo di aderenza, filtro Attivi/Archiviati/Tutti e commenti sui pasti;
- **agenda con prenotazioni:** disponibilità del nutrizionista, calendario con visite e slot liberi, visita fissata dal nutrizionista o prenotata dal paziente, avvisi in app, prossima e ultima visita nella scheda cliente;
- piano di abbonamento con pagamento simulato e spazio sponsor nel piano Free.

**Fuori ambito (sviluppi futuri, vedi BMC §7):** versione web, fatturazione e Sistema Tessera Sanitaria, pagamenti reali, videochiamate, sincronizzazione con Google Calendar, prenotazioni a pagamento, liste d'attesa e visite ricorrenti automatiche, tracciamento libero di calorie e macro da parte del paziente (Cenato non è un contacalorie), riconoscimento dei piatti da foto, importazione con IA, wearable, piano Studio, marketplace.

## 1.3 Obiettivi e criteri di successo (Objectives and success criteria)

Criteri misurabili, da verificare nella live demo:

- **Completezza:** tutte le funzionalità a priorità Alta (A) e Media (M) previste (§3.2) sono implementate e dimostrabili su smartphone; ciò che non è dimostrabile non viene promesso.
- **Rapidità:** il paziente completa il check-in di un pasto in non più di 3 tap.
- **Visibilità:** il professionista vede lo stato di aderenza di tutti i suoi pazienti in una sola schermata.
- **Obiettivi nutrizionali:** nell'editor il professionista vede lo scostamento tra i totali del piano e gli obiettivi del paziente; il paziente vede gli obiettivi nella sezione Dieta.
- **Agenda:** il paziente prenota uno slot libero, il nutrizionista lo vede nel calendario ed è avvisato; il nutrizionista può fissare una visita e il paziente è avvisato; due pazienti non possono occupare lo stesso slot.
- **Sicurezza:** un utente non legge mai i dati di pazienti non collegati a lui (verificato con test sulle policy di accesso).
- **Coerenza del modello:** i limiti dei piani di abbonamento sono applicati davvero dall'app (Free: 1 paziente a vita; Start: 5 attivi; Pro: illimitati).
- **Scadenza:** consegna prevista entro gennaio 2027; la data definitiva dipende dall'appello scelto [DA CONFERMARE].

## 1.4 Definizioni, acronimi, abbreviazioni (Definitions)

- **RAD**: Requirements Analysis Document. **BMC**: Business Model Canvas (documento separato). **BC**: Business Case (documento separato). **MVP**: Minimum Viable Product.
- **S1 / S2**: segmento di clientela 1 (nutrizionisti) / 2 (pazienti), come definiti nel BMC.
- **NUT**: Nutrizionista (ruolo che comprende biologo nutrizionista, dietista, medico dietologo). **PAZ**: Paziente.
- **RF / RNF**: requisito funzionale / non funzionale. **SC**: scenario. **UC**: use case. **UCD**: Use Case Diagram. **CD**: Class Diagram. **SD**: Sequence Diagram. **SCD**: StateChart Diagram. **NP**: Navigation Path. **UI**: User Interface.
- **FURPS+**: Functionality, Usability, Reliability, Performance, Supportability, più vincoli (Implementazione, Interfacce, Packaging, Legali). I vincoli di operazione sono riportati tra quelli di implementazione.
- **Gruppi di requisiti funzionali:** GA Gestione Account; GI Gestione Inviti e Pazienti; GP Gestione Piano; GD Gestione Check-in dei pasti; GM Gestione Misure; GN Gestione Notifiche; GC Gestione Commenti; GV Gestione Visite (agenda, disponibilità e prenotazioni); GAD Gestione Aderenza, Dashboard e Abbonamento.
- **Priorità:** A = Alta (indispensabile), M = Media (prevista nell'MVP, da realizzare dopo le funzioni A), B = Bassa (sviluppo futuro).

## 1.5 Riferimenti (References)

- Slide del corso Enterprise Mobile Application Development (L0–L6), Dott. S. Nocera, Università degli Studi di Salerno.
- **Business Model Canvas** di Cenato: EMAD_Cenato_BMC_V0.2.0 (segmenti, Value Proposition Canvas, nove blocchi, motivazioni dalla teoria).
- **Business Case** di Cenato: EMAD_Cenato_BC_V0.2.0 (mercato, ricavi, costi, scenari, rischi).
- **Registro delle decisioni** di Cenato: EMAD_Cenato_Registro_V0.2.0 (decisioni, back-end, nome, punti aperti).
- Bruegge, B., Dutoit, A. H., *Object-Oriented Software Engineering: Using UML, Patterns and Java*, Prentice Hall, 2010.
- RAD del progetto Esistere (team C04, 2023), usato come modello di struttura del documento.
- Regolamento (UE) 2016/679 (GDPR), art. 9 (categorie particolari di dati personali).
- Open Food Facts, licenza ODbL (attribuzione e condivisione allo stesso modo).

## 1.6 Panoramica del documento (Overview)

Il documento segue la struttura del Requirements Analysis Document di Bruegge e Dutoit. Il capitolo 1 introduce scopo, ambito e obiettivi del sistema. Il capitolo 2 descrive come il problema è affrontato oggi. Il capitolo 3 descrive il **sistema proposto**: panoramica (3.1), requisiti funzionali (3.2), requisiti non funzionali (3.3) e modelli di sistema (3.4: scenari, casi d'uso, modello a oggetti, modello dinamico, percorsi di navigazione e mock-up). Il capitolo 4 è il glossario.

Questo RAD si occupa di **che cosa** deve fare il sistema. Il **perché** economico e le scelte di mercato sono in tre documenti separati e allineati con questo: il Business Model Canvas (EMAD_Cenato_BMC_V0.2.0), il Business Case (EMAD_Cenato_BC_V0.2.0) e il Registro delle decisioni (EMAD_Cenato_Registro_V0.2.0).
