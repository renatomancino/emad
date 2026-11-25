import 'package:flutter/foundation.dart';

import '../modelli/modello_piano.dart';
import '../modelli/piano_alimentare.dart';

/// Pasti salvati e piani modello del nutrizionista (RF_GP_9). Ogni modello è
/// una copia indipendente: modificarlo o eliminarlo non tocca i piani creati
/// con esso. Avvisa i listener dopo ogni modifica.
abstract class ModelliRepository extends ChangeNotifier {
  /// I modelli del tipo indicato, dal più recente. Sono solo del nutrizionista
  /// che li ha creati (RLS).
  Future<List<ModelloPiano>> elenco(TipoModello tipo);

  /// Salva [pasto] come modello. Lancia `ErroreOperazione` per un nome non
  /// valido o per la rete.
  Future<ModelloPiano> salvaPasto(String nome, PastoPiano pasto);

  /// Salva [piano] come piano modello.
  Future<ModelloPiano> salvaPiano(String nome, PianoAlimentare piano);

  Future<void> elimina(String modelloId);
}
