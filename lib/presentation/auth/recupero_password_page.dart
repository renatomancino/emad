import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../comuni/controlli.dart';

/// Recupero password (UC_GA_4, RF_GA_4): richiesta del link via email.
/// Il messaggio finale è lo STESSO sia che l'email esista sia di no, così non
/// si rivela chi ha un account (UC_GA_4, passo 4).
class RecuperoPasswordPage extends StatefulWidget {
  const RecuperoPasswordPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<RecuperoPasswordPage> createState() => _RecuperoPasswordPageState();
}

class _RecuperoPasswordPageState extends State<RecuperoPasswordPage> {
  final _email = TextEditingController();
  String? _erroreEmail;
  ErroreAuth? _errore;
  bool _inCorso = false;
  bool _inviata = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    final errore = Validazione.email(_email.text);
    setState(() {
      _erroreEmail = errore;
      _errore = null;
    });
    if (errore != null) return;

    setState(() => _inCorso = true);
    try {
      await widget.dip.auth.recuperaPassword(email: _email.text);
      if (mounted) setState(() => _inviata = true);
    } on ErroreAuth catch (e) {
      if (mounted) setState(() => _errore = e);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recupero password'),
        leading: IconButton(
          tooltip: 'Torna all\'accesso',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Rotte.accesso),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _inviata ? _conferma(testo) : _modulo(testo),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _modulo(TextTheme testo) => [
    Text('Hai dimenticato la password?', style: testo.headlineSmall),
    const SizedBox(height: 8),
    const Text(
      'Scrivi l\'email con cui ti sei registrato: ti mandiamo un link per '
      'scegliere una nuova password.',
    ),
    const SizedBox(height: 16),
    CampoTesto(
      controller: _email,
      etichetta: 'Email',
      errore: _erroreEmail,
      tastiera: TextInputType.emailAddress,
      suggerimentiAutofill: const [AutofillHints.email],
      azioneTastiera: TextInputAction.done,
      onInvio: _invia,
      onCambiato: (_) => setState(() => _erroreEmail = null),
    ),
    if (_errore != null) ...[
      const SizedBox(height: 12),
      MessaggioErrore(
        messaggio: _errore!.messaggio,
        onRiprova: _errore!.eRete ? _invia : null,
      ),
    ],
    const SizedBox(height: 16),
    PulsantePrimario(
      etichetta: 'Invia il link',
      onPressed: _invia,
      inCorso: _inCorso,
    ),
  ];

  List<Widget> _conferma(TextTheme testo) => [
    const SizedBox(height: 24),
    const Icon(
      Icons.mark_email_read_outlined,
      size: 64,
      color: ColoriCenato.primario,
    ),
    const SizedBox(height: 16),
    Text(
      'Controlla la tua email',
      key: const Key('recupero-inviato'),
      textAlign: TextAlign.center,
      style: testo.headlineSmall,
    ),
    const SizedBox(height: 12),
    const Text(
      'Se l\'indirizzo è registrato, tra poco riceverai un\'email con il link '
      'per scegliere una nuova password. Aprilo da questo telefono: ti riporta '
      'in Cenato. Il link vale per un tempo limitato; se non lo trovi, guarda '
      'anche tra la posta indesiderata.',
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => context.go(Rotte.accesso),
      child: const Text('Torna all\'accesso'),
    ),
  ];
}
