import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/obiettivi.dart';
import '../../domain/modelli/piano_alimentare.dart';
import '../../domain/repository/pazienti_repository.dart' show ErroreOperazione;
import '../comuni/componenti.dart';
import '../comuni/segnaposto_page.dart' show IntestazioneSezione;
import '../comuni/stati_view.dart';
import '../nutrizionista/alimenti/ricerca_alimento.dart' show formattaValore;
import '../nutrizionista/piano/piano_sola_lettura.dart';

/// Testi della sezione Dieta (in un punto solo, così i test li ritrovano).
abstract final class TestiDieta {
  static const sottotitoloVuoto = 'Piano e obiettivi';
  static const vuotoTitolo = 'Il tuo nutrizionista sta preparando il piano';
  static const vuotoMessaggio =
      'Quando il piano sarà pronto lo troverai qui, giorno per giorno. '
      'Tira verso il basso per controllare.';
  static const obiettiviTitolo = 'I tuoi obiettivi giornalieri';
  static const obiettiviMancanti =
      'Il tuo nutrizionista non ha ancora impostato gli obiettivi.';
  static const aggiornamentoFallito =
      'Aggiornamento non riuscito: vedi l\'ultimo piano scaricato.';
}

/// "27/11/2026", come nello storico delle versioni.
String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Sezione Dieta del paziente (UC_GP_4, RF_GP_8, RF_GP_16, NP_1_PAZ).
///
/// **Sola lettura**: obiettivi giornalieri, giorni del piano corrente con
/// pasti, alimenti, quantità, kcal e macro, totale del giorno confrontato
/// con gli obiettivi e alternative espandibili. Nessuna azione di modifica.
///
/// Mostra sempre la versione **corrente**: si ricarica quando i repository
/// avvisano di un cambiamento e con il "tira per aggiornare". Se
/// l'aggiornamento fallisce e un piano c'è già, resta quello (UC_GP_4,
/// flusso 2.2); l'errore a tutta pagina con "Riprova" compare solo se non è
/// mai stato caricato nulla.
class DietaPage extends StatefulWidget {
  const DietaPage({super.key, required this.dip, this.adesso = DateTime.now});

  final Dipendenze dip;

  /// Orologio: serve a evidenziare il giorno di oggi; i test lo fissano.
  final DateTime Function() adesso;

  @override
  State<DietaPage> createState() => _DietaPageState();
}

class _DietaPageState extends State<DietaPage> {
  /// Id della riga `pazienti` (non l'id utente, D18): letto una volta.
  String? _pazienteId;
  PianoAlimentare? _piano;
  Obiettivi? _obiettivi;

  /// `true` dopo il primo caricamento riuscito.
  bool _caricato = false;
  Object? _errore;

  /// Numero dell'ultima richiesta: le risposte di richieste superate da una
  /// più recente si scartano (due aggiornamenti ravvicinati).
  int _richiesta = 0;

  @override
  void initState() {
    super.initState();
    // I repository sono ChangeNotifier: avvisano dopo un salvataggio (nuova
    // versione del piano, nuovi obiettivi) e la pagina si aggiorna da sola.
    widget.dip.piani.addListener(_aggiornaInSilenzio);
    widget.dip.obiettivi.addListener(_aggiornaInSilenzio);
    _carica();
  }

  @override
  void dispose() {
    widget.dip.piani.removeListener(_aggiornaInSilenzio);
    widget.dip.obiettivi.removeListener(_aggiornaInSilenzio);
    super.dispose();
  }

  void _aggiornaInSilenzio() => unawaited(_carica());

