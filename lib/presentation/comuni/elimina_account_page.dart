import 'package:material_ui/material_ui.dart';

import '../../core/dipendenze.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/pazienti_repository.dart';
import 'controlli.dart';

/// Eliminazione dell'account su richiesta (UC_GA_5, RF_GA_7, GDPR art. 17).
/// Spiega le conseguenze e chiede di scrivere ELIMINA prima di procedere.
/// La cancellazione vera la fa la RPC `elimina_account` (005): per le scelte
/// vedi docs/decisioni-sviluppo.md.
class EliminaAccountPage extends StatefulWidget {
  const EliminaAccountPage({super.key, required this.dip});

  final Dipendenze dip;

  /// Parola da scrivere per confermare.
  static const parolaConferma = 'ELIMINA';

  @override
  State<EliminaAccountPage> createState() => _EliminaAccountPageState();
}

class _EliminaAccountPageState extends State<EliminaAccountPage> {
  final _conferma = TextEditingController();
  bool _inCorso = false;
  String? _errore;
  bool _erroreDiRete = false;
  int? _pazienti; // solo nutrizionista: pazienti collegati o archiviati

  bool get _nutrizionista => widget.dip.auth.ruolo == Ruolo.nutrizionista;
  bool get _confermato =>
      _conferma.text.trim() == EliminaAccountPage.parolaConferma;

  @override
  void initState() {
    super.initState();
    _conferma.addListener(() => setState(() {}));
    if (_nutrizionista) _contaPazienti();
  }

  @override
  void dispose() {
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _contaPazienti() async {
    try {
      final stato = await widget.dip.abbonamento.stato();
      if (mounted) setState(() => _pazienti = stato.pazientiCollegatiTotali);
    } on ErroreOperazione {
      // Il conteggio è solo informativo: il testo vale comunque.
    }
  }

  Future<void> _elimina() async {
    if (!_confermato) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _inCorso = true;
      _errore = null;
    });
    try {
      // A cancellazione riuscita la sessione si chiude e il router porta
      // all'accesso: il messaggio resta visibile sul livello superiore.
      await widget.dip.profilo.eliminaAccount();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Il tuo account e i tuoi dati sono stati eliminati.'),
        ),
      );
    } on ErroreOperazione catch (e) {
      if (mounted) {
        setState(() {
          _errore = e.messaggio;
          _erroreDiRete = e.codice == 'rete';
        });
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Elimina account')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ColoriCenato.errore.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ColoriCenato.errore.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: ColoriCenato.errore,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Questa azione è definitiva',
                              style: testo.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._nutrizionista
                          ? _conseguenzeNutrizionista()
                          : _conseguenzePaziente(),
                      const SizedBox(height: 4),
                      const Text('Non è possibile annullare.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CampoTesto(
                  controller: _conferma,
                  etichetta:
                      'Scrivi ${EliminaAccountPage.parolaConferma} per confermare',
                  maiuscolo: true,
                  azioneTastiera: TextInputAction.done,
                  abilitato: !_inCorso,
                ),
                if (_errore != null) ...[
                  const SizedBox(height: 12),
                  MessaggioErrore(
                    messaggio: _errore!,
                    onRiprova: _erroreDiRete ? _elimina : null,
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('conferma-elimina'),
                    style: FilledButton.styleFrom(
                      backgroundColor: ColoriCenato.errore,
                    ),
                    onPressed: _confermato && !_inCorso ? _elimina : null,
                    child: _inCorso
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Elimina definitivamente'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _inCorso
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: const Text('Annulla'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _punti(List<String> voci) => [
    for (final v in voci)
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(v)),
          ],
        ),
      ),
  ];

  List<Widget> _conseguenzePaziente() => _punti(const [
    'Cancelliamo il tuo account e tutti i tuoi dati: profilo, piano, check-in, peso, commenti e visite.',
    'Il tuo nutrizionista non vedrà più nulla di te. Nel suo elenco resterà '
        'soltanto una riga "Account eliminato", senza alcun dato personale.',
    'Potrai creare un nuovo account in qualsiasi momento, ma non recupererai i dati.',
  ]);

  List<Widget> _conseguenzeNutrizionista() => _punti([
    'Cancelliamo il tuo account, i tuoi piani, gli inviti, le visite, i commenti e le disponibilità.',
    if (_pazienti != null && _pazienti! > 0)
      'Hai $_pazienti ${_pazienti == 1 ? 'paziente' : 'pazienti'} (anche archiviati): '
          'verrà cancellato anche tutto ciò che li riguarda in Cenato (piani, check-in, peso, commenti, visite).'
    else
      'Se hai pazienti collegati o archiviati, verrà cancellato anche tutto ciò che li riguarda in Cenato '
          '(piani, check-in, peso, commenti, visite).',
    'Gli account dei tuoi pazienti restano: non saranno più collegati a te e '
        'potranno accettare l\'invito di un altro nutrizionista.',
    'Se vuoi conservare qualcosa, fallo prima: dopo non sarà più possibile.',
  ]);
}
