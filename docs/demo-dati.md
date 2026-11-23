# Dati di prova per la demo

Dati **fittizi** creati da `supabase/seed.sql`: personaggi degli scenari del RAD (`docs/rad/06-scenari.md`), nessun dato sanitario reale. Le date sono **relative a oggi**: rigenerando i dati il giorno prima della demo, semaforo, visite e finestre di prenotazione restano coerenti.

## Credenziali

Tutti gli account hanno la stessa password: **`CenatoDemo2026!`**

| Account | Ruolo | Chi è | Cosa mostra |
|---|---|---|---|
| `giulia@example.com` | Nutrizionista | Dott.ssa Giulia Rinaldi, biologa nutrizionista, piano **Pro annuale** (pagamento simulato) | Dashboard con semaforo verde, giallo e rosso; un paziente archiviato; un invito in attesa (codice `GIULIA26`); agenda con visite; commenti |
| `elena@example.com` | Nutrizionista | Dott.ssa Elena Ferri, dietista, piano **Free** | Ha già 1 paziente (Anna): un nuovo invito viene **bloccato** con l'errore del limite del piano (RF_GAD_7, SC_GAD_2) |
| `marco@example.com` | Paziente di Giulia | Marco Esposito | **Verde**: quasi tutti i pasti Seguiti, alternativa a colazione ogni 3 giorni; oggi ha già registrato la colazione; peso in calo (84,0 → 81,2 kg); **finestra di prenotazione aperta** (può prenotare una visita) |
| `sara@example.com` | Paziente di Giulia | Sara Romano | **Giallo**: spuntino saltato a giorni alterni, cena Fuori piano (pizza, ristorante, dolce, aperitivo); un pasto extra; commento di Giulia non ancora letto; visita **fissata** tra circa una settimana |
| `paolo@example.com` | Paziente di Giulia | Paolo Greco | **Rosso**: pranzo sempre saltato, molti pasti non registrati; visita **prenotata** da lui; commento di Giulia sul pranzo |
| `luca@example.com` | Paziente di Giulia | Luca Galli | **Archiviato** 12 giorni fa: lo storico resta consultabile da Giulia (RF_GI_4) |
| `anna@example.com` | Paziente di Elena | Anna Conti | Il paziente che occupa l'unico posto del piano Free di Elena |

Il dominio `example.com` è riservato agli esempi e l'app non lo accetta in registrazione: così gli account demo non si confondono con quelli veri, e lo script di reset cancella solo loro.

## Cosa contiene

- **Piani**: per ogni paziente un piano settimanale completo (7 giorni × colazione, spuntino, pranzo, cena) con alimenti, quantità, kcal e macro calcolati, e alternative (es. fiocchi d'avena → fette biscottate; yogurt → mela o banana; pollo ↔ merluzzo).
- **Obiettivi**: Marco 2000 kcal, 110 g proteine, 230 g carboidrati, 65 g grassi (come in SC_GP_4); gli altri simili.
- **Alimenti in cache**: 16 alimenti, alcuni con `fonte = open_food_facts` e gli altri `personalizzato`.
- **Check-in**: ultimi 10 giorni per Marco, Sara e Paolo, 7 per Anna, storico di Luca di 20-30 giorni fa.
- **Peso**: 6-7 misure settimanali per Marco, Sara e Paolo; 4 per Luca; 3 per Anna.
- **Agenda di Giulia**: lun-ven 9:00-13:00, mar e gio anche 15:00-19:00, visite da 45 minuti; 3 visite svolte, 1 fissata (Sara), 1 prenotata (Paolo).

## Semaforo atteso

Media degli ultimi **3 giorni completi** (ieri, l'altro ieri e il giorno prima). Punti: Seguito 1, Alternativa 1, Fuori piano 0,5, Saltato 0, non registrato 0. Soglie: verde ≥ 0,8, giallo 0,4-0,8, rosso < 0,4.

Esito del controllo alla fine di `seed.sql` (23/11/2026):

| Paziente | Nutrizionista | Media 3 giorni | Semaforo | Ultimo check-in |
|---|---|---|---|---|
| Marco Esposito | Giulia | 1,00 | verde | oggi |
| Anna Conti | Elena | 1,00 | verde | ieri |
| Sara Romano | Giulia | 0,71 | giallo | ieri |
| Paolo Greco | Giulia | 0,13 | rosso | ieri |

Il calcolo nell'app (e nella tabella `stati_aderenza`) arriva con la scheda "Calcolo aderenza, semaforo e dashboard" (fase 3). Se la regola cambia (es. includere oggi), va aggiornata anche questa interrogazione di controllo.

## Rigenerare i dati (prima della demo)

1. Supabase → **SQL Editor** → *New query*.
2. Incolla tutto `supabase/seed.sql` e premi **Run**.
3. In fondo compare la tabella del semaforo: verifica verde, giallo e rosso.

Lo script è anche lo **script di reset**: prima cancella solo i dati degli account demo (anche quelli modificati durante le prove), poi li ricrea. Si può eseguire tutte le volte che serve. Verificato il 23/11/2026: con i dati presenti, il reset ha cancellato 7 utenti, 6 pazienti, 178 check-in e 16 alimenti demo e nient'altro.

> Se il progetto Supabase è in pausa (piano gratuito, dopo 7 giorni senza attività), riattivalo prima: vedi `docs/supabase.md`, sezione 6.
