import '../../domain/modelli/alimento.dart';
import '../alimenti_cache.dart';

/// [AlimentiCache] in memoria, per test e per `CENATO_RUOLO_FINTO`.
class AlimentiCacheInMemoria implements AlimentiCache {
  final Map<String, Alimento> _alimenti = {};
  final Map<String, _Uso> _uso = {};
  int _contatore = 0;

  Alimento _conFlag(Alimento a) =>
      a.copyWith(preferito: _uso[a.id]?.preferito ?? false);

  /// Preferiti prima, poi i più recenti, poi il nome.
  int _confronta(Alimento a, Alimento b) {
    final ua = _uso[a.id], ub = _uso[b.id];
    final pa = ua?.preferito ?? false, pb = ub?.preferito ?? false;
    if (pa != pb) return pa ? -1 : 1;
    final oa = ua?.ordine ?? 0, ob = ub?.ordine ?? 0;
    if (oa != ob) return ob.compareTo(oa);
    return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
  }

  @override
  Future<List<Alimento>> cercaPerNome(String testo, {int limite = 20}) async {
    final t = testo.trim().toLowerCase();
    if (t.isEmpty) return const [];
    final trovati =
        _alimenti.values
            .where((a) => a.nome.toLowerCase().contains(t))
            .map(_conFlag)
            .toList()
          ..sort(_confronta);
    return trovati.take(limite).toList();
  }

  @override
  Future<Alimento> salva(Alimento alimento) async {
    assert(alimento.completo, 'La cache accetta solo alimenti completi');
    if (alimento.fonte == FonteAlimento.openFoodFacts) {
      final esistente = _alimenti.values.where((a) {
        if (a.fonte != FonteAlimento.openFoodFacts) return false;
        if (alimento.codiceBarre != null) {
          return a.codiceBarre == alimento.codiceBarre;
        }
        return a.nome.toLowerCase() == alimento.nome.toLowerCase() &&
            (a.marca ?? '').toLowerCase() ==
                (alimento.marca ?? '').toLowerCase();
      });
      if (esistente.isNotEmpty) return _conFlag(esistente.first);
    }
    final id = 'a${++_contatore}';
    final salvato = alimento.copyWith(id: id);
    _alimenti[id] = salvato;
    return _conFlag(salvato);
  }

  @override
  Future<void> segnaUso(String alimentoId) async {
    final uso = _uso.putIfAbsent(alimentoId, _Uso.new);
    uso.ordine = ++_contatore;
  }

  @override
  Future<List<Alimento>> recenti({int limite = 10}) async {
    final conUso = _uso.entries.where((e) => e.value.ordine > 0).toList()
      ..sort((a, b) => b.value.ordine.compareTo(a.value.ordine));
    return [
      for (final e in conUso.take(limite))
        if (_alimenti[e.key] != null) _conFlag(_alimenti[e.key]!),
    ];
  }

  @override
  Future<List<Alimento>> preferiti() async {
    final lista = _uso.entries.where((e) => e.value.preferito).toList()
      ..sort((a, b) => b.value.ordine.compareTo(a.value.ordine));
    return [
      for (final e in lista)
        if (_alimenti[e.key] != null) _conFlag(_alimenti[e.key]!),
    ];
  }

  @override
  Future<void> impostaPreferito(String alimentoId, bool preferito) async {
    _uso.putIfAbsent(alimentoId, _Uso.new).preferito = preferito;
  }
}

class _Uso {
  bool preferito = false;

  /// Più alto = usato più di recente; 0 = mai usato.
  int ordine = 0;
}
