import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../domain/repository/file_csv.dart';
import '../../domain/repository/pazienti_repository.dart' show ErroreOperazione;

/// Percorso del modello tra le risorse dell'app e nome proposto al salvataggio.
const String risorsaModelloCsv = 'assets/modello_piano.csv';
const String nomeModelloCsv = 'modello_piano.csv';

/// Dimensione massima accettata: un piano in CSV pesa pochi KB.
const int _byteMassimi = 1024 * 1024;

/// [FileCsv] con le finestre di sistema (pacchetto `file_picker`).
class FileCsvDispositivo implements FileCsv {
  const FileCsvDispositivo();

  @override
  Future<FileScelto?> scegli() async {
    try {
      // Nessun filtro per estensione: su Android molti gestori di file non
      // riconoscono ".csv" e lo mostrerebbero disattivato. Il contenuto lo
      // controlla il parser.
      final file = await FilePicker.pickFile();
      if (file == null) return null;
      final dimensione = await file.length();
      if (dimensione != null && dimensione > _byteMassimi) {
        throw const ErroreOperazione(
          'Il file è troppo grande per essere un piano in CSV.',
        );
      }
      return FileScelto(nome: file.name, bytes: await file.readAsBytes());
    } on ErroreOperazione {
      rethrow;
    } catch (_) {
      throw const ErroreOperazione('Non riesco a leggere il file scelto.');
    }
  }

  @override
  Future<bool> salvaModello() async {
    try {
      final dati = await rootBundle.load(risorsaModelloCsv);
      final percorso = await FilePicker.saveFile(
        fileName: nomeModelloCsv,
        bytes: dati.buffer.asUint8List(dati.offsetInBytes, dati.lengthInBytes),
        mimeType: 'text/csv',
      );
      return percorso != null;
    } catch (_) {
      throw const ErroreOperazione('Non riesco a salvare il modello.');
    }
  }
}
