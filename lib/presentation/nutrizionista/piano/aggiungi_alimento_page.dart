import 'package:material_ui/material_ui.dart';

import '../../../domain/modelli/alimento.dart';
import '../../../domain/repository/alimenti_repository.dart';
import '../alimenti/alimento_personalizzato_page.dart';
import '../alimenti/ricerca_alimento.dart';

/// Scelta di un alimento da aggiungere a un pasto (UC_GP_2 passi 1-3): la
/// ricerca con recenti e preferiti (UC_GP_3) e, se l'alimento non c'è,
/// l'inserimento a mano (flusso 2.1). Restituisce l'alimento scelto, già
/// salvato nella cache e quindi con `id`.
class AggiungiAlimentoPage extends StatelessWidget {
  const AggiungiAlimentoPage({super.key, required this.alimenti});

  final AlimentiRepository alimenti;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aggiungi alimento')),
      body: RicercaAlimento(
        repository: alimenti,
        onScelto: (a) => Navigator.of(context).pop<Alimento>(a),
        onCreaPersonalizzato: (testo) async {
          final creato = await Navigator.of(context).push<Alimento>(
            MaterialPageRoute(
              builder: (_) => AlimentoPersonalizzatoPage(
                repository: alimenti,
                nomeIniziale: testo,
              ),
            ),
          );
          // Un alimento appena creato si aggiunge subito al pasto.
          if (creato != null && context.mounted) {
            Navigator.of(context).pop<Alimento>(creato);
          }
        },
      ),
    );
  }
}
