import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/segnaposto_page.dart';

/// Sezione Dieta del paziente (segnaposto, NP_1_PAZ).
class DietaPage extends StatelessWidget {
  const DietaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SegnapostoPage(
      titolo: Testi.dieta,
      sottotitolo: 'Piano e obiettivi',
      icona: Icons.restaurant_menu,
      descrizione: 'Qui vedrai il piano del nutrizionista giorno per giorno, con alternative e obiettivi nutrizionali (UC_GP_4).',
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
