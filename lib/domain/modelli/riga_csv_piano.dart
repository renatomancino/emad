import 'piano_alimentare.dart';

/// Quello che il parser ricava da un file CSV del piano (RF_GP_11, UC_GP_5).
/// Sta nel dominio perché lo usano sia il parser (data) sia l'anteprima e la
/// costruzione della bozza.

/// Una riga valida: un alimento (ancora solo per nome) di un pasto.
class RigaCsvPiano {
  const RigaCsvPiano({
    required this.numero,
    required this.giorno,
    required this.pasto,
    required this.alimento,
    required this.quantitaG,
    this.note = '',
  });

  /// Numero della riga nel foglio (l'intestazione è la 1).
  final int numero;

  /// 1 = lunedì … 7 = domenica, come nel database.
  final int giorno;
  final TipoPasto pasto;

  /// Nome scritto nel file: si abbina poi a un alimento vero.
  final String alimento;
  final double quantitaG;

  /// Si mostra in anteprima ma non si salva: il piano non ha un campo note.
  final String note;
}

/// Un problema di una riga: colonna e motivo, in italiano.
class ErroreCsv {
  const ErroreCsv(this.colonna, this.motivo);

  /// Nome della colonna come nel modello ("giorno", "quantita_g"…).
  final String colonna;
  final String motivo;
}

/// Una riga che non si può importare, con tutti i suoi problemi.
class RigaCsvErrata {
  const RigaCsvErrata({
    required this.numero,
    required this.testo,
    required this.errori,
  });

  final int numero;

  /// I valori della riga, per riconoscerla in anteprima.
  final String testo;
  final List<ErroreCsv> errori;
}

/// Il contenuto leggibile di un file: righe valide e righe errate.
class EsitoCsvPiano {
  const EsitoCsvPiano({
    required this.separatore,
    required this.righe,
    required this.errate,
  });

  /// ";" o ",", rilevato dall'intestazione.
  final String separatore;
  final List<RigaCsvPiano> righe;
  final List<RigaCsvErrata> errate;
}

/// Il file intero non si può importare (vuoto, colonne mancanti, codifica…):
/// non si crea nulla e si rimanda al modello (UC_GP_5, flusso 4.2).
class ErroreFileCsv implements Exception {
  const ErroreFileCsv(this.messaggio);

  final String messaggio;

  @override
  String toString() => 'ErroreFileCsv: $messaggio';
}
