import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../comuni/segnaposto_page.dart';

/// Calendario delle visite (segnaposto, NP_2_NUT).
class CalendarioPage extends StatelessWidget {
  const CalendarioPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SegnapostoPage(
      titolo: Testi.calendario,
      sottotitolo: 'Visite e slot liberi',
      icona: Icons.calendar_month,
      descrizione:
          'Qui vedrai le visite della settimana e del mese, gli slot liberi, '
          'le disponibilità e le finestre di prenotazione (UC_GV_1, UC_GV_2, '
          'UC_GV_3).',
    );
  }
}
