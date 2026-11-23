import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

/// Inizializzazione del client Supabase (RNF_I_2, RNF_I_5).
///
/// Usa solo URL e chiave pubblica letti da `.env`: la chiave `service_role`
/// non è mai presente nell'app. I dati sono protetti dalle policy RLS.
class SupabaseService {
  const SupabaseService._();

  static Future<void> inizializza(EnvConfig config) async {
    // supabase_flutter 2.18 chiama "publishableKey" la chiave pubblica:
    // accetta sia la chiave anon (JWT) sia il formato sb_publishable_.
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  }

  /// Client da usare nei repository di `lib/data`.
  static SupabaseClient get client => Supabase.instance.client;
}
