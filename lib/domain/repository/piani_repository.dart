import 'package:flutter/foundation.dart';

import '../modelli/piano_alimentare.dart';

/// Piani alimentari con versioni (RF_GP_1, RF_GP_2, RF_GP_7, UC_GP_1).
///
/// Ogni salvataggio crea una **nuova versione** e la assegna al paziente; le
/// versioni precedenti restano (i check-in già registrati restano legati a
/// quella su cui sono stati fatti). Il paziente vede solo la corrente.
/// Avvisa i listener dopo ogni salvataggio.
abstract class PianiRepository extends ChangeNotifier {
  /// La versione corrente (quella che vede il paziente), `null` se non c'è.
  Future<PianoAlimentare?> corrente(String pazienteId);

  /// Le versioni del paziente, dalla più recente (storico, RF_GP_7).
  Future<List<VersionePiano>> versioni(String pazienteId);

  /// Una versione con tutta la sua struttura, per consultarla.
  Future<PianoAlimentare> versione(String pianoId);

  /// Salva [piano] come nuova versione e la assegna al paziente, tutto o
  /// niente. Lancia `ErroreOperazione` (piano non valido, paziente non attivo,
  /// rete): in quel caso nulla cambia.
  ///
  /// Aggancio per la scheda Notifiche: qui nasce la notifica "nuovo piano".
  Future<PianoAlimentare> salva(String pazienteId, PianoAlimentare piano);
}
