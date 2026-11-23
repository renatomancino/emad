import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';

/// Schermata PROVVISORIA di accesso e registrazione (solo sviluppo).
///
/// Serve a provare Supabase Auth e la tabella `profili` (scheda "Progetto
/// Supabase (UE) e autenticazione"). Le vere schermate di registrazione con
/// consenso (UC_GA_1, RF_GA_6), accesso (UC_GA_2) e recupero password
/// (UC_GA_4) sono nella fase 1 e sostituiranno questa.
class ProvaAuthPage extends StatefulWidget {
  const ProvaAuthPage({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<ProvaAuthPage> createState() => _ProvaAuthPageState();
}

class _ProvaAuthPageState extends State<ProvaAuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _nome = TextEditingController();
  bool _inCorso = false;
  String? _esito;
  bool _esitoErrore = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _nome.dispose();
    super.dispose();
  }

  Future<void> _esegui(Future<String> Function() azione) async {
    setState(() {
      _inCorso = true;
      _esito = null;
    });
    try {
      final messaggio = await azione();
      if (!mounted) return;
      setState(() {
        _esito = messaggio;
        _esitoErrore = false;
      });
    } on ErroreAuth catch (e) {
      if (!mounted) return;
      // I campi restano compilati: l'utente può correggere e riprovare.
      setState(() {
        _esito = e.messaggio;
        _esitoErrore = true;
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<String> _registra(Ruolo ruolo) async {
    final nome = _nome.text.trim().isEmpty
        ? ruolo.etichetta
        : _nome.text.trim();
    final autenticato = await widget.auth.registra(
      email: _email.text,
      password: _password.text,
      ruolo: ruolo,
      nome: nome,
    );
    return autenticato
        ? 'Account creato come ${ruolo.etichetta}.'
        : 'Account creato come ${ruolo.etichetta}. Conferma l\'email e poi '
              'accedi.';
  }

  Future<String> _accedi() async {
    await widget.auth.accedi(email: _email.text, password: _password.text);
    final profilo = widget.auth.profilo;
    return 'Accesso riuscito. Ruolo letto dal profilo: '
        '${profilo?.ruolo.etichetta ?? 'non trovato'}.';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Cenato · accesso di prova')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: tema.colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Schermata provvisoria per lo sviluppo. Registrazione con '
                  'consenso e accesso definitivi arrivano nella fase 1.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nome,
              decoration: const InputDecoration(
                labelText: 'Nome (solo per la registrazione)',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _inCorso ? null : () => _esegui(_accedi),
              child: const Text('Accedi'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _inCorso
                  ? null
                  : () => _esegui(() => _registra(Ruolo.nutrizionista)),
              child: const Text('Registra come nutrizionista'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _inCorso
                  ? null
                  : () => _esegui(() => _registra(Ruolo.paziente)),
              child: const Text('Registra come paziente'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(Rotte.recuperoPassword),
              child: const Text(Testi.passwordDimenticata),
            ),
            TextButton(
              onPressed: () => context.go(Rotte.registrazione),
              child: const Text(Testi.nonHaiAccount),
            ),
            const SizedBox(height: 12),
            if (_inCorso) const Center(child: CircularProgressIndicator()),
            if (_esito != null)
              Text(
                _esito!,
                key: const Key('esito'),
                style: tema.textTheme.bodyLarge?.copyWith(
                  color: _esitoErrore
                      ? tema.colorScheme.error
                      : tema.colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
