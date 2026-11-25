import 'package:material_ui/material_ui.dart';

import '../../core/tema/tema.dart';
import '../../domain/modelli/obiettivi.dart';
import '../../domain/regole/obiettivi.dart';
import '../../domain/repository/obiettivi_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/componenti.dart';
import '../comuni/controlli.dart';
import '../comuni/stati_view.dart';

/// Obiettivi nutrizionali giornalieri di un paziente (UC_GP_6, RF_GP_16):
/// kcal, proteine, carboidrati e grassi. Ogni salvataggio crea una nuova
/// versione (storico); i piani già assegnati non cambiano.
class ObiettiviPage extends StatefulWidget {
  const ObiettiviPage({
    super.key,
    required this.repository,
    required this.pazienteId,
    this.nomePaziente,
  });

  final ObiettiviRepository repository;
  final String pazienteId;
  final String? nomePaziente;

  @override
  State<ObiettiviPage> createState() => _ObiettiviPageState();
}

class _ObiettiviPageState extends State<ObiettiviPage> {
  final _kcal = TextEditingController();
  final _proteine = TextEditingController();
  final _carboidrati = TextEditingController();
  final _grassi = TextEditingController();

  final Map<String, String?> _errori = {};
  bool _caricamento = true;
  String? _erroreCaricamento;
  ErroreOperazione? _erroreSalvataggio;
  bool _inCorso = false;
  Obiettivi? _attuale;
  List<Obiettivi> _storico = [];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    for (final c in [_kcal, _proteine, _carboidrati, _grassi]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _erroreCaricamento = null;
    });
    try {
      final storico = await widget.repository.storico(widget.pazienteId);
      if (!mounted) return;
      setState(() {
        _storico = storico;
        _attuale = storico.isEmpty ? null : storico.first;
        if (_attuale != null) _precompila(_attuale!);
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _erroreCaricamento = e.messaggio;
        _caricamento = false;
      });
    }
  }

  void _precompila(Obiettivi o) {
    _kcal.text = '${o.kcal}';
    _proteine.text = _numero(o.proteineG);
    _carboidrati.text = _numero(o.carboidratiG);
    _grassi.text = _numero(o.grassiG);
  }

  void _pulisci(String campo) {
    setState(() {
      _errori[campo] = null;
      _erroreSalvataggio = null;
    });
  }

  /// Avviso di coerenza kcal/macro, solo se tutti i valori sono già validi.
  String? get _avviso {
    if (ValidazioneObiettivi.kcal(_kcal.text) != null) return null;
    final p = _macroValido(_proteine, 'Proteine');
    final c = _macroValido(_carboidrati, 'Carboidrati');
    final g = _macroValido(_grassi, 'Grassi');
    if (p == null || c == null || g == null) return null;
    return ValidazioneObiettivi.avvisoCoerenza(
      kcal: ValidazioneObiettivi.leggiNumero(_kcal.text)!.round(),
      proteineG: p,
      carboidratiG: c,
      grassiG: g,
    );
  }

  double? _macroValido(TextEditingController c, String etichetta) =>
      ValidazioneObiettivi.macro(c.text, etichetta) == null
      ? ValidazioneObiettivi.leggiNumero(c.text)
      : null;

  Future<void> _salva() async {
    final errori = <String, String?>{
      'kcal': ValidazioneObiettivi.kcal(_kcal.text),
      'proteine': ValidazioneObiettivi.macro(_proteine.text, 'Proteine'),
      'carboidrati': ValidazioneObiettivi.macro(
        _carboidrati.text,
        'Carboidrati',
      ),
      'grassi': ValidazioneObiettivi.macro(_grassi.text, 'Grassi'),
    };
    setState(() {
      _errori
        ..clear()
        ..addAll(errori);
      _erroreSalvataggio = null;
    });
    if (errori.values.any((e) => e != null)) return;

    final nuovi = (
      kcal: ValidazioneObiettivi.leggiNumero(_kcal.text)!.round(),
      p: ValidazioneObiettivi.leggiNumero(_proteine.text)!,
      c: ValidazioneObiettivi.leggiNumero(_carboidrati.text)!,
      g: ValidazioneObiettivi.leggiNumero(_grassi.text)!,
    );
    final messaggi = ScaffoldMessenger.of(context);
    final attuale = _attuale;
    if (attuale != null &&
        attuale.kcal == nuovi.kcal &&
        attuale.proteineG == nuovi.p &&
        attuale.carboidratiG == nuovi.c &&
        attuale.grassiG == nuovi.g) {
      // Stessi valori: niente nuova riga nello storico.
      messaggi.showSnackBar(
        const SnackBar(
          content: Text('Nessuna modifica: gli obiettivi sono gli stessi.'),
        ),
      );
      return;
    }

    setState(() => _inCorso = true);
    try {
      await widget.repository.imposta(
        widget.pazienteId,
        kcal: nuovi.kcal,
        proteineG: nuovi.p,
        carboidratiG: nuovi.c,
        grassiG: nuovi.g,
      );
      if (!mounted) return;
      messaggi.showSnackBar(
        SnackBar(
          content: Text(
            widget.nomePaziente == null
                ? 'Obiettivi salvati.'
                : 'Obiettivi di ${widget.nomePaziente} salvati.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ErroreOperazione catch (e) {
      // I campi restano compilati: si corregge o si riprova.
      if (mounted) setState(() => _erroreSalvataggio = e);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Obiettivi nutrizionali')),
      body: SafeArea(
        child: _caricamento
            ? const CaricamentoView()
            : _erroreCaricamento != null
            ? ErroreView(messaggio: _erroreCaricamento!, onRiprova: _carica)
            : _modulo(context),
      ),
    );
  }

  Widget _modulo(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    const numerica = TextInputType.numberWithOptions(decimal: true);
    final avviso = _avviso;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.nomePaziente != null)
              Text(widget.nomePaziente!, style: testo.titleLarge),
            const SizedBox(height: 4),
            Text(
              _attuale == null
                  ? 'Non ci sono ancora obiettivi. Impostali prima di '
                        'comporre il piano: l\'editor li usa come riferimento.'
                  : 'In vigore dal ${_data(_attuale!.dal)}. Una modifica non '
                        'cambia i piani già assegnati, solo lo scostamento.',
              style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
            ),
            const SizedBox(height: 16),
            CampoTesto(
              controller: _kcal,
              etichetta: 'Calorie al giorno (kcal)',
              errore: _errori['kcal'],
              tastiera: const TextInputType.numberWithOptions(),
              azioneTastiera: TextInputAction.next,
              onCambiato: (_) => _pulisci('kcal'),
            ),
            const SizedBox(height: 12),
            CampoTesto(
              controller: _proteine,
              etichetta: 'Proteine al giorno (g)',
              errore: _errori['proteine'],
              tastiera: numerica,
              azioneTastiera: TextInputAction.next,
              onCambiato: (_) => _pulisci('proteine'),
            ),
            const SizedBox(height: 12),
            CampoTesto(
              controller: _carboidrati,
              etichetta: 'Carboidrati al giorno (g)',
              errore: _errori['carboidrati'],
              tastiera: numerica,
              azioneTastiera: TextInputAction.next,
              onCambiato: (_) => _pulisci('carboidrati'),
            ),
            const SizedBox(height: 12),
            CampoTesto(
              controller: _grassi,
              etichetta: 'Grassi al giorno (g)',
              errore: _errori['grassi'],
              tastiera: numerica,
              azioneTastiera: TextInputAction.done,
              onInvio: _salva,
              onCambiato: (_) => _pulisci('grassi'),
            ),
            if (avviso != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('avviso-coerenza'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.avvisoTonale,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: c.avviso),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(avviso, style: TextStyle(color: c.avviso)),
                    ),
                  ],
                ),
              ),
            ],
            if (_erroreSalvataggio != null) ...[
              const SizedBox(height: 12),
              MessaggioErrore(
                messaggio: _erroreSalvataggio!.messaggio,
                onRiprova: _salva,
              ),
            ],
            const SizedBox(height: 20),
            PulsantePrimario(
              etichetta: 'Salva obiettivi',
              onPressed: _salva,
              inCorso: _inCorso,
            ),
            if (_storico.length > 1) ...[
              const SizedBox(height: 24),
              SchedaSezione(
                titolo: 'Versioni precedenti',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final o in _storico.skip(1))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Dal ${_data(o.dal)}: ${o.kcal} kcal · '
                          'P ${_numero(o.proteineG)} g · '
                          'C ${_numero(o.carboidratiG)} g · '
                          'G ${_numero(o.grassiG)} g',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "110" invece di "110.0", "110,5" con la virgola.
String _numero(double v) =>
    (v == v.roundToDouble() ? v.toInt().toString() : v.toString()).replaceAll(
      '.',
      ',',
    );

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
