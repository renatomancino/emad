import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/config/env.dart';
import 'core/costanti/testi.dart';
import 'core/dipendenze.dart';
import 'core/router/router.dart';
import 'core/tema/tema.dart';
import 'data/alimenti_repository.dart';
import 'data/finto/dipendenze_finte.dart';
import 'data/open_food_facts/open_food_facts_client.dart';
import 'data/supabase/alimenti_cache_supabase.dart';
import 'data/supabase/collegamento_repository_supabase.dart';
import 'data/supabase/modelli_repository_supabase.dart';
import 'data/supabase/obiettivi_repository_supabase.dart';
import 'data/supabase/pazienti_repository_supabase.dart';
import 'data/supabase/piani_repository_supabase.dart';
import 'data/supabase/profilo_repository_supabase.dart';
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
    runApp(CenatoApp(dip: DipendenzeFinte(ruolo: Ruolo.daDb(_ruoloFinto)).dip));
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
  final auth = SupabaseAuthRepository(db);
  runApp(
    CenatoApp(
      dip: Dipendenze(
        auth: auth,
        pazienti: PazientiRepositorySupabase(db),
        abbonamento: AbbonamentoRepositorySupabase(db),
        collegamento: CollegamentoRepositorySupabase(db),
        profilo: ProfiloRepositorySupabase(db, auth),
        alimenti: AlimentiRepositoryImpl(
          cache: AlimentiCacheSupabase(db),
          online: OpenFoodFactsClient(),
        ),
        obiettivi: ObiettiviRepositorySupabase(db),
        piani: PianiRepositorySupabase(db),
        modelli: ModelliRepositorySupabase(db),
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
