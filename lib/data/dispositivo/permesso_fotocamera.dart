import 'package:flutter/services.dart';

/// Permesso della fotocamera per la scansione dei codici a barre (RNF_IN_3).
///
/// La richiesta vera la fa `mobile_scanner` quando avvia la fotocamera; qui
/// serve solo sapere **prima** se il permesso c'è già (per spiegare a cosa
/// serve solo quando il sistema sta per chiederlo) e aprire le impostazioni
/// dell'app se è stato negato (UC_GP_3, flusso 1.1).
abstract interface class PermessoFotocamera {
  /// Vero se l'app può già usare la fotocamera.
  Future<bool> concesso();

  /// Apre la pagina dell'app nelle impostazioni del telefono.
  Future<void> apriImpostazioni();
}

/// [PermessoFotocamera] con il canale nativo di `MainActivity.kt`: nessun
/// pacchetto in più oltre a `mobile_scanner`. Su piattaforme senza il canale
/// risponde "non concesso", e la scansione mostra prima la spiegazione.
class PermessoFotocameraNativo implements PermessoFotocamera {
  const PermessoFotocameraNativo();

  static const _canale = MethodChannel('it.unisa.cenato/fotocamera');

  @override
  Future<bool> concesso() async {
    try {
      return await _canale.invokeMethod<bool>('permessoConcesso') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> apriImpostazioni() async {
    try {
      await _canale.invokeMethod<void>('apriImpostazioni');
    } on MissingPluginException {
      // Nessuna pagina da aprire: resta il testo con il percorso a mano.
    } on PlatformException {
      // Come sopra.
    }
  }
}
