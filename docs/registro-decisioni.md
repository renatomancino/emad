# 1. Registro delle decisioni (con motivazione)

Tutte le decisioni prese il 10/11/2026 dal gruppo (Renato Mancino, Mario Celzo) con il supporto di Claude. La colonna "Dove" rimanda ai paragrafi e ai requisiti dei documenti collegati: **RAD** (EMAD_Cenato_RAD_V0.6.0), **BMC** (EMAD_Cenato_BMC_V0.3.0), **Business Case** (EMAD_Cenato_BC_V0.3.0).

| # | Decisione | Motivazione / teoria | Dove |
|---|---|---|---|
| 1 | Nome **Cenato** | "Hai cenato?": l'azione confermata dal paziente con un tap | Registro §3 |
| 2 | Piattaforma a due lati, B2B2C: paga il nutrizionista, il paziente è gratuito su invito | L1 multi-sided; L4 Uber, Airbnb, Spotify | BMC §2, §4.1 |
| 3 | Back-end **Supabase**, regione UE | Dati relazionali, RLS per ruolo, piano gratuito per la demo | Registro §2; RAD RNF_I_2 |
| 4 | **Modello a check-in:** il paziente non registra alimenti né macro | Registrare quello che il nutrizionista ha già prescritto è lavoro ridondante; pain reliever più forte (L1 VPC) | RAD RF_GD_1, UC_GD_1 |
| 5 | Banca dati alimentare **Open Food Facts** + cache nostra (`alimenti`) | Acquirente-fornitore (L1); L3 Partner ↔ Risorse; attribuzione ODbL | RAD RNF_IN_1, RNF_L_5 |
| 6 | Inserimento del piano da telefono: giorno tipo con copia, pasti salvati e modelli, recenti, quantità rapide, **importazione CSV/Excel** con modello scaricabile | Il nutrizionista è lento da telefono; l'importazione è valore e risorsa (L3 Canali ↔ Valore, Risorse ↔ Valore) | RAD RF_GP_9–15 |
| 7 | Versione web come **sviluppo futuro** | Limite dell'MVP dichiarato; stessa codebase Flutter | BMC §7 |
| 8 | **Check-in a quattro stati:** Seguito, Alternativa (scelta tra quelle del nutrizionista), Fuori piano, Saltato | Un paziente non esperto può sbagliare a scrivere; scelta guidata invece di testo libero | RAD RF_GD_1–2, RF_GD_7, UC_GD_1 |
| 9 | Aderenza: 1 / 1 / 0,5 / 0; semaforo su media di 3 giorni (soglie da confermare con il consulente) | Indicatore di attenzione, non misura clinica | RAD RF_GAD_1 |
| 10 | **Gestionale base:** clienti attivi/archiviati e agenda con disponibilità, prenotazioni e prossima visita nella scheda cliente | Più valore per S1 e retention (L3 Valore ↔ Relazioni/Ricavi); i concorrenti lo includono; ERRC aggiornato (agenda da "Eliminare" a "Creare") | RAD RF_GI_6, RF_GV_1–9 |
| 11 | **Agenda completa, senza checkpoint:** è a priorità Alta e fa parte dell'MVP; se il tempo non bastasse si rinviano per primi barcode, spazio sponsor e quantità rapide | Il gruppo vuole completare l'agenda; con due persone resta valida la regola del prof di non promettere ciò che non si mostra | RAD §3.1.3, §3.1.4 |
| 12 | Stati del paziente (Invitato, Attivo, Archiviato) e filtro nella dashboard; **i pazienti non si eliminano, si archiviano** | Storico clinico e limite dei piani non aggirabile | RAD RF_GI_4–7 |
| 13 | Listino **Free / Start / Pro** con annuale a 10 mesi | L1 subscription e freemium; confronto con la concorrenza; incasso anticipato (L4) | BMC §4.5; Business Case §7.1 |
| 14 | **Free = 1 paziente a vita** | Mostrare come funziona senza permettere un uso continuativo gratuito | BMC §4.5; RAD RF_GAD_4 |
| 15 | **Spazio sponsor** statico solo sul Free per S1; nessuna pubblicità al paziente; nessun dato sanitario | L4 Spotify; L1 avverte su pubblicità e UX; GDPR art. 9; L3 Segmenti ↔ Ricavi | BMC §4.5; RAD RF_GAD_6, RNF_L_6 |
| 16 | Incasso sul sito proprio (non negli store); nell'MVP pagamento simulato | L3 Canali ↔ Costi/Ricavi (canale proprio) | BMC §4.3; Business Case §7.1; RAD RF_GAD_5 |
| 17 | Canali: **chiamate e interviste** (progetto universitario) + referral tra colleghi | Canale e validazione insieme; L4 Airbnb | BMC §4.3 |
| 18 | Dati di check-in usati solo per il servizio, **mai venduti** | L1 sconsiglia la vendita dei dati; dati sanitari | BMC §4.5, §4.6 |
| 19 | Fatturazione, pagamenti reali, videochiamate, web, Studio, marketplace: **sviluppi futuri** | Focalizzazione (ERRC); estensioni come in L4 (Uber Eats, Airbnb Experiences, Udemy for Business) | BMC §7 |
| 20 | Colori ■S1■S2■ su tutti i blocchi | Consiglio di L4 | BMC e Business Case |
| 21 | **Agenda con disponibilità e prenotazione:** il NUT indica giorni e orari alla registrazione; il PAZ prenota uno slot libero nella finestra stabilita dal NUT (di norma circa un mese dopo l'ultima visita); il NUT può anche fissare visite e il paziente è avvisato | Meno messaggi di coordinamento (valore S1); self-service come relazione con S2 (L1); retention (L3 Valore ↔ Relazioni) | RAD RF_GV_6–9, RF_GN_5, UC_GV_3–4; BMC §4.2, §4.4 |
| 22 | **Obiettivi nutrizionali** (kcal e macro) impostati dal NUT per paziente prima del piano; l'editor mostra lo scostamento | Il piano nasce da un obiettivo, non solo da una lista di alimenti; gli obiettivi sono visibili al paziente | RAD RF_GP_16, UC_GP_6 |
| 23 | App del paziente in quattro sezioni: **Oggi, Dieta, Andamento, Visite** | Il check-in ha valore per il paziente solo se riceve riscontri sul proprio percorso (VPC S2: gain "vedere i progressi") | RAD RF_GM_4, RNF_U_6, §3.4.5 |
| 24 | Scadenza di consegna ipotizzata: **entro gennaio 2027**, da adeguare all'appello | Pianificazione del lavoro in base ai tempi del corso | RAD §1.3; Registro §5 |
| 25 | **Aderenza per pasto:** il NUT vede quali pasti il paziente salta o sostituisce di più (per tipo di pasto e giorno della settimana) e può adattare il piano | Idea del gruppo: il check-in diventa utile anche al nutrizionista (feedback per piani più realistici) e al paziente; si calcola dai dati già raccolti | RAD RF_GM_5, SC_GM_3, UC_GM_3 |
| 26 | **Errore al raggiungimento del limite del piano:** l'invito viene bloccato con un messaggio che spiega il motivo e le opzioni (cambio piano, archiviazione) | Il limite è la regola del modello di ricavi: il NUT deve capirla e poter agire | RAD RF_GAD_7, SC_GAD_2, UC_GI_1, §3.1.2 |
| 27 | **RAD nel formato del RAD di riferimento (Esistere):** requisiti divisi in comuni, lato Nutrizionista e lato Paziente; scenari, casi d'uso, oggetti Entity/Control/Boundary e glossario in tabelle; stati di una visita al posto degli stati di un pasto; due Navigation Path; mock-up delle funzioni principali | Maggiore leggibilità e coerenza con il modello di Bruegge; richiesta del gruppo | RAD §3.2, §3.4 |
| 28 | **Restyling grafico (25/11/2026):** titolo grande su sfondo chiaro al posto della fascia verde dei mock-up, card bianche con ombra morbida, icone tonali, filtri a pillole; font **Plus Jakarta Sans** (titoli) e **Inter** (testo), incorporati nell'app (licenza SIL OFL, nessun download a runtime); colori letti da un set che segue il tema (`CenatoColori`), pronto per un tema scuro. **Deroga ai mock-up del RAD** (`docs/rad/img/`, UI_*): le immagini non sono state rigenerate e non coincidono più con l'app | Aspetto professionale e attuale per la live demo (riferimenti: app salute e di prenotazione visite). Contrasto AA, aree di tocco da 48 dp e testo che segue le impostazioni del telefono restano garantiti (l'intestazione cresce fino a 1,3×). Nessuna modifica a logica, testi o requisiti | RAD RNF_U_3, §3.4.5; `docs/superpowers/specs/2026-11-25-restyling-grafico-design.md` |

# 2. Back-end: Supabase (valutazione del 10/11/2026)

**Verdetto: adatto.**

- Database **PostgreSQL relazionale**: i nostri dati (professionisti, pazienti, piani, pasti, misure) sono relazionali. Le **policy Row Level Security (RLS)** definiscono a livello di database chi legge cosa: "il nutrizionista vede solo i propri pazienti, il paziente solo sé stesso". Sono responsabilità nostra: vanno scritte e testate con cura.
- Auth, Storage, Edge Functions e Realtime inclusi; SDK Flutter (`supabase_flutter`).
- **Piano Free:** 500 MB di database, 50.000 utenti attivi/mese; **il progetto va in pausa dopo 1 settimana di inattività** → prima della live demo riattivarlo e fare un test completo. Piano Pro: 25 $/mese.
- **Regione UE:** scegliere una regione specifica (Francoforte, Irlanda o Parigi). Il gruppo generico "Europe" include anche Londra e Zurigo, che non sono nell'UE. La regione controlla dove stanno i dati ma non rende l'app conforme al GDPR da sola.
- Nel pitch: in produzione servirebbero DPA e valutazione d'impatto (DPIA), perché sono dati sanitari.

**Da chiedere al prof:** se per l'esame va bene qualsiasi back-end.
**Da consegnare nello zip (back-end):** script SQL dello schema, policy RLS, eventuali Edge Functions, `.env.example` senza chiavi.

# 3. Nome: Cenato (scelto il 10/11/2026)

- **Origine:** Ce(lzo) + (Re)nato; in italiano "cenato" = "hai cenato?", cioè l'azione che il paziente conferma con un tap.
- **Idea di logo:** forchetta/piatto con segno di spunta ("pasto confermato").
- **Slogan possibile:** "Hai cenato? Il tuo nutrizionista lo sa."
- **Verifiche fatte:** ricerche web senza conflitti diretti trovati (verifica debole).
- **Da fare prima di usarlo ufficialmente:** App Store, Google Play, dominio .it/.com, EUIPO TMview e UIBM.
- **Scartati:** NutriSync (già usato), NutriLoop ("Nutrition Loop" esiste), prefisso "Nutri-" affollato, Prandia (vicino a "Prandi"), Dietra (vicino a "Dietora").

# 4. Punti aperti e prossimi passi

**Punti aperti**

1. Data dell'appello e scadenza definitiva di consegna (ipotesi: entro gennaio 2027).
2. Back-end confermato dal docente (Supabase, regione UE).
3. Regola esatta di calcolo dell'aderenza e soglie del semaforo; trattamento del pasto extra.
4. Funzionamento offline (escluso dall'MVP).
5. Build iOS per la demo (serve un Mac) oppure solo Android.
6. Validazione con 2–3 nutrizionisti reali (interviste) e verifica dei prezzi dei concorrenti (soprattutto Nutribook e Practice Better).
7. Mock-up e identità grafica di Cenato.
8. Struttura del piano: menu con quantità e alternative (scelta per l'MVP) oppure sistema a scambi/porzioni (futuro).
9. Banche dati alimentari usate dai nutrizionisti italiani (es. CREA, BDA); per l'MVP si usa Open Food Facts, la cui copertura è stata giudicata buona dal gruppo, con test documentato su 15–20 alimenti tipici.
10. Regole degli store sui pagamenti esterni e obblighi fiscali, prima di un lancio reale.
11. Verifica del nome Cenato: store, dominio, EUIPO/UIBM.
12. Regole della prenotazione da confermare: finestra di prenotazione per paziente, annullamento fino a 24 ore prima, conferma immediata senza approvazione del nutrizionista, destino delle visite future di un paziente archiviato.
13. Tolleranza dello scostamento dagli obiettivi nutrizionali e soglia di coerenza tra kcal e macro (ipotesi: 10%).

**Prossimi passi**

1. Il gruppo valida la bozza: soglie del semaforo, listino, requisiti e casi d'uso del RAD 0.6.0.
2. Intervistare 2–3 nutrizionisti: dove compongono i piani e con quali software, disponibilità a pagare, reazione ai prezzi 12/120 € e 25/250 €, utilità dell'agenda, tolleranza dello spazio sponsor.
3. Ricontrollare i prezzi dei concorrenti sui siti ufficiali (soprattutto Nutribook e Practice Better) e completare la tabella.
4. Rifinire il canvas a colori (■S1 ■S2 ■) per il pitch (BMC).
5. Mock-up e RAD completo: prodotti nel RAD 0.6.0 (§3.4.5), da validare e, se serve, rifinire.
6. Verifica del nome: store, dominio, EUIPO/UIBM.
7. Test documentato della copertura di Open Food Facts con 15–20 alimenti tipici (il gruppo ha già giudicato la copertura buona).
8. Chiedere al docente: data dell'appello (la scadenza ipotizzata è gennaio 2027) e ok sul back-end Supabase.
9. Verificare le regole degli store sui pagamenti esterni prima di un lancio reale.
10. Solo quando il gruppo lo decide: setup Flutter + Supabase (schema, RLS).

# 5. Piano di realizzazione dell'MVP (bozza)

L'MVP è il **più piccolo insieme di funzioni che dimostra il valore** di Cenato in live demo: nel nostro caso, tutti i requisiti a priorità A e M del RAD (§3.2). Si realizza per **fette verticali**: ogni fase porta una funzione completa (schermata, logica, dati, test) e utilizzabile, invece di costruire prima tutto il database e poi tutte le schermate. Così a ogni fase c'è qualcosa da mostrare . Date indicative, con consegna entro gennaio 2027 (da adeguare all'appello).

| Fase | Periodo | Contenuto | Verifica |
|---|---|---|---|
| 0. Preparazione | 10–16/11 | Conferma del docente su Supabase e scadenza; mock-up di Oggi, editor del piano, calendario; repository Flutter; progetto Supabase (regione UE) con schema e policy RLS | Schema e policy scritti; mock-up approvati dal gruppo |
| 1. Account, inviti, limiti | 17–30/11 | Registrazione con ruoli e consenso, inviti, stati del paziente, limiti Free/Start/Pro, abbonamento simulato | Test sulle policy di accesso e sui limiti dei piani |
| 2. Obiettivi e piano | 24/11–14/12 | Obiettivi nutrizionali, editor del piano (ricerca Open Food Facts, barcode, alternative, giorno tipo, scostamento), sezione Dieta del paziente | Un piano completo creato da telefono e visto dal paziente |
| 3. Check-in e dashboard | 8–21/12 | Check-in a quattro stati, Oggi e Andamento, semaforo, dettaglio paziente, commenti, peso, promemoria | Un paziente fa i check-in e il nutrizionista vede il semaforo |
| 4. Agenda | 15–28/12 | Disponibilità, calendario con slot, visita fissata dal NUT, prenotazione e annullamento da parte del PAZ, avvisi | Agenda completa: disponibilità, slot, visita fissata e prenotata |
| 5. Completamento | 29/12–11/1 | Importazione CSV, modelli e pasti salvati, spazio sponsor, rifiniture grafiche | Tutte le funzioni A e M dimostrabili |
| 6. Test e demo | 12–25/1 | Test di sicurezza (RLS), prove su telefono reale, build Android (e iOS se disponibile), copertura Open Food Facts su 15–20 alimenti | Prova generale della demo |
| 7. Consegna | 26–31/1 | Pitch, aggiornamento dei documenti, archivio .zip con i nomi di tutti i membri | Consegna |

La suddivisione del lavoro tra Renato e Mario va decisa dal gruppo (ad esempio: uno su back-end e piano, l'altro su check-in, agenda e interfaccia del paziente). Le fasi 2 e 4 sono le più rischiose; durante le festività i tempi possono dilatarsi, per questo c'è un margine nell'ultima settimana.
