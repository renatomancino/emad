# RAD di Cenato (versione Markdown)

Questa cartella contiene il **Requirements Analysis Document (RAD) 0.6.0** di Cenato in formato Markdown, diviso per sezione, pensato per essere letto da chi sviluppa e da Claude quando riceve un prompt di implementazione. Il testo è lo stesso del documento `EMAD_Cenato_RAD_V0.6.0` (.docx/.pdf): se i due divergono, vale il documento Word/PDF e va corretto il Markdown.

Cenato è un'app Flutter con back-end Supabase per il coaching nutrizionale **Nutrizionista ↔ Paziente**. Il RAD dice **che cosa** deve fare il sistema; le scelte di mercato e di prezzo sono nei documenti separati (BMC, Business Case, Registro delle decisioni).

## Indice dei file

| File | Sezione del RAD | Che cosa contiene | Quando serve |
|---|---|---|---|
| `01-introduzione.md` | §1 | Scopo, ambito, obiettivi, definizioni, riferimenti | Per capire il progetto e le sigle (RF, RNF, UC, SC, SD, SCD, GA, GI, GP...) |
| `02-sistema-attuale.md` | §2 | Come si lavora oggi (PDF e WhatsApp) e soluzioni esistenti | Per il contesto del problema |
| `03-panoramica-e-mvp.md` | §3.1 | Attori, activity diagram del flusso principale, funzionalità dell'MVP, priorità e limiti noti | **Prima di iniziare qualsiasi fase**: dice cosa è dentro l'MVP e cosa si rinvia |
| `04-requisiti-funzionali.md` | §3.2 | Tutti i requisiti RF in tre tabelle: comuni, lato Nutrizionista, lato Paziente | Ogni funzione; ogni RF ha priorità A, M o B |
| `05-requisiti-non-funzionali.md` | §3.3 | Requisiti RNF: usabilità, affidabilità, prestazioni, implementazione, interfacce, packaging, legali | Vincoli di tempo, sicurezza, GDPR, piattaforme |
| `06-scenari.md` | §3.4.1 | 21 scenari con personaggi (Dott.ssa Giulia; Marco, Sara, Luca, Paolo) | Per capire l'uso reale e per preparare i dati di prova e la demo |
| `07-casi-d-uso.md` | §3.4.2 | Use Case Diagram e 33 casi d'uso con flusso principale e flussi di errore | **Il file più usato**: ogni schermata e ogni logica parte da qui |
| `08-modello-ad-oggetti.md` | §3.4.3 | Oggetti Entity, Control, Boundary per gruppo e Class Diagram | Schema del database e struttura del codice |
| `09-modello-dinamico.md` | §3.4.4 | Sequence Diagram (SD_1–SD_5) e StateChart (SCD_1–SCD_3) | Ordine delle chiamate e stati (paziente, visita, check-in) |
| `10-interfaccia-utente.md` | §3.4.5 | Percorsi di navigazione (NP_1_PAZ, NP_2_NUT) e mock-up | Schermate e navigazione |
| `11-glossario.md` | §4 | Glossario dei termini | Per i nomi in italiano usati nell'app |
| `img/` | | Immagini: Use Case Diagram e mock-up | Referenziate dai file |

I diagrammi (activity, class, sequence, statechart, navigazione) sono scritti in **Mermaid**: GitHub, VS Code (con l'estensione Markdown Preview Mermaid) e gli strumenti di Claude li interpretano direttamente.

## Come leggere gli identificatori

Il formato è `TIPO_GRUPPO_NUMERO`, ad esempio `UC_GP_1` o `RF_GD_3`.

| Sigla | Significato |
|---|---|
| `RF` / `RNF` | requisito funzionale / non funzionale |
| `SC` | scenario |
| `UC` | caso d'uso |
| `SD` | sequence diagram |
| `SCD` | statechart diagram |
| `NP` | navigation path (percorso di navigazione) |
| `UI` | mock-up |

I gruppi funzionali sono: **GA** Gestione Account, **GI** Gestione Inviti e Pazienti, **GP** Gestione Piano, **GD** Gestione Check-in dei pasti, **GM** Gestione Misure e Andamento, **GN** Gestione Notifiche, **GC** Gestione Commenti, **GV** Gestione Visite (agenda), **GAD** Gestione Abbonamento e Dashboard. Le priorità sono **A** alta (indispensabile), **M** media (nell'MVP dopo le A), **B** bassa (sviluppo futuro, non si implementa).

## Come usarlo in un prompt

Per implementare una funzione, nel prompt si indicano il caso d'uso, lo scenario, i requisiti e, se serve, il diagramma o il mock-up. Esempio:

> Leggi `CLAUDE.md`, poi in `docs/rad/` il caso d'uso `UC_GD_1` (`07-casi-d-uso.md`), lo scenario `SC_GD_1` (`06-scenari.md`), i requisiti `RF_GD_1`–`RF_GD_4` (`04-requisiti-funzionali.md`) e il sequence diagram `SD_1` (`09-modello-dinamico.md`). Implementa la sezione Oggi del paziente seguendo il flusso principale e i flussi di errore.

Ogni scheda di Trello ha già il suo prompt con questi riferimenti.

## Regole di aggiornamento

- Il RAD cambia solo per decisione del gruppo; se cambia un requisito, va cambiato anche nei documenti allineati (BMC, Business Case, Registro).
- Se durante lo sviluppo una funzione A o M viene rinviata, si annota nel file `03-panoramica-e-mvp.md` (sezione "Priorità, fattibilità e limiti noti") e si avvisa chi cura i documenti.
- I valori marcati **[DA CONFERMARE]** (soglie del semaforo, regole di prenotazione, tolleranza del 10%, soglie minime di check-in) sono ipotesi: si implementano come costanti facili da cambiare.
