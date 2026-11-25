import '../../domain/modelli/obiettivi.dart';
import '../../domain/repository/obiettivi_repository.dart';
import '../../domain/repository/pazienti_repository.dart';

/// Obiettivi in memoria, senza Supabase (test e `CENATO_RUOLO_FINTO`).
class ObiettiviRepositoryFinto extends ObiettiviRepository {
  ObiettiviRepositoryFinto({Map<String, List<Obiettivi>>? iniziali})
    : _righe = {
        for (final e in (iniziali ?? {}).entries) e.key: [...e.value],
      };

  /// Per paziente, dalla più vecchia alla più recente.
  final Map<String, List<Obiettivi>> _righe;

  /// Con `true` le operazioni falliscono come un errore di rete (per i test).
  bool nonRaggiungibile = false;

  /// Numero di salvataggi andati a buon fine.
  int salvataggi = 0;

  void _controlla() {
    if (nonRaggiungibile) {
      throw const ErroreOperazione(
        'Connessione non riuscita. Controlla la rete e riprova.',
        codice: 'rete',
      );
    }
  }

  @override
  Future<Obiettivi?> corrente(String pazienteId) async {
    _controlla();
    final righe = _righe[pazienteId];
    return righe == null || righe.isEmpty ? null : righe.last;
  }

  @override
  Future<List<Obiettivi>> storico(String pazienteId) async {
    _controlla();
    return List.of(_righe[pazienteId] ?? const <Obiettivi>[]).reversed.toList();
  }

  @override
  Future<Obiettivi> imposta(
    String pazienteId, {
    required int kcal,
    required double proteineG,
    required double carboidratiG,
    required double grassiG,
  }) async {
    _controlla();
    final nuovo = Obiettivi(
      id: 'ob-${++salvataggi}',
      kcal: kcal,
      proteineG: proteineG,
      carboidratiG: carboidratiG,
      grassiG: grassiG,
      dal: DateTime.now(),
    );
    (_righe[pazienteId] ??= []).add(nuovo);
    notifyListeners();
    return nuovo;
  }
}
