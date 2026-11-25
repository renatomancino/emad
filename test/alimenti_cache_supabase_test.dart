import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/data/supabase/alimenti_cache_supabase.dart';
import 'package:cenato/domain/modelli/alimento.dart';

Alimento _a(String id, String nome) => Alimento(
  id: id,
  nome: nome,
  kcal100g: 1,
  proteine100g: 1,
  carboidrati100g: 1,
  grassi100g: 1,
  fonte: FonteAlimento.openFoodFacts,
);

void main() {
  group('Supporto della cache su Supabase', () {
    test('escapeLike rende letterali %, _ e backslash', () {
      expect(
        AlimentiCacheSupabase.escapeLike('100%_pane\\x'),
        r'100\%\_pane\\x',
      );
      expect(AlimentiCacheSupabase.escapeLike('pane'), 'pane');
    });

    test('ordina: preferiti, poi i più recenti, poi il nome', () {
      final ordinati = AlimentiCacheSupabase.ordina(
        [
          _a('1', 'Zucchero'),
          _a('2', 'Pane'),
          _a('3', 'Latte'),
          _a('4', 'Riso'),
        ],
        {
          '1': (preferito: true, ultimoUso: DateTime(2026, 1, 1)),
          '2': (preferito: false, ultimoUso: DateTime(2026, 3, 1)),
          '3': (preferito: false, ultimoUso: DateTime(2026, 2, 1)),
        },
      );
      expect(ordinati.map((a) => a.nome), [
        'Zucchero',
        'Pane',
        'Latte',
        'Riso',
      ]);
      expect(ordinati.first.preferito, isTrue);
      expect(ordinati.last.preferito, isFalse);
    });

    test('Alimento.daRiga legge numeri come num o come testo', () {
      final a = Alimento.daRiga({
        'id': 'x',
        'nome': 'Pane',
        'marca': null,
        'codice_barre': '1234567890123',
        'kcal_100g': 250.5,
        'proteine_100g': '8.2',
        'carboidrati_100g': 49,
        'grassi_100g': '1.5',
        'fonte': 'open_food_facts',
      }, preferito: true);
      expect(a.kcal100g, 250.5);
      expect(a.proteine100g, 8.2);
      expect(a.carboidrati100g, 49);
      expect(a.grassi100g, 1.5);
      expect(a.fonte, FonteAlimento.openFoodFacts);
      expect(a.preferito, isTrue);
      expect(a.completo, isTrue);
    });

    test('perInserimento usa i nomi delle colonne di alimenti', () {
      final riga = _a('1', 'Pane').perInserimento(creatoDa: 'utente-1');
      expect(
        riga.keys,
        containsAll([
          'nome',
          'marca',
          'codice_barre',
          'kcal_100g',
          'proteine_100g',
          'carboidrati_100g',
          'grassi_100g',
          'fonte',
          'creato_da',
        ]),
      );
      expect(riga['fonte'], 'open_food_facts');
      expect(riga['creato_da'], 'utente-1');
    });
  });
}
