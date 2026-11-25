import '../domain/repository/alimenti_repository.dart';
import '../domain/repository/auth_repository.dart';
import '../domain/repository/collegamento_repository.dart';
import '../domain/repository/modelli_repository.dart';
import '../domain/repository/obiettivi_repository.dart';
import '../domain/repository/pazienti_repository.dart';
import '../domain/repository/piani_repository.dart';
import '../domain/repository/profilo_repository.dart';

/// Repository usati dalle schermate. Creati in main.dart (Supabase o finti)
/// e passati al router: le schermate non conoscono Supabase.
class Dipendenze {
  const Dipendenze({
    required this.auth,
    required this.pazienti,
    required this.abbonamento,
    required this.collegamento,
    required this.profilo,
    required this.alimenti,
    required this.obiettivi,
    required this.piani,
    required this.modelli,
  });

  final AuthRepository auth;
  final PazientiRepository pazienti;
  final AbbonamentoRepository abbonamento;
  final CollegamentoRepository collegamento;
  final ProfiloRepository profilo;
  final AlimentiRepository alimenti;
  final ObiettiviRepository obiettivi;
  final PianiRepository piani;
  final ModelliRepository modelli;
}
