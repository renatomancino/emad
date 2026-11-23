import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/segnaposto_page.dart';

/// Sezione Visite del paziente (segnaposto, NP_1_PAZ).
class VisitePage extends StatelessWidget {
  const VisitePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SegnapostoPage(
      titolo: Testi.visite,
      sottotitolo: 'Prossima visita',
      icona: Icons.event,
      descrizione: 'Qui vedrai la prossima visita e potrai prenotare uno slot libero o annullare (UC_GV_2, UC_GV_4).',
      azioni: [
        IconButton(
          tooltip: Testi.profilo,
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.push(Rotte.pazienteProfilo),
        ),
      ],
    );
  }
}
