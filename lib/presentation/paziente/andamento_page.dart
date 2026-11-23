import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/segnaposto_page.dart';

/// Sezione Andamento del paziente (segnaposto, NP_1_PAZ).
class AndamentoPage extends StatelessWidget {
  const AndamentoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SegnapostoPage(
      titolo: Testi.andamento,
      sottotitolo: 'Peso, aderenza e commenti',
      icona: Icons.show_chart,
      descrizione: 'Qui vedrai peso, aderenza della settimana, commenti del nutrizionista e storico dei check-in (UC_GM_1, UC_GM_2, UC_GC_2, UC_GD_3).',
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
