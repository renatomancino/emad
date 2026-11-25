import 'package:material_ui/material_ui.dart';

import '../../domain/modelli/piano.dart';
import '../../domain/regole/limiti_piano.dart';
import 'componenti.dart';
import '../../domain/repository/pazienti_repository.dart';

/// ErroreLimitePianoDialog (RF_GAD_7, UC_GI_1 flusso 2.1-2.2): motivo e
/// opzioni. "Cambia piano" sempre; "Archivia un paziente" solo in Start e Pro
/// (nel Free l'archiviazione non libera posti).
Future<void> mostraErroreLimite(
  BuildContext context,
  ErroreLimitePiano errore, {
  required VoidCallback onCambiaPiano,
  VoidCallback? onArchivia,
}) {
  final piano = errore.piano ?? PianoAbbonamento.free;
  final opzioni = opzioniAlLimite(piano);
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const IconaTonale(icona: Icons.lock_outline, dimensione: 56),
      title: const Text('Limite del piano raggiunto'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(errore.messaggio),
          if (errore.suggerimento != null) ...[
            const SizedBox(height: 8),
            Text(errore.suggerimento!),
          ],
          if (piano == PianoAbbonamento.free) ...[
            const SizedBox(height: 8),
            const Text(
              'Il piano Free conta tutti i pazienti che hanno accettato un '
              'invito, anche se poi archiviati.',
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Chiudi'),
        ),
        if (opzioni.contains(OpzioneLimite.archiviaPaziente) &&
            onArchivia != null)
          OutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onArchivia();
            },
            child: const Text('Archivia un paziente'),
          ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            onCambiaPiano();
          },
          child: const Text('Cambia piano'),
        ),
      ],
    ),
  );
}
