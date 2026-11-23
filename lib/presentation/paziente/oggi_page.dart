import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/segnaposto_page.dart';
import '../comuni/stati_view.dart';

/// Sezione Oggi del paziente (NP_1_PAZ). Il check-in dei pasti arriva con la
/// fase 3 (UC_GD_1); finché il nutrizionista non assegna un piano, e subito
/// dopo il collegamento, si vede lo stato vuoto (UC_GI_2, passo 6).
class OggiPage extends StatelessWidget {
  const OggiPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntestazioneSezione(
        titolo: Testi.oggi,
        sottotitolo: 'Pasti di oggi e check-in',
        azioni: [
          IconButton(
            tooltip: Testi.profilo,
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(Rotte.pazienteProfilo),
          ),
        ],
      ),
      body: const StatoVuotoView(
        icona: Icons.hourglass_top_outlined,
        titolo: 'Il tuo nutrizionista sta preparando il piano',
        messaggio:
            'Appena il piano sarà pronto, qui vedrai i pasti di oggi e potrai '
            'segnarli con un tocco. Ti avviseremo quando è disponibile.',
      ),
    );
  }
}
