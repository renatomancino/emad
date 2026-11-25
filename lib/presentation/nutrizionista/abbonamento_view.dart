import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';
import '../../domain/modelli/piano.dart';
import '../../domain/regole/limiti_piano.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/componenti.dart';
import '../comuni/segnaposto_page.dart';
import '../comuni/stati_view.dart';

/// AbbonamentoPage (UC_GAD_3, RF_GAD_4, RF_GAD_5): piano attuale, posti
/// occupati, listino e cambio piano con pagamento SIMULATO.
class AbbonamentoView extends StatefulWidget {
  const AbbonamentoView({super.key, required this.repository});

  final AbbonamentoRepository repository;

  @override
  State<AbbonamentoView> createState() => _AbbonamentoViewState();
}

class _AbbonamentoViewState extends State<AbbonamentoView> {
  StatoAbbonamento? _stato;
  String? _errore;
  bool _inCorso = false;
  PeriodoFatturazione _periodo = PeriodoFatturazione.annuale;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() => _errore = null);
    try {
      final s = await widget.repository.stato();
      if (mounted) {
        setState(() {
          _stato = s;
          _periodo = s.periodo ?? _periodo;
        });
      }
    } on ErroreOperazione catch (e) {
      if (mounted) setState(() => _errore = e.messaggio);
    }
  }

  Future<void> _passaA(PianoAbbonamento piano) async {
    final periodo = piano == PianoAbbonamento.free ? null : _periodo;
    final prezzo = periodo == null ? 0 : piano.prezzoCent(periodo);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Passa a ${piano.etichetta}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colori.avvisoTonale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Pagamento simulato: nessun addebito.',
                key: Key('avviso-simulato'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              periodo == null
                  ? 'Piano Free: 1 paziente a vita, nessun costo.'
                  : 'Piano ${piano.etichetta}, ${formattaEuro(prezzo)} '
                        '${periodo.suffisso} (IVA esclusa). ${piano.descrizioneLimite}.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Conferma'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    setState(() => _inCorso = true);
    try {
      await widget.repository.cambiaPiano(piano, periodo);
      await _carica();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ora sei sul piano ${piano.etichetta} (pagamento simulato).',
          ),
        ),
      );
    } on ErroreLimitePiano catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambio piano non possibile'),
          content: Text(
            [
              e.messaggio,
              if (e.suggerimento != null) e.suggerimento!,
            ].join('\n\n'),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.messaggio)));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errore != null) {
      return SizedBox(
        height: 240,
        child: ErroreView(messaggio: _errore!, onRiprova: _carica),
      );
    }
    final s = _stato;
    if (s == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 160),
        child: const CaricamentoView(),
      );
    }

    final testo = Theme.of(context).textTheme;
    final occupati = postiOccupati(
      piano: s.piano,
      pazientiAttivi: s.pazientiAttivi,
      pazientiCollegatiTotali: s.pazientiCollegatiTotali,
      invitiInAttesa: s.invitiInAttesa,
    );
    final limite = s.piano.limite;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SchedaSezione(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Il tuo piano', style: testo.labelLarge),
              Text(
                s.piano.etichetta +
                    (s.periodo == null ? '' : ' · ${s.periodo!.name}'),
                key: const Key('piano-attuale'),
                style: testo.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                limite == null
                    ? 'Pazienti: ${s.pazientiAttivi} attivi · illimitati'
                    : 'Posti occupati: $occupati su $limite',
              ),
              if (limite != null) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (occupati / limite).clamp(0, 1).toDouble(),
                  backgroundColor: context.colori.primarioTonale,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
              if (s.invitiInAttesa > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Comprende ${s.invitiInAttesa} invito/i in attesa.',
                    style: testo.bodySmall?.copyWith(
                      color: context.colori.testoSecondario,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SelettorePillole<PeriodoFatturazione>(
          opzioni: const [
            OpzioneSelettore(PeriodoFatturazione.mensile, 'Mensile'),
            OpzioneSelettore(
              PeriodoFatturazione.annuale,
              'Annuale (2 mesi gratis)',
            ),
          ],
          selezionato: _periodo,
          onCambiato: (v) => setState(() => _periodo = v),
        ),
        const SizedBox(height: 12),
        for (final piano in PianoAbbonamento.values) ...[
          _SchedaPiano(
            piano: piano,
            periodo: _periodo,
            attuale:
                piano == s.piano &&
                (piano == PianoAbbonamento.free || s.periodo == _periodo),
            inCorso: _inCorso,
            onScegli: () => _passaA(piano),
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Tutte le funzioni sono incluse in tutti i piani. Prezzi IVA esclusa. '
          'Nell\'MVP il pagamento è simulato: nessun addebito.',
          style: testo.bodySmall?.copyWith(
            color: context.colori.testoSecondario,
          ),
        ),
      ],
    );
  }
}

class _SchedaPiano extends StatelessWidget {
  const _SchedaPiano({
    required this.piano,
    required this.periodo,
    required this.attuale,
    required this.inCorso,
    required this.onScegli,
  });

  final PianoAbbonamento piano;
  final PeriodoFatturazione periodo;
  final bool attuale;
  final bool inCorso;
  final VoidCallback onScegli;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final prezzo = piano == PianoAbbonamento.free
        ? 'Gratis'
        : '${formattaEuro(piano.prezzoCent(periodo))} ${periodo.suffisso}';
    final c = context.colori;
    return SchedaSezione(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  piano.etichetta,
                  style: testo.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (attuale) const EtichettaStato(testo: 'Attuale'),
            ],
          ),
          Text(
            piano.descrizioneLimite,
            style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
          ),
          const SizedBox(height: 4),
          Text(prezzo, style: testo.titleSmall?.copyWith(color: c.primario)),
          if (!attuale) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: inCorso ? null : onScegli,
              child: Text('Passa a ${piano.etichetta}'),
            ),
          ],
        ],
      ),
    );
  }
}
