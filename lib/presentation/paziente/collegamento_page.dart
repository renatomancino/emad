import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/collegamento_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../comuni/componenti.dart';
import '../comuni/controlli.dart';
import '../comuni/stati_view.dart';

/// Inserimento del codice di invito da parte di un paziente non ancora
/// collegato (UC_GI_2, RF_GI_2): chi si è registrato ma deve ancora usare il
/// codice (email da confermare) e chi si è scollegato e riceve un nuovo
/// invito. Il collegamento passa SOLO dalla RPC `accetta_invito`.
///
/// Se alla registrazione è stato scritto un codice, viene usato da solo.
class CollegamentoPage extends StatefulWidget {
  const CollegamentoPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<CollegamentoPage> createState() => _CollegamentoPageState();
}

class _CollegamentoPageState extends State<CollegamentoPage> {
  final _codice = TextEditingController();
  String? _erroreCodice;
  String? _erroreGenerale;
  bool _erroreDiRete = false;
  AnteprimaInvito? _anteprima;
  bool _inCorso = false;
  bool _automatico = false;

  AuthRepository get _auth => widget.dip.auth;

  @override
  void initState() {
    super.initState();
    final pendente = _auth.codiceInvitoPendente;
    if (pendente != null) {
      _codice.text = pendente;
      _automatico = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _collegaDirettamente(),
      );
    }
  }

  @override
  void dispose() {
    _codice.dispose();
    super.dispose();
  }

  /// Usa il codice scritto alla registrazione senza chiedere altro.
  Future<void> _collegaDirettamente() async {
    await _accetta(mostraErroreSuCampo: true);
    if (mounted) setState(() => _automatico = false);
  }

  Future<void> _verifica() async {
    final formato = Validazione.codiceInvito(_codice.text);
    setState(() {
      _erroreCodice = formato;
      _erroreGenerale = null;
      _anteprima = null;
    });
    if (formato != null) return;

    setState(() => _inCorso = true);
    try {
      final anteprima = await widget.dip.collegamento.verifica(_codice.text);
      if (mounted) setState(() => _anteprima = anteprima);
    } on ErroreOperazione catch (e) {
      _mostraErrore(e.messaggio, rete: e.codice == 'rete');
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _accetta({bool mostraErroreSuCampo = false}) async {
    setState(() {
      _inCorso = true;
      _erroreGenerale = null;
      _erroreCodice = null;
    });
    try {
      await widget.dip.collegamento.accetta(_codice.text);
      // Dopo l'aggiornamento il router apre la sezione Oggi.
      await _auth.aggiornaCollegamento();
    } on ErroreLimitePiano catch (e) {
      _mostraErrore(e.messaggio);
    } on ErroreOperazione catch (e) {
      _mostraErrore(e.messaggio, rete: e.codice == 'rete');
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  void _mostraErrore(String messaggio, {bool rete = false}) {
    if (!mounted) return;
    setState(() {
      if (rete) {
        _erroreGenerale = messaggio;
        _erroreDiRete = true;
      } else {
        _erroreCodice = messaggio;
        _erroreDiRete = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_automatico && _inCorso) {
      return const Scaffold(
        body: CaricamentoView(
          messaggio: 'Ti sto collegando al tuo nutrizionista…',
        ),
      );
    }
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Il tuo nutrizionista'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: Testi.esci,
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.esci(),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Center(
                  child: IconaTonale(icona: Icons.link, dimensione: 72),
                ),
                const SizedBox(height: 16),
                Text(
                  'Collegati al tuo nutrizionista',
                  textAlign: TextAlign.center,
                  style: testo.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Non sei ancora collegato a un nutrizionista. Inserisci il '
                  'codice di invito che ti ha dato: serve per vedere il tuo '
                  'piano e fare il check-in dei pasti.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                CampoTesto(
                  controller: _codice,
                  etichetta: 'Codice di invito',
                  errore: _erroreCodice,
                  maiuscolo: true,
                  azioneTastiera: TextInputAction.done,
                  onInvio: _verifica,
                  onCambiato: (_) => setState(() {
                    _erroreCodice = null;
                    _anteprima = null;
                  }),
                ),
                if (_erroreGenerale != null) ...[
                  const SizedBox(height: 12),
                  MessaggioErrore(
                    messaggio: _erroreGenerale!,
                    onRiprova: _erroreDiRete
                        ? (_anteprima == null ? _verifica : _accetta)
                        : null,
                  ),
                ],
                const SizedBox(height: 16),
                if (_anteprima == null)
                  PulsantePrimario(
                    etichetta: 'Verifica il codice',
                    onPressed: _verifica,
                    inCorso: _inCorso,
                  )
                else ...[
                  BannerInvito(
                    nomeNutrizionista: _anteprima!.nomeNutrizionista,
                  ),
                  const SizedBox(height: 12),
                  PulsantePrimario(
                    etichetta: 'Conferma e collegati',
                    onPressed: _accetta,
                    inCorso: _inCorso,
                  ),
                ],
                const SizedBox(height: 24),
                TextButton(
                  key: const Key('elimina-account-da-collegamento'),
                  onPressed: () => context.push(Rotte.eliminaAccount),
                  child: const Text('Elimina il mio account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
