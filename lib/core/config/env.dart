import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configurazione del back-end letta dal file `.env` (RNF_I_5).
///
/// Il file `.env` non è versionato: si crea copiando `.env.example`.
/// Contiene solo l'URL del progetto Supabase e la chiave pubblica "anon":
/// la chiave `service_role` non deve mai arrivare nell'app.
class EnvConfig {
  const EnvConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  /// Nome del file (asset) da cui si leggono le variabili.
  static const String fileName = '.env';

  static const String keyUrl = 'SUPABASE_URL';
  static const String keyAnonKey = 'SUPABASE_ANON_KEY';

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Carica `.env` e controlla i valori.
  ///
  /// Lancia [EnvConfigException] con un messaggio in italiano se il file
  /// manca, è vuoto, contiene ancora i segnaposto di `.env.example`
  /// oppure contiene una chiave segreta.
  static Future<EnvConfig> load() async {
    try {
      await dotenv.load(fileName: fileName);
    } on FileNotFoundError {
      throw const EnvConfigException(
        'File .env non trovato.\n'
        'Copia .env.example in .env, inserisci i valori del progetto '
        'Supabase e riavvia l\'app.',
      );
    } on EmptyEnvFileError {
      throw const EnvConfigException(
        'Il file .env è vuoto.\n'
        'Inserisci SUPABASE_URL e SUPABASE_ANON_KEY (vedi .env.example).',
      );
    }
    return fromMap(dotenv.env);
  }

  /// Valida le variabili già lette. Separato da [load] per poterlo testare.
  static EnvConfig fromMap(Map<String, String> env) {
    final url = env[keyUrl]?.trim() ?? '';
    final anonKey = env[keyAnonKey]?.trim() ?? '';

    final mancanti = [
      if (url.isEmpty) keyUrl,
      if (anonKey.isEmpty) keyAnonKey,
    ];
    if (mancanti.isNotEmpty) {
      throw EnvConfigException(
        'Nel file .env manca: ${mancanti.join(', ')}.\n'
        'Copia i nomi da .env.example e inserisci i valori.',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) {
      throw const EnvConfigException(
        'SUPABASE_URL non è valido: deve essere l\'indirizzo https del '
        'progetto, ad esempio https://abcd1234.supabase.co.',
      );
    }

    // Valori lasciati come in .env.example.
    if (uri.host.startsWith('tuo-progetto') ||
        anonKey.startsWith('inserisci-qui')) {
      throw const EnvConfigException(
        'Il file .env contiene ancora i valori di esempio.\n'
        'Inserisci URL e chiave anon del progetto Supabase.',
      );
    }

    if (isSecretKey(anonKey)) {
      throw const EnvConfigException(
        'SUPABASE_ANON_KEY contiene una chiave segreta (service_role).\n'
        'Nell\'app va solo la chiave pubblica "anon": sostituiscila subito.',
      );
    }

    return EnvConfig(supabaseUrl: url, supabaseAnonKey: anonKey);
  }

  /// `true` se [key] è una chiave segreta di Supabase: nuovo formato
  /// `sb_secret_...` oppure JWT con ruolo `service_role`.
  static bool isSecretKey(String key) {
    if (key.startsWith('sb_secret_')) return true;
    final parti = key.split('.');
    if (parti.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parti[1])),
      );
      final ruolo = (jsonDecode(payload) as Map<String, dynamic>)['role'];
      return ruolo == 'service_role';
    } on FormatException {
      return false;
    }
  }
}

/// Errore di configurazione con un messaggio da mostrare all'utente.
class EnvConfigException implements Exception {
  const EnvConfigException(this.message);

  final String message;

  @override
  String toString() => 'EnvConfigException: $message';
}
