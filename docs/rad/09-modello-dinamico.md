# 3.4.4 Modello dinamico (Dynamic model)

## 3.4.4.1 Sequence Diagram

**SD_1 – Check-in di un pasto (paziente)**

```mermaid
sequenceDiagram
  actor PAZ as Paziente
  participant App as App Cenato
  participant API as Back-end
  participant PUSH as Notifiche push
  PUSH-->>PAZ: Promemoria del pasto
  PAZ->>App: Apre l'app dal promemoria
  App->>API: Richiede il piano di oggi e i check-in
  API-->>App: Pasti previsti con stato
  App-->>PAZ: Schermata Oggi
  PAZ->>App: Seleziona il pasto e tocca Alternativa
  App-->>PAZ: Mostra le alternative del nutrizionista
  PAZ->>App: Sceglie un'alternativa
  App->>API: Salva il check-in
  API->>API: Ricalcola l'aderenza
  API-->>App: Conferma e stato del giorno
  App-->>PAZ: Pasto completato, stato aggiornato
```

**SD_2 – Composizione di un pasto con barcode (nutrizionista)**

```mermaid
sequenceDiagram
  actor NUT as Nutrizionista
  participant App as App Cenato
  participant FOOD as Open Food Facts
  participant API as Back-end
  NUT->>App: Tocca Scansiona nell'editor del piano
  NUT->>App: Inquadra il barcode
  App->>FOOD: Richiede il prodotto
  FOOD-->>App: Dati nutrizionali per 100 g
  App-->>NUT: Mostra l'alimento e chiede la quantità
  NUT->>App: Indica la quantità
  App-->>NUT: Mostra kcal e macro del pasto e del giorno
  NUT->>App: Salva il piano
  App->>API: Salva l'alimento in cache e la nuova versione del piano
  API-->>App: Conferma
  API->>API: Richiede la notifica al paziente
```

**SD_3 – Monitoraggio dell'aderenza e commento**

```mermaid
sequenceDiagram
  actor NUT as Nutrizionista
  participant App as App Cenato
  participant API as Back-end
  participant PUSH as Notifiche push
  NUT->>App: Apre la lista pazienti
  App->>API: Richiede pazienti, stato di aderenza e prossime visite
  API-->>App: Elenco con semaforo e ultimo check-in
  App-->>NUT: Dashboard
  NUT->>App: Seleziona un paziente
  App->>API: Richiede check-in, peso e piano
  API-->>App: Dati del paziente
  NUT->>App: Scrive un commento su un check-in
  App->>API: Salva il commento
  API->>PUSH: Richiede la notifica al paziente
```

**SD_4 – Creazione di un invito con verifica del limite del piano**

```mermaid
sequenceDiagram
  actor NUT as Nutrizionista
  participant App as App Cenato
  participant API as Back-end
  actor PAZ as Paziente
  NUT->>App: Tocca Invita
  App->>API: Richiede la creazione dell'invito
  API->>API: Verifica il piano e il numero di pazienti
  alt Limite raggiunto
    API-->>App: Rifiuto con motivo
    App-->>NUT: Propone di cambiare piano o archiviare
  else Posti disponibili
    API-->>App: Codice e link di invito
    App-->>NUT: Mostra il codice da condividere
    NUT-->>PAZ: Invia il codice
    PAZ->>App: Inserisce il codice e accetta il consenso
    App->>API: Accetta l'invito
    API->>API: Collega il paziente e aggiorna i contatori
    API-->>App: Conferma
  end
```

**SD_5 – Prenotazione di una visita da parte del paziente**

```mermaid
sequenceDiagram
  actor PAZ as Paziente
  participant App as App Cenato
  participant API as Back-end
  participant PUSH as Notifiche push
  actor NUT as Nutrizionista
  PAZ->>App: Apre la sezione Visite
  App->>API: Richiede gli slot liberi nella finestra di prenotazione
  API-->>App: Elenco degli slot liberi
  App-->>PAZ: Mostra gli slot
  PAZ->>App: Sceglie uno slot e conferma
  App->>API: Prenota lo slot
  API->>API: Verifica che lo slot sia ancora libero
  alt Slot ancora libero
    API-->>App: Visita confermata
    API->>PUSH: Avvisa il nutrizionista
    PUSH-->>NUT: Nuova visita prenotata
    App-->>PAZ: Visita fissata e promemoria programmato
  else Slot occupato nel frattempo
    API-->>App: Slot non più disponibile
    App-->>PAZ: Propone altri slot
  end
```

## 3.4.4.2 StateChart Diagram

**SCD_1 – Stati di un Invito**

```mermaid
stateDiagram-v2
  [*] --> Creato
  Creato --> Utilizzato: accettato dal paziente
  Creato --> Scaduto: scadenza raggiunta
  Creato --> Revocato: annullato dal nutrizionista
  Utilizzato --> [*]
  Scaduto --> [*]
  Revocato --> [*]
```

**SCD_2 – Stati di una visita**

```mermaid
stateDiagram-v2
  [*] --> Fissata: il nutrizionista fissa la visita
  [*] --> Prenotata: il paziente prenota uno slot libero
  Fissata --> Fissata: spostata dal nutrizionista
  Prenotata --> Fissata: spostata dal nutrizionista
  Fissata --> Annullata: annullata dal nutrizionista
  Prenotata --> Annullata: annullata dal paziente (entro il termine) o dal nutrizionista
  Fissata --> Annullata: paziente archiviato o scollegato
  Prenotata --> Annullata: paziente archiviato o scollegato
  Fissata --> Svolta: data e ora passate
  Prenotata --> Svolta: data e ora passate
  Annullata --> [*]
  Svolta --> [*]
```

Nota: dopo l'annullamento lo slot torna libero e il paziente può prenotare di nuovo (una sola visita futura alla volta).

**SCD_3 – Stati di un Paziente (per il nutrizionista)**

```mermaid
stateDiagram-v2
  [*] --> Invitato: invito creato
  Invitato --> Attivo: invito accettato
  Attivo --> Archiviato: archiviazione o scollegamento
  Archiviato --> Attivo: riattivazione, se il piano lo consente
  Invitato --> [*]: invito scaduto o revocato
```

Nota: non esiste uno stato "Eliminato" per un paziente che ha accettato un invito. Nel piano Free l'archiviazione non libera il posto; in Start e Pro libera un posto di paziente attivo.
