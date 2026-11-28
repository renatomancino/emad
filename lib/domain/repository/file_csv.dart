import 'dart:typed_data';

/// Un file scelto dal nutrizionista: nome e contenuto.
class FileScelto {
  const FileScelto({required this.nome, required this.bytes});

  final String nome;
  final Uint8List bytes;
}

/// Accesso ai file del telefono per l'importazione del piano (RF_GP_10,
/// RF_GP_11). Dietro un'interfaccia così le schermate si provano senza
/// dispositivo.
abstract interface class FileCsv {
  /// Fa scegliere un file; `null` se il nutrizionista annulla. Lancia
  /// `ErroreOperazione` se il file non si riesce a leggere.
  Future<FileScelto?> scegli();

  /// Salva il modello CSV dove indica il nutrizionista; `false` se annulla.
  /// Lancia `ErroreOperazione` se il salvataggio non riesce.
  Future<bool> salvaModello();
}
