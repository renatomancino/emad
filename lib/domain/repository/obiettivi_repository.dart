import 'dart:async';

import 'package:flutter/foundation.dart';

import '../modelli/obiettivi.dart';

/// Obiettivi nutrizionali dei pazienti (UC_GP_6, RF_GP_16).
///
/// Il nutrizionista li imposta; a ogni modifica si salva una nuova riga
/// (storico). L'editor del piano e la sezione Dieta del paziente leggono
/// l'ultimo valore con [corrente] o seguono i cambiamenti con [osserva].
/// Avvisa i listener dopo ogni modifica.
abstract class ObiettiviRepository extends ChangeNotifier {
  /// L'ultimo obiettivo valido del paziente, `null` se non ancora impostato.
  Future<Obiettivi?> corrente(String pazienteId);

  /// Tutte le versioni, dalla più recente.
  Future<List<Obiettivi>> storico(String pazienteId);

  /// Salva una nuova versione (valida da oggi). Lancia `ErroreOperazione`.
  Future<Obiettivi> imposta(
    String pazienteId, {
    required int kcal,
    required double proteineG,
    required double carboidratiG,
    required double grassiG,
  });

  /// Obiettivo corrente del paziente, riemesso a ogni modifica: lo usano
  /// l'editor del piano (scostamento) e la sezione Dieta.
  Stream<Obiettivi?> osserva(String pazienteId) {
    late final StreamController<Obiettivi?> controller;
    Future<void> emetti() async {
      try {
        final o = await corrente(pazienteId);
        if (!controller.isClosed) controller.add(o);
      } catch (e, s) {
        if (!controller.isClosed) controller.addError(e, s);
      }
    }

    controller = StreamController<Obiettivi?>(
      onListen: () {
        addListener(emetti);
        emetti();
      },
      onCancel: () => removeListener(emetti),
    );
    return controller.stream;
  }
}
