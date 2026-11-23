import '../domain/repository/auth_repository.dart';
import '../domain/repository/pazienti_repository.dart';

/// Repository usati dalle schermate. Creati in main.dart (Supabase o finti)
/// e passati al router: le schermate non conoscono Supabase.
class Dipendenze {
  const Dipendenze({
    required this.auth,
    required this.pazienti,
    required this.abbonamento,
  });

  final AuthRepository auth;
  final PazientiRepository pazienti;
  final AbbonamentoRepository abbonamento;
}
