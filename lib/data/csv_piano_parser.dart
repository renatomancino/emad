import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../domain/modelli/piano_alimentare.dart';
import '../domain/modelli/riga_csv_piano.dart';
import '../domain/regole/calcoli_piano.dart';
import '../domain/regole/importazione_piano.dart';

export '../domain/modelli/riga_csv_piano.dart';

/// Righe di dati accettate in un file. Un piano settimanale ne ha circa 150:
/// il tetto è una guardia contro un file sbagliato, non un requisito.
const int righeMassimeCsv = 1000;

/// Colonne obbligatorie del modello (RNF_IN_4). "note" è facoltativa.
const List<String> colonneObbligatorie = [
  'giorno',
  'pasto',
  'alimento',
  'quantita_g',
];

/// Lunghezza massima di un nome, come il vincolo della tabella `alimenti`.
const int _lunghezzaMassimaNome = 200;

/// Legge un CSV del piano (RF_GP_11, UC_GP_5): UTF-8 con o senza BOM,
/// separatore ";" o "," rilevato dall'intestazione, decimali con la virgola o
/// col punto. Le righe con problemi non fermano la lettura: tornano in
/// `errate` con numero, colonna e motivo. Se è il file intero a non andare,
/// lancia [ErroreFileCsv].
EsitoCsvPiano leggiCsvPiano(Uint8List bytes) {
  final testo = _decodifica(bytes);
  if (testo.trim().isEmpty) {
    throw const ErroreFileCsv(
      'Il file è vuoto. Scarica il modello, compilalo e riprova.',
    );
  }

  final separatore = _separatore(testo);
  // Le righe vuote non si saltano qui: così la posizione nell'elenco resta il
  // numero di riga che il nutrizionista vede nel suo foglio.
  final List<List<dynamic>> tabella;
  try {
    tabella = CsvDecoder(
      fieldDelimiter: separatore,
      skipEmptyLines: false,
    ).convert(testo);
  } catch (_) {
    throw const ErroreFileCsv(
      'Il file non si legge come CSV. Scarica il modello e riprova.',
    );
  }

  final colonne = _colonne(tabella.first);
  final righe = <RigaCsvPiano>[];
  final errate = <RigaCsvErrata>[];
  for (var i = 1; i < tabella.length; i++) {
    final celle = [for (final c in tabella[i]) '$c'.trim()];
    if (celle.every((c) => c.isEmpty)) continue;
    if (righe.length + errate.length >= righeMassimeCsv) {
      throw const ErroreFileCsv(
        'Il file ha più di $righeMassimeCsv righe: controlla di aver scelto '
        'il file giusto.',
      );
    }
    _leggiRiga(i + 1, celle, tabella.first.length, colonne, righe, errate);
  }

  if (righe.isEmpty && errate.isEmpty) {
    throw const ErroreFileCsv(
      'Nessuna riga da importare: sotto l\'intestazione non c\'è nulla.',
    );
  }
  return EsitoCsvPiano(separatore: separatore, righe: righe, errate: errate);
}

/// Da byte a testo, rifiutando ciò che non è un CSV in UTF-8.
String _decodifica(Uint8List bytes) {
  // Un .xlsx è un archivio ZIP e comincia con "PK" (RF_GP_12 non previsto).
  if (bytes.length > 1 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
    throw const ErroreFileCsv(
      'I file Excel .xlsx non si importano: da Excel scegli "Salva con nome" '
      'e il formato "CSV UTF-8".',
    );
  }
  // Il BOM (EF BB BF), che Excel aggiunge, non fa parte del contenuto.
  final inizio =
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? 3
      : 0;
  try {
    return utf8.decode(bytes.sublist(inizio));
  } on FormatException {
    throw const ErroreFileCsv(
      'La codifica del file non è UTF-8 (gli accenti andrebbero persi). '
      'Da Excel salva come "CSV UTF-8".',
    );
  }
}

