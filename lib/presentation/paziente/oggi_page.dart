import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/segnaposto_page.dart';

/// Sezione Oggi del paziente (segnaposto, NP_1_PAZ).
class OggiPage extends StatelessWidget {
  const OggiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SegnapostoPage(
      titolo: Testi.oggi,
      sottotitolo: 'Pasti di oggi e check-in',
      icona: Icons.check_circle_outline,
      descrizione: 'Qui vedrai i pasti di oggi e potrai segnarli come Seguito, Alternativa, Fuori piano o Saltato (UC_GD_1, UC_GD_2).',
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
