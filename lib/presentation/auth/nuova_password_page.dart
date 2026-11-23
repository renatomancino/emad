import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../comuni/controlli.dart';

/// Scelta della nuova password dopo il rientro dal link ricevuto via email
/// (UC_GA_4, passo 5). Il router porta qui chi apre il link di recupero.
class NuovaPasswordPage extends StatefulWidget {
  const NuovaPasswordPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<NuovaPasswordPage> createState() => _NuovaPasswordPageState();
}

class _NuovaPasswordPageState extends State<NuovaPasswordPage> {
  final _password = TextEditingController();
  final _conferma = TextEditingController();
  String? _errorePassword;
  String? _erroreConferma;
  ErroreAuth? _errore;
  bool _inCorso = false;

  @override
  void dispose() {
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final errorePassword = Validazione.password(_password.text);
    final erroreConferma = Validazione.conferma(_password.text, _conferma.text);
    setState(() {
      _errorePassword = errorePassword;
      _erroreConferma = erroreConferma;
      _errore = null;
    });
    if (errorePassword != null || erroreConferma != null) return;

    setState(() => _inCorso = true);
    try {
      // Dopo il salvataggio il router porta alla home del ruolo.
      await widget.dip.auth.impostaNuovaPassword(_password.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password aggiornata.')));
      }
    } on ErroreAuth catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.riguardaPassword || e.codice == 'same_password') {
          _errorePassword = e.messaggio;
        } else {
          _errore = e;
        }
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final linkScaduto =
        _errore?.codice == 'session_not_found' || _errore?.codice == 'bad_jwt';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuova password'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Scegli una nuova password', style: testo.headlineSmall),
                const SizedBox(height: 16),
                CampoPassword(
                  controller: _password,
                  nuova: true,
                  etichetta: 'Nuova password',
                  errore: _errorePassword,
                  aiuto:
                      'Almeno ${Validazione.lunghezzaMinimaPassword} caratteri, con lettere e numeri.',
                  azioneTastiera: TextInputAction.next,
                  onCambiato: (_) => setState(() => _errorePassword = null),
                ),
                const SizedBox(height: 12),
                CampoPassword(
                  controller: _conferma,
                  nuova: true,
                  etichetta: 'Ripeti la password',
                  errore: _erroreConferma,
                  azioneTastiera: TextInputAction.done,
                  onInvio: _salva,
                  onCambiato: (_) => setState(() => _erroreConferma = null),
                ),
                if (_errore != null) ...[
                  const SizedBox(height: 12),
                  MessaggioErrore(
                    messaggio: _errore!.messaggio,
                    onRiprova: _errore!.eRete ? _salva : null,
                  ),
                ],
                const SizedBox(height: 16),
                PulsantePrimario(
                  etichetta: 'Salva la password',
                  onPressed: _salva,
                  inCorso: _inCorso,
                ),
                if (linkScaduto)
                  TextButton(
                    onPressed: () async {
                      await widget.dip.auth.esci();
                      if (context.mounted) context.go(Rotte.recuperoPassword);
                    },
                    child: const Text('Richiedi un nuovo link'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
