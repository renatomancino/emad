import '../../domain/modelli/paziente.dart';
import '../../domain/modelli/piano.dart';
import '../../domain/regole/limiti_piano.dart';
import '../../domain/repository/pazienti_repository.dart';

/// Pazienti, inviti e abbonamento in memoria, senza Supabase.
///
/// Usato dai test e dalla prova con ruolo simulato
/// (`--dart-define=CENATO_RUOLO_FINTO=nutrizionista`). Applica le stesse
/// regole dei limiti dell'app (lib/domain/regole/limiti_piano.dart).
class DatiFinti {
  DatiFinti({this.piano = PianoAbbonamento.pro, List<PazienteElenco>? pazienti})
    : pazienti =
          pazienti ??
          [
            const PazienteElenco(
              id: 'p1',
              nome: 'Marco',
              stato: StatoPaziente.attivo,
            ),
            const PazienteElenco(
              id: 'p2',
              nome: 'Sara',
              stato: StatoPaziente.attivo,
            ),
            const PazienteElenco(
              id: 'p3',
              nome: 'Paolo',
              stato: StatoPaziente.attivo,
            ),
            const PazienteElenco(
              id: 'p4',
              nome: 'Luca',
              stato: StatoPaziente.archiviato,
            ),
          ];

  PianoAbbonamento piano;
  PeriodoFatturazione? periodo = PeriodoFatturazione.annuale;
  final List<PazienteElenco> pazienti;
  final List<Invito> inviti = [];
  int _contatore = 0;

  int get attivi =>
      pazienti.where((p) => p.stato == StatoPaziente.attivo).length;
  int get collegatiTotali =>
      pazienti.where((p) => p.stato != StatoPaziente.invitato).length;
  int get invitiInAttesa => inviti
      .where((i) => i.statoEffettivo(DateTime.now()) == StatoInvito.creato)
      .length;

  String nuovoId() => 'finto-${_contatore++}';
}

class PazientiRepositoryFinto extends PazientiRepository {
  PazientiRepositoryFinto(this.dati);

  final DatiFinti dati;

  @override
  Future<List<PazienteElenco>> elencoPazienti() async => List.of(dati.pazienti);

  @override
  Future<List<Invito>> elencoInviti() async => List.of(dati.inviti);

  @override
  Future<Invito> creaInvito({String? nome}) async {
    final esito = puoInvitare(
      piano: dati.piano,
      pazientiAttivi: dati.attivi,
      pazientiCollegatiTotali: dati.collegatiTotali,
      invitiInAttesa: dati.invitiInAttesa,
    );
    if (esito is LimiteRaggiunto) {
      throw ErroreLimitePiano(esito.motivo, piano: dati.piano);
    }
    final invito = Invito(
      id: dati.nuovoId(),
      codice: 'PROVA${dati.inviti.length + 100}',
      stato: StatoInvito.creato,
      scadenza: DateTime.now().add(const Duration(days: 7)),
      nome: nome,
    );
    dati.inviti.insert(0, invito);
    notifyListeners();
    return invito;
  }

  @override
  Future<void> revocaInvito(String invitoId) async {
    final i = dati.inviti.indexWhere((x) => x.id == invitoId);
    if (i < 0 || dati.inviti[i].stato != StatoInvito.creato) {
      throw const ErroreOperazione('Invito non trovato o già utilizzato.');
    }
    final v = dati.inviti[i];
    dati.inviti[i] = Invito(
      id: v.id,
      codice: v.codice,
      stato: StatoInvito.revocato,
      scadenza: v.scadenza,
      nome: v.nome,
    );
    notifyListeners();
  }

  void _cambiaStato(String id, StatoPaziente stato) {
    final i = dati.pazienti.indexWhere((p) => p.id == id);
    final p = dati.pazienti[i];
    dati.pazienti[i] = PazienteElenco(id: p.id, nome: p.nome, stato: stato);
  }

  @override
  Future<void> archivia(String pazienteId) async {
    _cambiaStato(pazienteId, StatoPaziente.archiviato);
    notifyListeners();
  }

  @override
  Future<void> riattiva(String pazienteId) async {
    final esito = puoRiattivare(
      piano: dati.piano,
      pazientiAttivi: dati.attivi,
      pazientiCollegatiTotali: dati.collegatiTotali,
    );
    if (esito is LimiteRaggiunto) {
      throw ErroreLimitePiano(esito.motivo, piano: dati.piano);
    }
    _cambiaStato(pazienteId, StatoPaziente.attivo);
    notifyListeners();
  }

  @override
  Future<void> scollegati() async => notifyListeners();
}

class AbbonamentoRepositoryFinto extends AbbonamentoRepository {
  AbbonamentoRepositoryFinto(this.dati);

  final DatiFinti dati;

  @override
  Future<StatoAbbonamento> stato() async => StatoAbbonamento(
    piano: dati.piano,
    periodo: dati.periodo,
    pazientiAttivi: dati.attivi,
    pazientiCollegatiTotali: dati.collegatiTotali,
    invitiInAttesa: dati.invitiInAttesa,
  );

  @override
  Future<void> cambiaPiano(
    PianoAbbonamento piano,
    PeriodoFatturazione? periodo,
  ) async {
    final esito = puoCambiarePiano(
      nuovo: piano,
      pazientiAttivi: dati.attivi,
      pazientiCollegatiTotali: dati.collegatiTotali,
      invitiInAttesa: dati.invitiInAttesa,
    );
    if (esito is LimiteRaggiunto) {
      throw ErroreLimitePiano(esito.motivo, piano: piano);
    }
    dati.piano = piano;
    dati.periodo = piano == PianoAbbonamento.free ? null : periodo;
    notifyListeners();
  }
}
