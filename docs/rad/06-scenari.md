# 3.4.1 Scenari (Scenarios)

Gli scenari descrivono istanze concrete di utilizzo con personaggi di fantasia: la Dott.ssa Giulia (nutrizionista NUT) e i pazienti Marco, Sara, Luca e Paolo (PAZ). Ogni scenario è una tabella con il flusso degli eventi tra attore e sistema.

**SC_GA_1** — RegistrazioneNutrizionista

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | La Dott.ssa Giulia è una biologa nutrizionista che segue una trentina di pazienti con PDF e WhatsApp. Ha sentito parlare di Cenato, scarica l'app e sceglie "Registrati" con il ruolo Nutrizionista. | |
| 2 | | Il sistema mostra il modulo di registrazione (nome, email, password) e l'informativa sul trattamento dei dati sanitari. |
| 3 | Giulia compila il modulo, legge l'informativa, accetta il consenso e conferma. | |
| 4 | | Il sistema crea l'account, assegna il piano Free e chiede di indicare giorni, orari di ricevimento e durata della visita (SC_GV_3). |
| 5 | Giulia completa il passaggio e raggiunge la dashboard dei pazienti. | |
| 6 | | Il sistema mostra la dashboard vuota con il pulsante "Invita un paziente" e la scheda sponsor del piano Free. |


**SC_GI_1** — InvitoPaziente

**Attori:** NUT: Giulia; PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia ha una nuova paziente in studio e vuole che Marco usi Cenato. Apre la sezione Pazienti e sceglie "Invita". | |
| 2 | | Il sistema controlla il limite del piano di Giulia (ha ancora posti), genera un codice valido 7 giorni [DA CONFERMARE] e un link condivisibile. |
| 3 | Giulia invia il codice a Marco su WhatsApp. | |
| 4 | Marco scarica l'app, sceglie il ruolo Paziente e inserisce il codice. | |
| 5 | | Il sistema verifica il codice e mostra informativa e consenso. |
| 6 | Marco li accetta e crea l'account. | |
| 7 | | Il sistema collega Marco a Giulia e mostra a Giulia Marco nell'elenco pazienti con stato Attivo. |


**SC_GI_2** — ArchiviazionePaziente

**Attori:** NUT: Giulia; PAZ: Luca

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia ha il piano Start (5 pazienti attivi) e li ha tutti occupati. Luca ha finito il percorso: Giulia apre il suo profilo e sceglie "Archivia". | |
| 2 | | Il sistema chiede conferma e spiega che Luca non verrà eliminato e che lo storico resta consultabile. |
| 3 | Giulia conferma. | |
| 4 | | Il sistema imposta Luca come Archiviato e libera un posto: Giulia può invitare un nuovo paziente. Con il piano Free l'archiviazione non avrebbe liberato il posto, perché il Free conta tutti i pazienti che hanno accettato un invito. |


**SC_GAD_2** — LimiteDelPiano

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia è sul piano Free e ha già collegato Marco. Prova a invitare un secondo paziente toccando "Invita". | |
| 2 | | Il sistema blocca l'invito e mostra un messaggio di errore: "Hai raggiunto il limite del piano Free (1 paziente)". Propone Start (12 €/mese o 120 €/anno) e Pro (25 €/mese o 250 €/anno) oppure di archiviare un paziente (solo nei piani Start e Pro). |
| 3 | Giulia sceglie Start annuale e tocca "Passa a Start". | |
| 4 | | Il sistema mostra la finestra di pagamento, chiaramente indicata come simulata. |
| 5 | Giulia conferma. | |
| 6 | | Il sistema aggiorna il piano e i limiti, rimuove la scheda sponsor dalla dashboard e consente di invitare altri pazienti fino a 5 attivi. |


**SC_GP_4** — ImpostazioneObiettivi

**Attori:** NUT: Giulia; PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia ha appena collegato Marco. Prima di comporre il piano apre il suo profilo e sceglie "Obiettivi". | |
| 2 | | Il sistema mostra il modulo con kcal giornaliere, proteine, carboidrati e grassi. |
| 3 | Giulia inserisce 2.000 kcal, 110 g di proteine, 230 g di carboidrati e 65 g di grassi e salva. | |
| 4 | | Il sistema salva gli obiettivi, li userà nell'editor come riferimento (scostamento) e li mostrerà a Marco nella sezione Dieta. |


**SC_GP_1** — CreazionePiano

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia apre il profilo di Marco e sceglie "Nuovo piano". Seleziona i giorni e i pasti previsti. | |
| 2 | | Il sistema mostra l'editor con i pasti del primo giorno e gli obiettivi di Marco. |
| 3 | Per il lunedì cerca "latte parzialmente scremato" e lo aggiunge con 200 ml scegliendo una quantità rapida, poi aggiunge i cereali con 40 g. | |
| 4 | | Il sistema mostra subito kcal e macro del pasto e della giornata. |
| 5 | Giulia indica un'alternativa ammessa per i cereali (fette biscottate), salva il pasto tra i pasti salvati e copia il lunedì su martedì, mercoledì e giovedì. | |
| 6 | | Il sistema duplica il giorno e mostra lo scostamento dagli obiettivi: la giornata è a +60 kcal. |
| 7 | Giulia lascia il piano così, lo salva e lo assegna. | |
| 8 | | Il sistema registra la versione del piano e notifica Marco. |


