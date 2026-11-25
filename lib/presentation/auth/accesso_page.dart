import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';
import '../../domain/regole/validazione.dart';
import '../../domain/repository/auth_repository.dart';
import '../comuni/componenti.dart';
import '../comuni/controlli.dart';

/// Accesso con email e password (UC_GA_2, RF_GA_2). Dopo l'accesso il router
/// apre la home del ruolo; con una sessione valida questa schermata non
/// compare (il router salta direttamente alla home).
class AccessoPage extends StatefulWidget {
  const AccessoPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<AccessoPage> createState() => _AccessoPageState();
}

class _AccessoPageState extends State<AccessoPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _erroreEmail;
  String? _errorePassword;
  ErroreAuth? _errore;
  bool _inCorso = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _accedi() async {
    final erroreEmail = Validazione.email(_email.text);
    final errorePassword = _password.text.isEmpty
        ? 'Inserisci la password.'
        : null;
    setState(() {
      _erroreEmail = erroreEmail;
      _errorePassword = errorePassword;
      _errore = null;
    });
    if (erroreEmail != null || errorePassword != null) return;

    setState(() => _inCorso = true);
    try {
      // In caso di successo il router cambia schermata da solo.
      await widget.dip.auth.accedi(
        email: _email.text,
        password: _password.text,
      );
    } on ErroreAuth catch (e) {
      // I campi restano compilati: l'utente corregge e riprova.
      if (mounted) setState(() => _errore = e);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final credenzialiErrate = _errore?.codice == 'invalid_credentials';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: IconaTonale(icona: Icons.restaurant, dimensione: 72),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    Testi.nomeApp,
                    textAlign: TextAlign.center,
                    style: testo.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Il tuo percorso nutrizionale, pasto dopo pasto.',
                    textAlign: TextAlign.center,
                    style: testo.bodyMedium?.copyWith(
                      color: context.colori.testoSecondario,
                    ),
                  ),
                  const SizedBox(height: 32),
                  CampoTesto(
                    controller: _email,
                    etichetta: 'Email',
                    errore: _erroreEmail,
                    tastiera: TextInputType.emailAddress,
                    suggerimentiAutofill: const [AutofillHints.email],
                    azioneTastiera: TextInputAction.next,
                    onCambiato: (_) => setState(() => _erroreEmail = null),
                  ),
                  const SizedBox(height: 12),
                  CampoPassword(
                    controller: _password,
                    errore: _errorePassword,
                    azioneTastiera: TextInputAction.done,
                    onInvio: _accedi,
                    onCambiato: (_) => setState(() => _errorePassword = null),
                  ),
                  if (_errore != null) ...[
                    const SizedBox(height: 12),
                    MessaggioErrore(
                      messaggio: _errore!.messaggio,
                      onRiprova: _errore!.eRete ? _accedi : null,
                    ),
                  ],
                  const SizedBox(height: 16),
                  PulsantePrimario(
                    etichetta: 'Accedi',
                    onPressed: _accedi,
                    inCorso: _inCorso,
                  ),
                  const SizedBox(height: 8),
                  // Dopo credenziali errate il recupero password è in evidenza.
                  credenzialiErrate
                      ? FilledButton.tonal(
                          onPressed: () => context.go(Rotte.recuperoPassword),
                          child: const Text(Testi.passwordDimenticata),
                        )
                      : TextButton(
                          onPressed: () => context.go(Rotte.recuperoPassword),
                          child: const Text(Testi.passwordDimenticata),
                        ),
                  TextButton(
                    onPressed: () => context.go(Rotte.registrazione),
                    child: const Text(Testi.nonHaiAccount),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
