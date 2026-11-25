import '../../domain/modelli/modello_piano.dart';
import '../../domain/modelli/piano_alimentare.dart';
import '../../domain/regole/calcoli_piano.dart';
import '../../domain/repository/modelli_repository.dart';
import '../../domain/repository/pazienti_repository.dart';

/// Modelli in memoria, senza Supabase (test e `CENATO_RUOLO_FINTO`). Salva il
/// contenuto con la stessa codifica JSON del database.
class ModelliRepositoryFinto extends ModelliRepository {
  final List<ModelloPiano> _modelli = [];
  int _contatore = 0;

  /// Con `true` le operazioni falliscono come un errore di rete (per i test).
  bool nonRaggiungibile = false;

  void _controlla() {
    if (nonRaggiungibile) {
      throw const ErroreOperazione(
        'Connessione non riuscita. Controlla la rete e riprova.',
        codice: 'rete',
      );
    }
  }

  @override
  Future<List<ModelloPiano>> elenco(TipoModello tipo) async {
    _controlla();
    return [
      for (final m in _modelli.reversed)
        if (m.tipo == tipo) m,
    ];
  }

  Future<ModelloPiano> _salva(
    String nome,
    TipoModello tipo,
    Map<String, dynamic> contenuto,
  ) async {
    _controlla();
    final errore = validaNomeModello(nome);
    if (errore != null) throw ErroreOperazione(errore, codice: 'nome');
    final m = ModelloPiano(
      id: 'modello-${++_contatore}',
      nome: nome.trim(),
      tipo: tipo,
      contenuto: contenuto,
      creatoIl: DateTime.now(),
    );
    _modelli.add(m);
    notifyListeners();
    return m;
  }

  @override
  Future<ModelloPiano> salvaPasto(String nome, PastoPiano pasto) =>
      _salva(nome, TipoModello.pasto, contenutoDaPasto(pasto));

  @override
  Future<ModelloPiano> salvaPiano(String nome, PianoAlimentare piano) =>
      _salva(nome, TipoModello.piano, contenutoDaPiano(piano));

  @override
  Future<void> elimina(String modelloId) async {
    _controlla();
    _modelli.removeWhere((m) => m.id == modelloId);
    notifyListeners();
  }
}