**SC_GP_2** — ComposizioneConBarcode

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Marco mangia spesso un certo yogurt e Giulia vuole inserirlo nel piano. Nell'editor tocca "Scansiona" e inquadra il codice a barre. | |
| 2 | | Il sistema recupera il prodotto da Open Food Facts e mostra i valori nutrizionali per 100 g. |
| 3 | Giulia indica 125 g e lo aggiunge allo spuntino. | |
| 4 | | Il sistema aggiorna kcal e macro dello spuntino e della giornata. |
| 5 | Per un altro prodotto il codice non viene trovato: Giulia sceglie "Inserisci manualmente" e digita i valori letti sull'etichetta. | |
| 6 | | Il sistema salva l'alimento personalizzato e lo aggiunge al pasto. |


**SC_GP_3** — ImportazioneDaFile

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia ha già i piani dei suoi pazienti in Excel. Dalla sezione Piani sceglie "Importa da file". | |
| 2 | | Il sistema offre il download del modello CSV. |
| 3 | Giulia scarica il modello, lo compila al computer con un piano settimanale, lo esporta in CSV e lo carica dal telefono. | |
| 4 | | Il sistema mostra l'anteprima: 27 righe riconosciute, 2 alimenti da abbinare e 1 riga con quantità non valida. |
| 5 | Giulia abbina i due alimenti, corregge il file e lo ricarica. | |
| 6 | | Il sistema mostra l'anteprima senza errori. |
| 7 | Giulia conferma. | |
| 8 | | Il sistema crea il piano come bozza da rivedere e assegnare. |


**SC_GD_1** — CheckInSeguito

**Attori:** PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Alle 13:30 Marco riceve il promemoria e apre Cenato. | |
| 2 | | Il sistema mostra la schermata "Oggi" con il pranzo previsto, alimenti e quantità. |
| 3 | Marco ha mangiato esattamente quello e tocca "Seguito". | |
| 4 | | Il sistema salva il check-in e aggiorna lo stato del giorno: 3 pasti su 4 completati. |


**SC_GD_2** — CheckInAlternativa

**Attori:** PAZ: Sara

| # | Attore | Sistema |
|---|---|---|
| 1 | Per colazione il piano prevede cereali, ma Sara ha mangiato fette biscottate. Apre la colazione e tocca "Alternativa". | |
| 2 | | Il sistema mostra le alternative decise da Giulia per quel pasto. |
| 3 | Sara sceglie "fette biscottate" con un tap, senza scrivere nulla. | |
| 4 | | Il sistema salva il check-in come pasto seguito con l'alternativa scelta; Giulia vedrà quale alternativa è stata usata. |


**SC_GD_3** — CheckInFuoriPiano

**Attori:** PAZ: Sara

| # | Attore | Sistema |
|---|---|---|
| 1 | A cena Sara è uscita con gli amici e ha mangiato una pizza. Apre la cena e tocca "Fuori piano". | |
| 2 | | Il sistema mostra le etichette rapide (pizza, ristorante, dolce…) e un campo nota facoltativo. |
| 3 | Sara sceglie l'etichetta "pizza" e conferma. | |
| 4 | | Il sistema registra il check-in (0,5 punti) e aggiorna lo stato del giorno. |
| 5 | Più tardi Sara segnala uno spuntino non previsto con "Pasto extra". | |
| 6 | | Il sistema registra il pasto extra: non cambia l'indice di aderenza ma sarà visibile a Giulia. |


**SC_GM_1** — RegistrazionePeso

**Attori:** PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Ogni lunedì Marco apre la sezione Andamento e sceglie "Aggiungi peso". | |
| 2 | | Il sistema mostra il campo del peso con la data di oggi. |
| 3 | Marco inserisce 82,4 kg e salva. | |
| 4 | | Il sistema salva il valore e aggiorna il grafico dell'andamento rispetto alle settimane precedenti. |


**SC_GM_2** — ConsultazioneAndamento

**Attori:** PAZ: Sara

| # | Attore | Sistema |
|---|---|---|
| 1 | Dopo tre settimane Sara apre la sezione Andamento. | |
| 2 | | Il sistema mostra il peso sceso di 1,8 kg dall'inizio, l'aderenza di questa settimana più alta della precedente e l'ultimo commento di Giulia. |
| 3 | Sara capisce che sta andando nella direzione giusta e apre il grafico per vedere dove può ancora migliorare. | |
| 4 | | Il sistema mostra i grafici di peso e di aderenza nel tempo. |


**SC_GM_3** — AderenzaPerPasto

