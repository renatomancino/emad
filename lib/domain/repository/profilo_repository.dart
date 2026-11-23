import 'package:flutter/foundation.dart';

import '../modelli/dati_profilo.dart';

/// Lettura e modifica del profilo ed eliminazione dell'account
/// (UC_GA_3, UC_GA_5; RF_GA_5, RF_GA_7). Le operazioni lanciano
/// `ErroreOperazione` (lib/domain/repository/pazienti_repository.dart).
abstract class ProfiloRepository extends ChangeNotifier {
  Future<DatiProfilo> leggi();

  /// Salva i dati; avvisa i listener (il nome compare in più schermate).
  Future<void> salva(DatiProfilo dati);

  /// Cancella davvero i dati personali e l'account (GDPR art. 17) con la
  /// RPC `elimina_account`. Dopo il successo la sessione va chiusa.
  Future<void> eliminaAccount();
}
