import 'package:flutter/foundation.dart';

import '../modelli/paziente.dart';
import '../modelli/piano.dart';

/// Errore del limite del piano (RF_GAD_7): motivo e piano che lo ha causato.
class ErroreLimitePiano implements Exception {
  const ErroreLimitePiano(this.messaggio, {this.suggerimento, this.piano});

  final String messaggio;
  final String? suggerimento;
  final PianoAbbonamento? piano;

  @override
  String toString() => 'ErroreLimitePiano: $messaggio';
}

/// Errore di un'operazione (rete, permessi, dati non validi) con messaggio
/// in italiano per l'utente.
class ErroreOperazione implements Exception {
  const ErroreOperazione(this.messaggio, {this.codice});

  final String messaggio;
  final String? codice;

  @override
  String toString() => 'ErroreOperazione($codice): $messaggio';
}

/// Pazienti e inviti del nutrizionista (UC_GI_1, UC_GI_3, UC_GI_4) e
/// scollegamento del paziente (UC_GI_5). Avvisa i listener dopo ogni modifica.
abstract class PazientiRepository extends ChangeNotifier {
  Future<List<PazienteElenco>> elencoPazienti();

  Future<List<Invito>> elencoInviti();

  /// Crea un invito; lancia [ErroreLimitePiano] se non c'è posto.
  Future<Invito> creaInvito({String? nome});

  Future<void> revocaInvito(String invitoId);

  Future<void> archivia(String pazienteId);

  /// Lancia [ErroreLimitePiano] se il piano non lo consente.
  Future<void> riattiva(String pazienteId);

  /// Il paziente interrompe il collegamento con il nutrizionista.
  Future<void> scollegati();
}

/// Abbonamento del nutrizionista (UC_GAD_3).
abstract class AbbonamentoRepository extends ChangeNotifier {
  Future<StatoAbbonamento> stato();

  /// Cambio piano con pagamento SIMULATO (RF_GAD_5).
  Future<void> cambiaPiano(
    PianoAbbonamento piano,
    PeriodoFatturazione? periodo,
  );
}
