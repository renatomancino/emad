import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/env.dart';
import 'core/costanti/testi.dart';
import 'core/dipendenze.dart';
import 'core/router/router.dart';
import 'core/tema/tema.dart';
import 'data/finto/auth_repository_finto.dart';
import 'data/finto/pazienti_repository_finto.dart';
import 'data/supabase/pazienti_repository_supabase.dart';
import 'data/supabase/supabase_auth_repository.dart';
import 'data/supabase/supabase_service.dart';
import 'domain/modelli/profilo.dart';
import 'presentation/comuni/errore_configurazione_page.dart';

/// Ruolo simulato per provare la navigazione senza Supabase:
/// `flutter run --dart-define=CENATO_RUOLO_FINTO=paziente` (o `nutrizionista`).
const _ruoloFinto = String.fromEnvironment('CENATO_RUOLO_FINTO');

/// Punto di ingresso: legge `.env`, inizializza Supabase e avvia l'app.
/// Se la configurazione non è valida mostra un messaggio chiaro invece
/// di chiudersi (RNF_A_2).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_ruoloFinto.isNotEmpty) {
    final dati = DatiFinti();
    runApp(
      CenatoApp(
        dip: Dipendenze(
          auth: AuthRepositoryFinto(ruoloIniziale: Ruolo.daDb(_ruoloFinto)),
          pazienti: PazientiRepositoryFinto(dati),
          abbonamento: AbbonamentoRepositoryFinto(dati),
        ),
      ),
    );
    return;
  }

  try {
    final config = await EnvConfig.load();
    await SupabaseService.inizializza(config);
  } on EnvConfigException catch (e) {
    runApp(CenatoErroreApp(messaggio: e.message));
    return;
  } catch (e) {
    // Nessun dato sanitario qui: si registra solo il tipo di errore.
    debugPrint('Inizializzazione di Supabase non riuscita: ${e.runtimeType}');
    runApp(
      const CenatoErroreApp(
        messaggio:
            'Impossibile collegarsi a Supabase.\n'
            'Controlla SUPABASE_URL e SUPABASE_ANON_KEY nel file .env.',
      ),
    );
    return;
  }

  final db = SupabaseService.client;
  runApp(
    CenatoApp(
      dip: Dipendenze(
        auth: SupabaseAuthRepository(db),
        pazienti: PazientiRepositorySupabase(db),
        abbonamento: AbbonamentoRepositorySupabase(db),
      ),
    ),
  );
}

/// Radice dell'app: tema e router con reindirizzamento per ruolo.
class CenatoApp extends StatefulWidget {
  const CenatoApp({super.key, required this.dip});

  final Dipendenze dip;

  @override
  State<CenatoApp> createState() => _CenatoAppState();
}

class _CenatoAppState extends State<CenatoApp> {
  late final GoRouter _router = creaRouter(widget.dip);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: Testi.nomeApp,
      debugShowCheckedModeBanner: false,
      theme: temaCenato(),
      routerConfig: _router,
    );
  }
}

/// App minima mostrata quando `.env` manca o non è valido.
class CenatoErroreApp extends StatelessWidget {
  const CenatoErroreApp({super.key, required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Testi.nomeApp,
      debugShowCheckedModeBanner: false,
      theme: temaCenato(),
      home: SchermataErroreConfigurazione(messaggio: messaggio),
    );
  }
}
