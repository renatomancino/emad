import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/core/config/env.dart';
import 'package:cenato/main.dart';

/// Costruisce un finto JWT con il ruolo indicato (solo per i test).
String _jwt(String role) {
  String parte(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${parte({'alg': 'HS256'})}.${parte({'role': role})}.firma';
}

void main() {
  group('Avvio dell\'app', () {
    testWidgets('mostra un messaggio chiaro se .env manca', (tester) async {
      await tester.pumpWidget(
        const CenatoErroreApp(messaggio: 'File .env non trovato.'),
      );

      expect(find.text('Configurazione mancante'), findsOneWidget);
      expect(find.text('File .env non trovato.'), findsOneWidget);
    });
  });

  group('EnvConfig.fromMap', () {
    test('accetta URL https e chiave anon', () {
      final config = EnvConfig.fromMap({
        'SUPABASE_URL': 'https://abcd1234.supabase.co',
        'SUPABASE_ANON_KEY': _jwt('anon'),
      });

      expect(config.supabaseUrl, 'https://abcd1234.supabase.co');
    });

    test('segnala le variabili mancanti', () {
      expect(
        () => EnvConfig.fromMap({}),
        throwsA(
          isA<EnvConfigException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL, SUPABASE_ANON_KEY'),
          ),
        ),
      );
    });

    test('rifiuta i valori segnaposto di .env.example', () {
      expect(
        () => EnvConfig.fromMap({
          'SUPABASE_URL': 'https://tuo-progetto.supabase.co',
          'SUPABASE_ANON_KEY': 'inserisci-qui-la-chiave-anon',
        }),
        throwsA(isA<EnvConfigException>()),
      );
    });

    test('rifiuta la chiave service_role', () {
      for (final chiave in [_jwt('service_role'), 'sb_secret_abc123']) {
        expect(
          () => EnvConfig.fromMap({
            'SUPABASE_URL': 'https://abcd1234.supabase.co',
            'SUPABASE_ANON_KEY': chiave,
          }),
          throwsA(isA<EnvConfigException>()),
        );
      }
    });

    test('rifiuta un URL non https', () {
      expect(
        () => EnvConfig.fromMap({
          'SUPABASE_URL': 'http://abcd1234.supabase.co',
          'SUPABASE_ANON_KEY': _jwt('anon'),
        }),
        throwsA(isA<EnvConfigException>()),
      );
    });
  });
}