/// Il separatore è quello più usato nella riga di intestazione. Con nessuno
/// dei due si prosegue con ";": il controllo delle colonne dirà cosa manca.
String _separatore(String testo) {
  final prima = const LineSplitter()
      .convert(testo)
      .firstWhere((r) => r.trim().isNotEmpty, orElse: () => '');
  final puntiVirgola = ';'.allMatches(prima).length;
  final virgole = ','.allMatches(prima).length;
  return virgole > puntiVirgola ? ',' : ';';
}

/// Posizione di ogni colonna, dall'intestazione (ordine e maiuscole liberi).
Map<String, int> _colonne(List<dynamic> intestazione) {
  final posizioni = <String, int>{};
  for (var i = 0; i < intestazione.length; i++) {
    // "Quantità_g" vale come "quantita_g".
    posizioni.putIfAbsent(normalizzaNome('${intestazione[i]}'), () => i);
  }
  final mancanti = [
    for (final c in colonneObbligatorie)
      if (!posizioni.containsKey(c)) c,
  ];
  if (mancanti.isNotEmpty) {
    throw ErroreFileCsv(
      'Mancano le colonne: ${mancanti.join(', ')}. La prima riga deve essere '
      'quella del modello, con separatore ";" o ",".',
    );
  }
  return posizioni;
}

/// Controlla una riga e la mette tra le valide o tra le errate.
void _leggiRiga(
  int numero,
  List<String> celle,
  int attese,
  Map<String, int> colonne,
  List<RigaCsvPiano> righe,
  List<RigaCsvErrata> errate,
) {
  String cella(String colonna) {
    final i = colonne[colonna];
    return i == null || i >= celle.length ? '' : celle[i];
  }

  final testo = celle.where((c) => c.isNotEmpty).join(' · ');

  // Più valori che colonne: di solito è "12,5" non racchiuso tra virgolette
  // in un file separato da virgole. I valori sarebbero spostati: ci si ferma.
  if (celle.length > attese && celle.skip(attese).any((c) => c.isNotEmpty)) {
    errate.add(
      RigaCsvErrata(
        numero: numero,
        testo: testo,
        errori: const [
          ErroreCsv(
            'quantita_g',
            'La riga ha troppi valori: con il separatore "," scrivi i '
                'decimali tra virgolette ("12,5") o col punto.',
          ),
        ],
      ),
    );
    return;
  }

  final errori = <ErroreCsv>[];

  final testoGiorno = cella('giorno');
  final giorno = giornoDaTesto(testoGiorno);
  if (giorno == null) {
    errori.add(
      ErroreCsv(
        'giorno',
        testoGiorno.isEmpty
            ? 'Manca il giorno.'
            : '"$testoGiorno" non è un giorno della settimana.',
      ),
    );
  }

  final testoPasto = cella('pasto');
  final TipoPasto? pasto = pastoDaTesto(testoPasto);
  if (pasto == null) {
    errori.add(
      ErroreCsv(
        'pasto',
        testoPasto.isEmpty
            ? 'Manca il pasto.'
            : '"$testoPasto" non è un pasto (colazione, spuntino, pranzo, '
                  'merenda, cena).',
      ),
    );
  }

  final alimento = cella('alimento');
  if (alimento.isEmpty) {
    errori.add(const ErroreCsv('alimento', 'Manca il nome dell\'alimento.'));
  } else if (alimento.length > _lunghezzaMassimaNome) {
    errori.add(
      const ErroreCsv(
        'alimento',
        'Il nome è troppo lungo (massimo $_lunghezzaMassimaNome caratteri).',
      ),
    );
  }

  // Stessa regola e stessi messaggi dell'editor (UC_GP_2, flusso 4.1).
  final testoQuantita = cella('quantita_g');
  final erroreQuantita = validaQuantita(testoQuantita);
  if (erroreQuantita != null) {
    errori.add(ErroreCsv('quantita_g', erroreQuantita));
  }

  if (errori.isNotEmpty) {
    errate.add(RigaCsvErrata(numero: numero, testo: testo, errori: errori));
    return;
  }
  righe.add(
    RigaCsvPiano(
      numero: numero,
      giorno: giorno!,
      pasto: pasto!,
      alimento: alimento,
      quantitaG: double.parse(testoQuantita.replaceAll(',', '.')),
      note: cella('note'),
    ),
  );
}
