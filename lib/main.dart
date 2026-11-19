import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';

/// Punto di ingresso: legge `.env`, inizializza Supabase e avvia l'app.
/// Se la configurazione non è valida mostra un messaggio chiaro invece
/// di chiudersi (RNF_A_2).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? erroreConfigurazione;
  try {
    final config = await EnvConfig.load();
    // supabase_flutter 2.18 chiama "publishableKey" la chiave pubblica:
    // accetta sia la chiave anon (JWT) sia il nuovo formato sb_publishable_.
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } on EnvConfigException catch (e) {
    erroreConfigurazione = e.message;
  } catch (e) {
    // Nessun dato sanitario qui: si registra solo il tipo di errore.
    debugPrint('Inizializzazione di Supabase non riuscita: ${e.runtimeType}');
    erroreConfigurazione =
        'Impossibile collegarsi a Supabase.\n'
        'Controlla SUPABASE_URL e SUPABASE_ANON_KEY nel file .env.';
  }

  runApp(CenatoApp(erroreConfigurazione: erroreConfigurazione));
}

/// Radice dell'app. Tema e router arriveranno in `lib/core`.
class CenatoApp extends StatelessWidget {
  const CenatoApp({super.key, this.erroreConfigurazione});

  /// Messaggio da mostrare se `.env` manca o non è valido; `null` se è tutto ok.
  final String? erroreConfigurazione;

  @override
  Widget build(BuildContext context) {
    final errore = erroreConfigurazione;
    return MaterialApp(
      title: 'Cenato',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: errore == null
          ? const SchermataProva()
          : SchermataErroreConfigurazione(messaggio: errore),
    );
  }
}

/// Schermata provvisoria di avvio: conferma che l'app parte ed è collegata.
class SchermataProva extends StatelessWidget {
  const SchermataProva({super.key});

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.restaurant,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('Cenato', style: testo.displaySmall),
                const SizedBox(height: 8),
                Text(
                  'Il tuo percorso nutrizionale, pasto dopo pasto.',
                  style: testo.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Text(
                  'Configurazione caricata: app pronta.',
                  style: testo.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mostrata quando `.env` manca o non è valido.
class SchermataErroreConfigurazione extends StatelessWidget {
  const SchermataErroreConfigurazione({super.key, required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Configurazione mancante',
                  style: testo.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  messaggio,
                  style: testo.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Istruzioni nel README.md del repository.',
                    style: testo.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
