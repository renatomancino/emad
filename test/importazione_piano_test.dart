import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/domain/modelli/alimento.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';
import 'package:cenato/domain/modelli/riga_csv_piano.dart';
import 'package:cenato/domain/regole/importazione_piano.dart';

/// Regole dell'importazione (RF_GP_11, UC_GP_5): confronto dei nomi,
/// abbinamento automatico solo con nomi identici, costruzione della bozza.
Alimento _a(String nome, {String? id, double? kcal = 100}) => Alimento(
  id: id,
  nome: nome,
  kcal100g: kcal,
  proteine100g: 1,
  carboidrati100g: 1,
  grassi100g: 1,
  fonte: FonteAlimento.personalizzato,
);

RigaCsvPiano _r(
  int numero,
  int giorno,
  TipoPasto pasto,
  String alimento, [
  double quantita = 100,
]) => RigaCsvPiano(
  numero: numero,
  giorno: giorno,
  pasto: pasto,
  alimento: alimento,
  quantitaG: quantita,
);

void main() {
  test('i nomi si confrontano senza maiuscole, accenti, spazi e apostrofi', () {
    expect(
      normalizzaNome('  Fiocchi  d’Avena '),
      normalizzaNome("fiocchi d'avena"),
    );
    expect(normalizzaNome('Caffè'), normalizzaNome('caffe'));
    expect(normalizzaNome('Riso'), isNot(normalizzaNome('Riso basmati')));
  });

  group('Abbinamento automatico: solo nomi identici', () {
    test('sceglie il primo identico e completo', () {
      final scelto = corrispondenzaEsatta('pane integrale', [
        _a('Pane integrale a fette', id: '1'),
        _a('Pane Integrale', id: '2'),
        _a('Pane integrale', id: '3'),
      ]);
      expect(scelto?.id, '2');
    });

    test('un nome solo simile non si abbina', () {
      expect(corrispondenzaEsatta('Riso', [_a('Riso basmati')]), isNull);
    });

    test('un alimento senza tutti i valori non si abbina', () {
      expect(corrispondenzaEsatta('Mela', [_a('Mela', kcal: null)]), isNull);
    });
  });

  test('la bozza raggruppa per giorno e pasto, in ordine (UC_GP_5)', () {
    final latte = _a('Latte', id: 'l');
    final riso = _a('Riso', id: 'r');
    final bozza = costruisciBozza([
      (_r(2, 2, TipoPasto.cena, 'Riso', 80), riso),
      (_r(3, 1, TipoPasto.pranzo, 'Riso', 90), riso),
      (_r(4, 1, TipoPasto.colazione, 'Latte', 200), latte),
      (_r(5, 1, TipoPasto.pranzo, 'Latte', 50), latte),
    ], dataInizio: DateTime(2026, 11, 30));

    expect(bozza.stato, StatoPiano.bozza);
    expect(bozza.id, isNull);
    expect(bozza.dataInizio, DateTime(2026, 11, 30));
    expect(bozza.giorni.map((g) => g.giornoSettimana), [1, 2]);
    final lunedi = bozza.giorni.first;
    expect(lunedi.pasti.map((p) => p.tipo), [
      TipoPasto.colazione,
      TipoPasto.pranzo,
    ]);
    expect(lunedi.pasti.last.orario, '13:00');
    // Dentro il pasto resta l'ordine del file.
    expect(lunedi.pasti.last.voci.map((v) => (v.alimento.id, v.quantitaG)), [
      ('r', 90.0),
      ('l', 50.0),
    ]);
  });
}
