import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cenato/data/csv_piano_parser.dart';
import 'package:cenato/domain/modelli/piano_alimentare.dart';

/// Parser del CSV del piano (RF_GP_10, RF_GP_11, RNF_IN_4, UC_GP_5):
/// codifica UTF-8 con o senza BOM, separatore ";" o ",", decimali con la
/// virgola, errori per riga e colonna, errori del file intero.
Uint8List _bytes(String testo, {bool bom = false}) => Uint8List.fromList([
  if (bom) ...[0xEF, 0xBB, 0xBF],
  ...utf8.encode(testo),
]);

Uint8List _fixture(String nome) =>
    File('test/fixtures/$nome').readAsBytesSync();

const _intestazione = 'giorno;pasto;alimento;quantita_g;note';

/// Un file con l'intestazione standard e le righe [righe].
EsitoCsvPiano _leggi(List<String> righe) =>
    leggiCsvPiano(_bytes([_intestazione, ...righe].join('\n')));

/// Il messaggio dell'errore che riguarda il file intero.
String _erroreFile(Uint8List bytes) {
  try {
    leggiCsvPiano(bytes);
  } on ErroreFileCsv catch (e) {
    return e.messaggio;
  }
  return 'nessun errore';
}

void main() {
  group('File validi', () {
    test('file di esempio: BOM, ";" e decimali con la virgola', () {
      final esito = leggiCsvPiano(_fixture('piano_valido.csv'));

      expect(esito.separatore, ';');
      expect(esito.errate, isEmpty);
      expect(esito.righe, hasLength(5));
      final prima = esito.righe.first;
      expect(prima.numero, 2); // la riga 1 è l'intestazione
      expect(prima.giorno, 1);
      expect(prima.pasto, TipoPasto.colazione);
      expect(prima.alimento, 'Latte parzialmente scremato');
      expect(prima.quantitaG, 200);
      expect(esito.righe[3].quantitaG, 12.5);
      expect(esito.righe[3].note, 'a crudo');
      expect(esito.righe.last.giorno, 2);
    });

    test('separatore ",", senza BOM, valori tra virgolette', () {
      final esito = leggiCsvPiano(
        _bytes(
          'giorno,pasto,alimento,quantita_g,note\r\n'
          'Lunedì,Cena,"Pane, integrale",50,\r\n'
          'Lunedì,Cena,Olio,"12,5",\r\n'
          'Lunedì,Cena,Zucchine,12.5,\r\n',
        ),
      );

      expect(esito.separatore, ',');
      expect(esito.errate, isEmpty);
      expect(esito.righe[0].alimento, 'Pane, integrale');
      expect(esito.righe[1].quantitaG, 12.5);
      expect(esito.righe[2].quantitaG, 12.5);
    });

    test('intestazione in altro ordine, maiuscole e senza la colonna note', () {
      final esito = leggiCsvPiano(
        _bytes('Quantità_g; Alimento ;PASTO;Giorno\n80;Riso;pranzo;mar'),
      );

      expect(esito.errate, isEmpty);
      final riga = esito.righe.single;
      expect(
        (riga.giorno, riga.pasto, riga.alimento, riga.quantitaG, riga.note),
        (2, TipoPasto.pranzo, 'Riso', 80, ''),
      );
    });

    test('giorni e pasti scritti in modi diversi', () {
      final esito = _leggi([
        'lunedi;COLAZIONE;A;1',
        'Mar;Spuntino;B;1',
        '3;merenda;C;1',
        'DOMENICA ;Cena;D;1',
      ]);

      expect(esito.errate, isEmpty);
      expect(esito.righe.map((r) => r.giorno), [1, 2, 3, 7]);
      expect(esito.righe.map((r) => r.pasto), [
        TipoPasto.colazione,
        TipoPasto.spuntino,
        TipoPasto.merenda,
        TipoPasto.cena,
      ]);
    });

    test(
      'le righe vuote si saltano e la numerazione resta quella del file',
      () {
        final esito = _leggi([
          '',
          'Lun;Cena;A;10',
          ';;;;',
          'Lun;Cena;B;20',
          '',
        ]);

        expect(esito.errate, isEmpty);
        expect(esito.righe.map((r) => r.numero), [3, 5]);
      },
    );
  });

  group('Errori nelle righe (UC_GP_5, flusso "errori bloccanti")', () {
    test('file con 3 errori: le 3 righe errate, con colonna e motivo', () {
      final esito = leggiCsvPiano(_fixture('piano_con_errori.csv'));

      expect(esito.righe.map((r) => r.numero), [2, 4]);
      expect(esito.errate.map((r) => r.numero), [3, 5, 6]);
      expect(
        [
          for (final r in esito.errate)
            for (final e in r.errori) '${r.numero} ${e.colonna}: ${e.motivo}',
        ],
        [
          '3 quantita_g: Inserisci un numero, per esempio 150.',
          '5 giorno: "Lundì" non è un giorno della settimana.',
          '6 alimento: Manca il nome dell\'alimento.',
        ],
      );
    });

    test('più errori sulla stessa riga restano insieme', () {
      final riga = _leggi(['boh;brunch;;-1']).errate.single;

      expect(riga.errori.map((e) => e.colonna), [
        'giorno',
        'pasto',
        'alimento',
        'quantita_g',
      ]);
    });

    test('quantità zero, mancante o oltre il massimo', () {
      final esito = _leggi(['Lun;Cena;A;0', 'Lun;Cena;B;', 'Lun;Cena;C;6000']);

      expect(esito.righe, isEmpty);
      expect(esito.errate.map((r) => r.errori.single.motivo), [
        'La quantità deve essere maggiore di zero.',
        'Inserisci la quantità in grammi.',
        'La quantità può essere al massimo 5000 g.',
      ]);
    });

    test('virgola decimale senza virgolette con separatore ","', () {
      final esito = leggiCsvPiano(
        _bytes('giorno,pasto,alimento,quantita_g\nLun,Cena,Olio,12,5'),
      );

      expect(esito.righe, isEmpty);
      expect(esito.errate.single.errori.single.motivo, contains('virgolette'));
    });

    test('nome dell\'alimento troppo lungo', () {
      final riga = _leggi(['Lun;Cena;${'a' * 201};10']).errate.single;
      expect(riga.errori.single.colonna, 'alimento');
    });
  });

  group('File non importabili: nessuna riga (UC_GP_5, flusso 4.2)', () {
    test('vuoto', () {
      expect(_erroreFile(Uint8List(0)), contains('vuoto'));
      expect(_erroreFile(_bytes('  \n\n', bom: true)), contains('vuoto'));
    });

    test('solo l\'intestazione', () {
      expect(_erroreFile(_bytes(_intestazione)), contains('Nessuna riga'));
    });

    test('colonne mancanti, elencate per nome', () {
      final messaggio = _erroreFile(_bytes('giorno;alimento\nLun;Riso'));
      expect(messaggio, contains('pasto'));
      expect(messaggio, contains('quantita_g'));
    });

    test('separatore diverso (tabulazione)', () {
      final messaggio = _erroreFile(
        _bytes('giorno\tpasto\talimento\tquantita_g\nLun\tCena\tRiso\t80'),
      );
      expect(messaggio, contains(';'));
    });

    test('codifica non UTF-8', () {
      // "Lunedì" come lo salva un Excel in Windows-1252: ì = 0xEC.
      final bytes = Uint8List.fromList([
        ...utf8.encode('$_intestazione\nLuned'),
        0xEC,
        ...utf8.encode(';Cena;Riso;80;'),
      ]);
      expect(_erroreFile(bytes), contains('UTF-8'));
    });

    test('file Excel .xlsx (RF_GP_12 non previsto)', () {
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(_erroreFile(zip), contains('.xlsx'));
    });

    test('troppe righe', () {
      final righe = List.filled(1001, 'Lun;Cena;Riso;80').join('\n');
      expect(_erroreFile(_bytes('$_intestazione\n$righe')), contains('1000'));
    });
  });

  test('il modello scaricabile si importa senza errori (RF_GP_10)', () {
    final esito = leggiCsvPiano(
      File('assets/modello_piano.csv').readAsBytesSync(),
    );
    expect(esito.errate, isEmpty);
    expect(esito.righe, isNotEmpty);
    expect(esito.separatore, ';');
  });

  test('un piano settimanale grande si legge ben sotto i 5 s (RNF_P_4)', () {
    final righe = [for (var i = 0; i < 1000; i++) 'Lun;Cena;Alimento $i;80']
        .join('\n');
    final orologio = Stopwatch()..start();
    leggiCsvPiano(_bytes('$_intestazione\n$righe'));
    expect(orologio.elapsedMilliseconds, lessThan(5000));
  });
}
