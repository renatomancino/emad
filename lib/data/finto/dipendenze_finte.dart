import '../../core/dipendenze.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/file_csv.dart';
import '../dispositivo/file_csv_dispositivo.dart';
import '../alimenti_repository.dart';
import 'alimenti_cache_in_memoria.dart';
import 'fonte_alimenti_online_finta.dart';
import 'auth_repository_finto.dart';
import 'collegamento_repository_finto.dart';
import 'modelli_repository_finto.dart';
import 'obiettivi_repository_finto.dart';
import 'pazienti_repository_finto.dart';
import 'piani_repository_finto.dart';
import 'profilo_repository_finto.dart';

/// Dipendenze finte (in memoria) per test e per `CENATO_RUOLO_FINTO`.
/// Restituisce anche i singoli oggetti, così i test possono ispezionarli.
class DipendenzeFinte {
  DipendenzeFinte({
    Ruolo? ruolo,
    DatiFinti? dati,
    // Predefinito: le finestre di sistema, così nella demo finta si possono
    // scegliere file veri.
    this.fileCsv = const FileCsvDispositivo(),
  }) : dati = dati ?? DatiFinti(),
       auth = AuthRepositoryFinto(ruoloIniziale: ruolo) {
    pazienti = PazientiRepositoryFinto(this.dati)
      ..alScollegamento = auth.scollega;
    abbonamento = AbbonamentoRepositoryFinto(this.dati);
    collegamento = CollegamentoRepositoryFinto(auth);
    profilo = ProfiloRepositoryFinto(auth);
    obiettivi = ObiettiviRepositoryFinto();
    piani = PianiRepositoryFinto();
    modelli = ModelliRepositoryFinto();
    alimenti = AlimentiRepositoryImpl(
      cache: AlimentiCacheInMemoria(),
      online: alimentiOnline,
    );
  }

  final FileCsv fileCsv;
  final DatiFinti dati;
  final AuthRepositoryFinto auth;
  late final PazientiRepositoryFinto pazienti;
  late final AbbonamentoRepositoryFinto abbonamento;
  late final CollegamentoRepositoryFinto collegamento;
  late final ProfiloRepositoryFinto profilo;
  late final ObiettiviRepositoryFinto obiettivi;
  late final PianiRepositoryFinto piani;
  late final ModelliRepositoryFinto modelli;
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
    piani: piani,
    modelli: modelli,
    fileCsv: fileCsv,
  );
}
