# 3.2 Requisiti funzionali (Functional requirements)

I requisiti sono identificati dalla forma RF_[GRUPPO]_[NUMERO] e sono divisi in tre tabelle: requisiti **comuni** a Nutrizionista e Paziente, requisiti **lato Nutrizionista** e requisiti **lato Paziente**. Il codice del gruppo indica la funzionalità (vedi §1.4). Priorità: **A** = Alta (indispensabile), **M** = Media (prevista nell'MVP, dopo le A), **B** = Bassa (sviluppo futuro). Le funzionalità A e M compongono l'MVP promesso e dimostrato nella live demo; l'agenda è interamente a priorità Alta.

Modello di interazione: il piano è composto dal **nutrizionista** (che imposta gli obiettivi, cerca gli alimenti, calcola quantità e macro, decide le alternative); il **paziente** non ricalcola e non scrive cosa ha mangiato, ma consulta il piano e fa il **check-in** di ogni pasto scegliendo tra opzioni guidate.

## 3.2.1 Requisiti comuni (Nutrizionista e Paziente)

| ID | Nome | Descrizione | Attore | Priorità |
|---|---|---|---|---|
| » Gestione Account (GA) | | | | |
| RF_GA_1 | Registrazione | L'utente crea un account con email e password scegliendo il ruolo; il NUT indica anche giorni e orari di ricevimento e durata della visita (RF_GV_6) | NUT, PAZ | A |
| RF_GA_2 | Accesso | L'utente accede con credenziali; la sessione resta attiva sul dispositivo | NUT, PAZ | A |
| RF_GA_3 | Logout | L'utente esce dall'account | NUT, PAZ | A |
| RF_GA_4 | Recupero password | L'utente richiede il reset via email | NUT, PAZ | M |
| RF_GA_5 | Modifica profilo | L'utente modifica i dati del proprio profilo (per il paziente: altezza, data di nascita, obiettivo; per il NUT: disponibilità, RF_GV_6) | NUT, PAZ | A |
| RF_GA_6 | Consenso al trattamento dati | Alla registrazione l'utente accetta informativa e consenso esplicito al trattamento dei dati sanitari | NUT, PAZ | A |
| RF_GA_7 | Eliminazione account | L'utente richiede la cancellazione del proprio account e dei dati | NUT, PAZ | M |
| RF_GA_8 | Esportazione dei dati | L'utente richiede una copia dei propri dati personali in formato leggibile (portabilità, GDPR) | NUT, PAZ | B |
| » Gestione Piano (GP) | | | | |
| RF_GP_16 | Obiettivi nutrizionali | Prima di creare il piano il NUT imposta per il paziente gli obiettivi giornalieri (kcal, proteine, carboidrati, grassi); l'editor mostra per ogni giorno lo scostamento tra i totali del piano e gli obiettivi; gli obiettivi sono visibili al PAZ | NUT, PAZ | A |
| » Gestione Misure e Andamento (GM) | | | | |
| RF_GM_1 | Registrazione peso | Il PAZ (o il NUT durante la visita) registra il peso con data | PAZ, NUT | A |
| RF_GM_2 | Grafico di andamento | Il PAZ e il NUT vedono i grafici di peso e di aderenza nel tempo | PAZ, NUT | A |
| » Gestione Notifiche (GN) | | | | |
| RF_GN_5 | Avvisi sulle visite | Il PAZ è avvisato quando il NUT fissa, sposta o annulla una visita e quando si apre la sua finestra di prenotazione; il NUT è avvisato quando un PAZ prenota o annulla | NUT, PAZ | A |

## 3.2.2 Requisiti lato Nutrizionista

| ID | Nome | Descrizione | Attore | Priorità |
|---|---|---|---|---|
| » Gestione Inviti e Pazienti (GI) | | | | |
| RF_GI_1 | Creazione invito | Il NUT genera un invito (codice o link) per un nuovo paziente; il sistema verifica prima il limite del piano e, se raggiunto, blocca l'invito e mostra un errore (RF_GAD_7) | NUT | A |
| RF_GI_3 | Elenco pazienti | Il NUT visualizza i propri pazienti | NUT | A |
| RF_GI_4 | Archiviazione | Il NUT archivia un paziente; **un paziente collegato non può essere eliminato**. Nei piani Start e Pro l'archiviazione libera un posto, nel Free no | NUT | A |
| RF_GI_5 | Riattivazione | Il NUT riattiva un paziente archiviato, se il limite del piano lo consente | NUT | M |
| RF_GI_6 | Stati e filtro | Ogni paziente ha stato Invitato, Attivo o Archiviato; la dashboard filtra Attivi / Archiviati / Tutti, ordina per semaforo e cerca per nome | NUT | A |
| RF_GI_8 | Revoca invito | Il NUT revoca un invito non ancora utilizzato; il codice non è più valido | NUT | M |
| » Gestione Piano (GP) | | | | |
| RF_GP_1 | Creazione piano | Il NUT crea un piano per un paziente, dopo averne impostato gli obiettivi nutrizionali (RF_GP_16), scegliendo i giorni e i pasti previsti (colazione, spuntini, pranzo, cena) | NUT | A |
| RF_GP_2 | Composizione del pasto | Il NUT compone ogni pasto con alimenti e quantità; il sistema calcola automaticamente kcal e macronutrienti del pasto e del giorno | NUT | A |
| RF_GP_3 | Ricerca alimento | Il NUT cerca un alimento per nome; gli alimenti già usati sono salvati in una cache (`alimenti`) con indicazione della fonte | NUT | A |
| RF_GP_4 | Scansione barcode | Il NUT inquadra il codice a barre di un prodotto per ottenerne i valori nutrizionali | NUT | M |
| RF_GP_5 | Alimento personalizzato | Il NUT inserisce manualmente un alimento non trovato, con i suoi valori | NUT | M |
| RF_GP_6 | Alternative equivalenti | Il NUT indica per una voce una o più alternative ammesse; sono le uniche scelte offerte al paziente nel check-in "Alternativa" | NUT | A |
| RF_GP_7 | Modifica piano | Il NUT aggiorna un piano; il sistema conserva le versioni e il paziente vede quella corrente | NUT | A |
| RF_GP_9 | Piani modello e pasti salvati | Il NUT salva un pasto o un piano come modello e lo riutilizza per altri pazienti | NUT | A |
| RF_GP_10 | Modello CSV scaricabile | Il NUT scarica un file modello (CSV) con le colonne richieste per importare un piano | NUT | A |
| RF_GP_11 | Importazione da CSV | Il NUT importa un piano da file CSV: il sistema mostra un'anteprima, elenca righe ed errori, abbina gli alimenti e crea il piano dopo conferma | NUT | A |
| RF_GP_12 | Importazione da .xlsx | Importazione diretta di file Excel (nell'MVP si usa il CSV esportato da Excel) | NUT | B |
| RF_GP_13 | Copia del giorno | Il NUT compone un giorno tipo e lo copia su altri giorni della settimana | NUT | A |
| RF_GP_14 | Alimenti recenti e preferiti | L'editor propone gli alimenti usati di recente o segnati come preferiti | NUT | M |
| RF_GP_15 | Quantità rapide | L'editor propone quantità tipiche (es. 50, 100, 150 g) per inserire una voce con pochi tocchi | NUT | M |
| » Gestione Misure e Andamento (GM) | | | | |
| RF_GM_3 | Misure aggiuntive | Il NUT registra altre misure alla visita (es. circonferenze) | NUT | B |
| RF_GM_5 | Aderenza per pasto | Il NUT vede la percentuale di aderenza per tipo di pasto e per giorno della settimana (con un numero minimo di check-in [DA CONFERMARE]) per capire quali pasti il paziente salta o sostituisce e adattare il piano | NUT | A |
| » Gestione Notifiche (GN) | | | | |
| RF_GN_3 | Notifica al NUT | Il NUT riceve una notifica se un paziente non fa check-in per più giorni | NUT | M |
| » Gestione Commenti (GC) | | | | |
| RF_GC_1 | Commento al check-in | Il NUT scrive un commento su un check-in del paziente | NUT | A |
| » Gestione Visite: agenda, disponibilità e prenotazioni (GV) | | | | |
| RF_GV_1 | Fissare una visita | Il NUT fissa una visita scegliendo cliente, data e ora (di norma uno slot libero) | NUT | A |
| RF_GV_2 | Calendario | Il NUT vede le visite e gli slot liberi in un calendario settimanale e mensile e può selezionare il cliente | NUT | A |
| RF_GV_3 | Prossima e ultima visita | La scheda del cliente mostra la prossima e l'ultima visita | NUT | A |
| RF_GV_4 | Modifica e annullamento | Il NUT sposta o annulla una visita | NUT | A |
| RF_GV_6 | Disponibilità settimanale | Il NUT indica (alla registrazione e poi dal profilo) giorni e fasce orarie in cui riceve e la durata della visita; il sistema ne ricava gli slot; modificare la disponibilità non sposta le visite già fissate | NUT | A |
| RF_GV_7 | Finestra di prenotazione | Per ogni paziente il NUT indica il periodo in cui può prenotare la prossima visita (di norma circa un mese dopo l'ultima) [DA CONFERMARE] | NUT | A |
| RF_GV_10 | Giorni non disponibili | Il NUT segna giorni o periodi non disponibili (ferie) che nascondono gli slot | NUT | B |
| » Aderenza, Dashboard e Abbonamento (GAD) | | | | |
| RF_GAD_1 | Calcolo aderenza | Il sistema calcola lo stato di aderenza del paziente dai suoi check-in | Sistema | A |
| RF_GAD_2 | Dashboard con semaforo | Il NUT vede per ogni paziente lo stato (verde, giallo, rosso), la data dell'ultimo check-in e la prossima visita | NUT | A |
| RF_GAD_3 | Dettaglio paziente | Il NUT apre i check-in, il peso, i commenti, il piano e le visite di un paziente | NUT | A |
| RF_GAD_4 | Piano di abbonamento e limiti | Il NUT ha un piano (Free: 1 paziente a vita; Start: fino a 5 attivi; Pro: illimitati); il sistema applica i limiti agli inviti (vedi condizioni limite) | NUT, Sistema | A |
| RF_GAD_5 | Cambio piano simulato | Il NUT passa a Start o Pro, con scelta mensile o annuale; il pagamento è **simulato** e marcato come tale | NUT | M |
| RF_GAD_6 | Spazio sponsor | Nel piano Free la dashboard del NUT mostra una scheda sponsor statica; scompare con Start e Pro; non è mai mostrata al paziente | NUT, Sistema | M |
| RF_GAD_7 | Errore al limite del piano | Se il limite del piano è raggiunto, il sistema blocca la creazione dell'invito e mostra un errore con il motivo, le opzioni di cambio piano e, nei piani Start e Pro, l'archiviazione | NUT, Sistema | A |

## 3.2.3 Requisiti lato Paziente

| ID | Nome | Descrizione | Attore | Priorità |
|---|---|---|---|---|
| » Gestione Inviti e Pazienti (GI) | | | | |
| RF_GI_2 | Accettazione invito | Il PAZ inserisce il codice e si collega al NUT | PAZ | A |
| RF_GI_7 | Scollegamento da parte del paziente | Il PAZ interrompe il collegamento con il NUT; il paziente passa ad Archiviato e il Free lo conta comunque | PAZ | M |
| » Gestione Piano (GP) | | | | |
| RF_GP_8 | Consultazione piano | Il PAZ consulta nella sezione Dieta il piano, pasto per pasto, con alimenti, quantità, alternative e obiettivi nutrizionali | PAZ | A |
| » Gestione Check-in dei pasti (GD) | | | | |
| RF_GD_1 | Check-in del pasto | Il PAZ segna ogni pasto previsto con uno di quattro stati: **Seguito, Alternativa, Fuori piano, Saltato** | PAZ | A |
| RF_GD_2 | Scelta dell'alternativa | Con "Alternativa" il PAZ sceglie una tra quelle previste dal NUT per il pasto; non scrive testo libero | PAZ | A |
| RF_GD_3 | Correzione del check-in | Il PAZ corregge un check-in entro il giorno successivo [DA CONFERMARE] | PAZ | A |
| RF_GD_4 | Riepilogo giornaliero | Il PAZ vede lo stato dei pasti del giorno e l'obiettivo del piano | PAZ | A |
| RF_GD_5 | Foto del pasto | Il PAZ può allegare una foto al check-in | PAZ | B |
| RF_GD_6 | Pasto extra | Il PAZ segnala un pasto non previsto dal piano; non modifica l'indice di aderenza [DA CONFERMARE] | PAZ | M |
| RF_GD_7 | Etichette rapide per Fuori piano | Con "Fuori piano" il PAZ sceglie un'etichetta rapida (es. pizza, ristorante, dolce) oppure scrive una nota breve | PAZ | M |
| RF_GD_8 | Storico dei check-in | Il PAZ rivede i check-in dei giorni passati e i commenti ricevuti | PAZ | M |
| » Gestione Misure e Andamento (GM) | | | | |
| RF_GM_4 | Riepilogo dell'andamento | Nella sezione Andamento il PAZ vede il peso attuale e la variazione dall'inizio, l'aderenza dell'ultima settimana rispetto alla precedente e gli ultimi commenti del NUT | PAZ | A |
| » Gestione Notifiche (GN) | | | | |
| RF_GN_1 | Promemoria check-in | Il PAZ riceve notifiche per fare il check-in dei pasti agli orari previsti | PAZ | A |
| RF_GN_2 | Impostazione promemoria | Il PAZ attiva o disattiva i promemoria | PAZ | M |
| RF_GN_4 | Promemoria visita | Il PAZ riceve una notifica prima di una visita fissata | PAZ | A |
| RF_GN_6 | Notifica di commento e di nuovo piano | Il PAZ riceve una notifica quando il NUT commenta un check-in o assegna una nuova versione del piano | PAZ | M |
| » Gestione Commenti (GC) | | | | |
| RF_GC_2 | Lettura commenti | Il PAZ legge i commenti del NUT | PAZ | A |
| » Gestione Visite: agenda, disponibilità e prenotazioni (GV) | | | | |
| RF_GV_5 | Visita visibile al paziente | Il PAZ vede in app la prossima visita | PAZ | A |
| RF_GV_8 | Prenotazione da parte del paziente | Il PAZ vede gli slot liberi nella propria finestra e prenota; la visita è confermata subito, senza approvazione, se lo slot è ancora libero; un solo appuntamento futuro per paziente | PAZ | A |
| RF_GV_9 | Annullamento da parte del paziente | Il PAZ annulla o sposta la propria visita fino a 24 ore prima [DA CONFERMARE]; lo slot torna libero | PAZ | A |

**Regola di aderenza (proposta, [DA CONFERMARE] con il consulente nutrizionista):** per ogni pasto previsto, il check-in vale **1 punto** se *Seguito*, **1 punto** se *Alternativa* (era una scelta approvata dal nutrizionista), **0,5** se *Fuori piano*, **0** se *Saltato*; un pasto senza check-in vale 0. I pasti extra (RF_GD_6) non modificano l'indice. L'indice giornaliero è la somma dei punti divisa per il numero di pasti previsti. Il **semaforo** si basa sulla media degli ultimi 3 giorni: verde ≥ 0,8; giallo tra 0,4 e 0,8; rosso < 0,4. La dashboard mostra anche la data dell'ultimo check-in, per distinguere "salta i pasti" da "non usa l'app". È un **indicatore di attenzione**, non una misura clinica.
