import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/obiettivi.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/repository/obiettivi_repository.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../../domain/repository/piani_repository.dart';
import '../../comuni/componenti.dart';
import '../../comuni/stati_view.dart';
import 'piano_sola_lettura.dart';

String _data(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Versioni del piano di un paziente (RF_GP_7): elenco con data e stato; si
/// può aprire e consultare una versione, non ripristinarla.
class StoricoVersioniPage extends StatefulWidget {
  const StoricoVersioniPage({
    super.key,
    required this.piani,
    required this.obiettivi,
    required this.pazienteId,
    this.nomePaziente,
  });

  final PianiRepository piani;
  final ObiettiviRepository obiettivi;
  final String pazienteId;
  final String? nomePaziente;

  @override
  State<StoricoVersioniPage> createState() => _StoricoVersioniPageState();
}

class _StoricoVersioniPageState extends State<StoricoVersioniPage> {
  bool _caricamento = true;
  String? _errore;
  List<VersionePiano> _versioni = [];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final v = await widget.piani.versioni(widget.pazienteId);
      if (!mounted) return;
      setState(() {
        _versioni = v;
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    return Scaffold(
      appBar: AppBar(title: const Text('Versioni del piano')),
      body: SafeArea(
        child: _caricamento
            ? const CaricamentoView()
            : _errore != null
            ? ErroreView(messaggio: _errore!, onRiprova: _carica)
            : _versioni.isEmpty
            ? const StatoVuotoView(
                icona: Icons.history,
                titolo: 'Nessuna versione',
                messaggio:
                    'Quando salvi un piano, qui compare la sua versione.',
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final v in _versioni) ...[
                    RigaElenco(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => VersionePianoPage(
                            piani: widget.piani,
                            obiettivi: widget.obiettivi,
                            pazienteId: widget.pazienteId,
                            versione: v,
                          ),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: v.stato == StatoPiano.corrente
                            ? c.primarioTonale
                            : c.bordo,
                        child: Text('${v.versione}'),
                      ),
                      titolo: 'Versione ${v.versione} · ${v.stato.etichetta}',
                      sottotitolo: v.creatoIl == null
                          ? null
                          : 'Salvata il ${_data(v.creatoIl!.toLocal())}'
                                '${v.dataInizio == null ? '' : ' · dal ${_data(v.dataInizio!)}'}',
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Una versione del piano, da consultare (non si modifica né si ripristina).
class VersionePianoPage extends StatefulWidget {
  const VersionePianoPage({
    super.key,
    required this.piani,
    required this.obiettivi,
    required this.pazienteId,
    required this.versione,
  });

  final PianiRepository piani;
  final ObiettiviRepository obiettivi;
  final String pazienteId;
  final VersionePiano versione;

  @override
  State<VersionePianoPage> createState() => _VersionePianoPageState();
}

class _VersionePianoPageState extends State<VersionePianoPage> {
  bool _caricamento = true;
  String? _errore;
  PianoAlimentare? _piano;
  Obiettivi? _obiettivi;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final r = await Future.wait([
        widget.piani.versione(widget.versione.id),
        widget.obiettivi.corrente(widget.pazienteId),
      ]);
      if (!mounted) return;
      setState(() {
        _piano = r[0] as PianoAlimentare;
        _obiettivi = r[1] as Obiettivi?;
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Versione ${widget.versione.versione} · ${widget.versione.stato.etichetta}',
        ),
      ),
      body: SafeArea(
        child: _caricamento
            ? const CaricamentoView()
            : _errore != null
            ? ErroreView(messaggio: _errore!, onRiprova: _carica)
            : PianoSolaLettura(piano: _piano!, obiettivi: _obiettivi),
      ),
    );
  }
}
