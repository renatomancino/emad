import '../../core/dipendenze.dart';
import '../../domain/modelli/profilo.dart';
import '../alimenti_repository.dart';
import 'alimenti_cache_in_memoria.dart';
import 'fonte_alimenti_online_finta.dart';
import 'auth_repository_finto.dart';
import 'collegamento_repository_finto.dart';
import 'obiettivi_repository_finto.dart';
import 'pazienti_repository_finto.dart';
import 'profilo_repository_finto.dart';

/// Dipendenze finte (in memoria) per test e per `CENATO_RUOLO_FINTO`.
/// Restituisce anche i singoli oggetti, così i test possono ispezionarli.
class DipendenzeFinte {
  DipendenzeFinte({Ruolo? ruolo, DatiFinti? dati})
    : dati = dati ?? DatiFinti(),
      auth = AuthRepositoryFinto(ruoloIniziale: ruolo) {
    pazienti = PazientiRepositoryFinto(this.dati)
      ..alScollegamento = auth.scollega;
    abbonamento = AbbonamentoRepositoryFinto(this.dati);
    collegamento = CollegamentoRepositoryFinto(auth);
    profilo = ProfiloRepositoryFinto(auth);
    obiettivi = ObiettiviRepositoryFinto();
    alimenti = AlimentiRepositoryImpl(
      cache: AlimentiCacheInMemoria(),
      online: alimentiOnline,
    );
  }

  final DatiFinti dati;
  final AuthRepositoryFinto auth;
  late final PazientiRepositoryFinto pazienti;
  late final AbbonamentoRepositoryFinto abbonamento;
  late final CollegamentoRepositoryFinto collegamento;
  late final ProfiloRepositoryFinto profilo;
  late final ObiettiviRepositoryFinto obiettivi;
  late final AlimentiRepositoryImpl alimenti;

  /// Servizio online finto: i test ne leggono le chiamate e lo spengono.
  final FonteAlimentiOnlineFinta alimentiOnline = FonteAlimentiOnlineFinta();

  Dipendenze get dip => Dipendenze(
    auth: auth,
    pazienti: pazienti,
    abbonamento: abbonamento,
    collegamento: collegamento,
    profilo: profilo,
    alimenti: alimenti,
    obiettivi: obiettivi,
  );
}