  /// Legge piano corrente e obiettivi. Usato all'apertura, da "Riprova", dal
  /// "tira per aggiornare" e quando i repository cambiano.
  Future<void> _carica() async {
    final numero = ++_richiesta;
    if (!_caricato && _errore != null) setState(() => _errore = null);
    final dip = widget.dip;
    try {
      final id = _pazienteId ?? await dip.collegamento.mioPazienteId();
      PianoAlimentare? piano;
      Obiettivi? obiettivi;
      if (id != null) {
        // Le due letture sono indipendenti: in parallelo.
        final risultati = await Future.wait<Object?>([
          dip.piani.corrente(id),
          dip.obiettivi.corrente(id),
        ]);
        piano = risultati[0] as PianoAlimentare?;
        obiettivi = risultati[1] as Obiettivi?;
      }
      if (!mounted || numero != _richiesta) return;
      setState(() {
        _pazienteId = id;
        _piano = piano;
        _obiettivi = obiettivi;
        _caricato = true;
        _errore = null;
      });
    } catch (e) {
      if (!mounted || numero != _richiesta) return;
      if (_caricato) {
        // C'è già un piano a schermo: lo si lascia e si avvisa.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(TestiDieta.aggiornamentoFallito)),
          );
      } else {
        setState(() => _errore = e);
      }
    }
  }

  String get _sottotitolo {
    final p = _piano;
    if (p == null) return TestiDieta.sottotitoloVuoto;
    final versione = p.versione == null
        ? 'Piano'
        : 'Piano versione ${p.versione}';
    return '$versione · dal ${_data(p.dataInizio)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntestazioneSezione(
        titolo: Testi.dieta,
        sottotitolo: _sottotitolo,
        azioni: [
          IconButton(
            tooltip: Testi.profilo,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Rotte.pazienteProfilo),
          ),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (!_caricato) {
      final errore = _errore;
      if (errore == null) return const CaricamentoView();
      return ErroreView(
        messaggio: errore is ErroreOperazione
            ? errore.messaggio
            : Testi.erroreRete,
        onRiprova: _carica,
      );
    }
    const fisica = AlwaysScrollableScrollPhysics();
    final intestazione = _IntestazioneDieta(
      obiettivi: _obiettivi,
      aggiornatoIl: _piano?.creatoIl,
    );
    final piano = _piano;
    return RefreshIndicator(
      onRefresh: _carica,
      child: piano == null
          ? ListView(
              physics: fisica,
              padding: const EdgeInsets.all(16),
              children: [
                // Gli obiettivi restano visibili anche senza piano (RF_GP_16).
                intestazione,
                const SizedBox(height: 24),
                const _StatoVuotoDieta(),
              ],
            )
          : PianoSolaLettura(
              piano: piano,
              obiettivi: _obiettivi,
              giornoIniziale: widget.adesso().weekday,
              giornoOggi: widget.adesso().weekday,
              intestazione: intestazione,
              alternativeEspandibili: true,
              macroPerPasto: true,
              fisica: fisica,
            ),
    );
  }
}

/// Stato vuoto "piano in preparazione" dentro l'elenco scorrevole (così il
/// "tira per aggiornare" funziona anche qui). `StatoVuotoView` non va bene
/// dentro un `ListView`: è centrato su tutta l'altezza.
class _StatoVuotoDieta extends StatelessWidget {
  const _StatoVuotoDieta();

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Column(
      key: const Key('dieta-vuota'),
      children: [
        const IconaTonale(icona: Icons.restaurant_menu, dimensione: 80),
        const SizedBox(height: 20),
        Text(
          TestiDieta.vuotoTitolo,
          textAlign: TextAlign.center,
          style: testo.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          TestiDieta.vuotoMessaggio,
          textAlign: TextAlign.center,
          style: testo.bodyLarge?.copyWith(
            color: context.colori.testoSecondario,
          ),
        ),
      ],
    );
  }
}

/// Card degli obiettivi giornalieri (mock-up UI_GP_1) e data dell'ultimo
/// aggiornamento del piano. I valori vanno a capo con il testo grande.
class _IntestazioneDieta extends StatelessWidget {
  const _IntestazioneDieta({
    required this.obiettivi,
    required this.aggiornatoIl,
  });

  final Obiettivi? obiettivi;
  final DateTime? aggiornatoIl;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final o = obiettivi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          key: const Key('obiettivi-dieta'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(TestiDieta.obiettiviTitolo, style: testo.titleMedium),
                const SizedBox(height: 8),
                if (o == null)
                  Text(
                    TestiDieta.obiettiviMancanti,
                    style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
                  )
                else
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _Valore(valore: '${o.kcal}', etichetta: 'kcal'),
                      _Valore(
                        valore: '${formattaValore(o.proteineG)} g',
                        etichetta: 'proteine',
                      ),
                      _Valore(
                        valore: '${formattaValore(o.carboidratiG)} g',
                        etichetta: 'carboidrati',
                      ),
                      _Valore(
                        valore: '${formattaValore(o.grassiG)} g',
                        etichetta: 'grassi',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (aggiornatoIl != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Piano aggiornato il ${_data(aggiornatoIl!.toLocal())}',
              key: const Key('piano-aggiornato-il'),
              style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
            ),
          ),
      ],
    );
  }
}

/// Un obiettivo: valore grande ed etichetta sotto, letti insieme dal lettore
/// di schermo ("2000 kcal").
class _Valore extends StatelessWidget {
  const _Valore({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valore,
            style: testo.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            etichetta,
            style: testo.bodyMedium?.copyWith(
              color: context.colori.testoSecondario,
            ),
          ),
        ],
      ),
    );
  }
}
