import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../comuni/segnaposto_page.dart';

/// Dashboard dei pazienti (segnaposto, NP_2_NUT).
class PazientiPage extends StatelessWidget {
  const PazientiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SegnapostoPage(
      titolo: Testi.pazienti,
      sottotitolo: 'Semaforo, ultimo check-in e prossima visita',
      icona: Icons.groups,
      descrizione:
          'Qui vedrai l\'elenco dei pazienti con il semaforo di aderenza, '
          'i filtri Attivi / Archiviati / Tutti e il pulsante Invita '
          '(UC_GAD_1, UC_GI_1, UC_GI_3).',
    );
  }
}
