# 3.4.5 Interfaccia utente: percorsi di navigazione e mock-up

## 3.4.5.1 Navigation Path

**NP_1_PAZ – Percorso di navigazione del paziente**

```mermaid
flowchart LR
  L[Login]
  R[Registrazione<br/>con invito e consenso]
  L --> R
  L --> P1
  R --> P1
  P1[Oggi:<br/>pasti e check-in]
  P1 --> P2[Check-in del pasto:<br/>Seguito, Alternativa,<br/>Fuori piano, Saltato]
  P1 --> P10[Pasto extra]
  P1 --> P5[Dieta:<br/>piano e obiettivi]
  P1 --> P6[Andamento:<br/>peso, aderenza,<br/>commenti]
  P6 --> P11[Aggiungi peso]
  P6 --> P12[Storico<br/>dei check-in]
  P1 --> P8[Visite:<br/>prossima visita]
  P8 --> P9[Prenota tra<br/>gli slot liberi]
  P8 --> P13[Annulla visita]
  P1 --> P7[Profilo e<br/>impostazioni]
  P7 --> P14[Promemoria]
  P7 --> P15[Elimina account]
```

**NP_2_NUT – Percorso di navigazione del nutrizionista**

```mermaid
flowchart LR
  L[Login o<br/>registrazione]
  N15[Disponibilità<br/>alla registrazione]
  L --> N15
  L --> N1
  N15 --> N1
  N1[Elenco pazienti:<br/>semaforo e filtro]
  N1 --> N2[Dettaglio<br/>paziente]
  N2 --> N14[Obiettivi<br/>nutrizionali]
  N2 --> N3[Commenta<br/>check-in]
  N2 --> N16[Aderenza<br/>per pasto]
  N2 --> N4[Editor<br/>piano]
  N4 --> N6[Ricerca alimento<br/>o barcode,<br/>quantità e macro]
  N4 --> N9[Importa<br/>da file]
  N2 --> N10[Archivia<br/>paziente]
  N1 --> N5[Genera invito]
  N5 --> N17[Errore:<br/>limite del piano]
  N1 --> N11[Calendario]
  N11 --> N12[Nuova visita]
  N11 --> N13[Disponibilità e<br/>finestra di prenotazione]
  N1 --> N8[Profilo e<br/>abbonamento]
  N17 -.-> N8
```

## 3.4.5.2 Mock-up

I mock-up mostrano ad alto livello le schermate delle funzioni principali; lo stile grafico definitivo sarà coerente con la proposta di valore (rapidità, chiarezza, motivazione). Le schermate del paziente sono le quattro sezioni dell'app (Oggi, Dieta, Andamento, Visite).

![Mock-up delle schermate del Paziente (Oggi, Dieta, Andamento, Visite)](img/ui_paz.png)

![Mock-up del Nutrizionista: dashboard, dettaglio paziente, editor del piano](img/ui_nut1.png)

![Mock-up del Nutrizionista: calendario, abbonamento e limite del piano](img/ui_nut2.png)