**Attori:** NUT: Giulia; PAZ: Sara

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia apre il dettaglio di Sara e sceglie la vista "Aderenza per pasto". | |
| 2 | | Il sistema mostra la percentuale di aderenza per colazione, spuntino mattutino, pranzo, merenda e cena, e per giorno della settimana. |
| 3 | Giulia nota che lo spuntino del mattino è saltato nell'80% dei casi e che il weekend è il momento più debole. | |
| 4 | | Il sistema indica che i dati sono sufficienti (almeno 7 check-in per pasto [DA CONFERMARE]). |
| 5 | Giulia decide di spostare gli alimenti dello spuntino negli altri pasti e apre l'editor del piano. | |
| 6 | | Il sistema mostra l'editor con lo scostamento dagli obiettivi, utile per verificare che i totali restino coerenti dopo lo spostamento. |


**SC_GAD_1** — MonitoraggioAderenza

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia apre l'elenco pazienti (filtro "Attivi"). | |
| 2 | | Il sistema mostra il semaforo di ciascuno: Marco è verde, Sara gialla, un terzo paziente è rosso (nessun check-in da 3 giorni, ultimo check-in di 4 giorni fa). |
| 3 | Giulia ordina per semaforo e apre il dettaglio del paziente rosso. | |
| 4 | | Il sistema mostra i pasti saltati, il peso fermo e il piano. |
| 5 | Giulia decide di scrivergli un commento e di fissare una visita. | |


**SC_GC_1** — CommentoCheckIn

**Attori:** NUT: Giulia; PAZ: Sara

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia apre il dettaglio di Sara e legge il check-in "Fuori piano" della cena. | |
| 2 | Scrive un commento di incoraggiamento con un consiglio per le prossime uscite e lo invia. | |
| 3 | | Il sistema salva il commento e invia una notifica a Sara. |
| 4 | Sara apre l'app e legge il commento nella sezione Andamento. | |


**SC_GN_1** — PromemoriaCheckIn

**Attori:** PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Marco ha attivato i promemoria. | |
| 2 | | Alle 13:30 il sistema invia la notifica "Com'è andato il pranzo?". |
| 3 | Marco tocca la notifica. | |
| 4 | | L'app si apre direttamente sul check-in del pranzo. |


**SC_GV_1** — FissareUnaVisita

**Attori:** NUT: Giulia; PAZ: Marco

| # | Attore | Sistema |
|---|---|---|
| 1 | Giulia apre il calendario settimanale. | |
| 2 | | Il sistema mostra le visite già fissate e gli slot liberi. |
| 3 | Giulia tocca uno slot libero del giovedì e seleziona il cliente Marco, poi salva. | |
| 4 | | Il sistema aggiorna la scheda di Marco con "Prossima visita: giovedì 14:30" e invia a Marco una notifica; il giorno prima invierà un promemoria. |


**SC_GV_2** — PrenotazioneDaPaziente

**Attori:** PAZ: Sara; NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Alla fine dell'ultima visita Giulia ha indicato per Sara la finestra di prenotazione "dal 1° al 15 del mese prossimo". | |
| 2 | | Quando la finestra si apre, il sistema invia a Sara una notifica. |
| 3 | Sara apre la sezione Visite. | |
| 4 | | Il sistema mostra gli slot liberi dei giorni della finestra. |
| 5 | Sara sceglie martedì alle 17:00 e conferma. | |
| 6 | | Il sistema verifica che lo slot sia ancora libero, registra la visita e la mostra nel calendario di Giulia, che riceve una notifica. |
| 7 | Se un'altra paziente avesse occupato lo slot un attimo prima, Sara avrebbe visto un messaggio di errore. | |
| 8 | | In quel caso il sistema propone gli altri slot ancora liberi. |


**SC_GV_3** — ImpostazioneDisponibilita

**Attori:** NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Durante la registrazione, dopo aver accettato il consenso, Giulia apre il passaggio "Disponibilità". | |
| 2 | | Il sistema mostra i giorni della settimana con fasce orarie e il campo "durata della visita". |
| 3 | Giulia indica che riceve il lunedì e il giovedì dalle 14:00 alle 19:00 e il martedì dalle 9:00 alle 13:00, con visite di 45 minuti. | |
| 4 | | Il sistema genera gli slot e li mostra nel calendario. |
| 5 | Più avanti Giulia modifica gli orari dal profilo. | |
| 6 | | Il sistema aggiorna gli slot futuri; le visite già fissate restano dove sono. |


**SC_GV_4** — AnnullamentoVisitaDaPaziente

**Attori:** PAZ: Marco; NUT: Giulia

| # | Attore | Sistema |
|---|---|---|
| 1 | Marco ha una visita giovedì alle 14:30 ma ha un impegno improvviso. Apre la sezione Visite e tocca "Annulla visita". | |
| 2 | | Il sistema verifica che manchino più di 24 ore [DA CONFERMARE] e chiede conferma. |
| 3 | Marco conferma. | |
| 4 | | Il sistema annulla la visita, libera lo slot, avvisa Giulia e rimuove il promemoria. |
| 5 | Marco tocca "Prenota di nuovo" e sceglie un altro slot nella sua finestra. | |
| 6 | | Il sistema registra la nuova visita (SC_GV_2). |

