import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/router/rotte.dart';
import '../comuni/stati_view.dart';

/// Segnaposto delle schermate pubbliche della fase 1: registrazione con
/// consenso (UC_GA_1, RF_GA_6) e recupero password (UC_GA_4).
class SegnapostoAuthPage extends StatelessWidget {
  const SegnapostoAuthPage({
    super.key,
    required this.titolo,
    required this.descrizione,
  });

  final String titolo;
  final String descrizione;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titolo)),
      body: StatoVuotoView(
        icona: Icons.construction_outlined,
        titolo: '$titolo · ${Testi.inArrivo.toLowerCase()}',
        messaggio: descrizione,
        etichettaAzione: Testi.torna,
        onAzione: () => context.go(Rotte.accesso),
      ),
    );
  }
}
