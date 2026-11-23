import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/dipendenze.dart';
import '../../core/router/rotte.dart';
import '../../core/tema/tema.dart';

/// Punto di innesto di UC_GV_3 (RF_GV_6): giorni, fasce orarie e durata della
/// visita. La schermata vera arriva nella fase 4; qui, subito dopo la
/// registrazione del nutrizionista, c'è il segnaposto con "Più tardi".
class DisponibilitaPage extends StatelessWidget {
  const DisponibilitaPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilità'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 64,
                    color: ColoriCenato.primario,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Quando ricevi?',
                    style: testo.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Qui indicherai i giorni e gli orari di ricevimento e la '
                    'durata della visita, così i pazienti potranno prenotare '
                    'uno slot libero (UC_GV_3). Questa schermata arriva con '
                    'l\'agenda: per ora puoi proseguire.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('piu-tardi'),
                    onPressed: () {
                      // Primo accesso: si prosegue con l'elenco pazienti
                      // (UC_GA_2, passo 6). Dal profilo si torna al profilo.
                      final primo = dip.auth.primoAccesso;
                      dip.auth.concludiOnboarding();
                      context.go(primo ? Rotte.nutPazienti : Rotte.nutProfilo);
                    },
                    child: Text(
                      dip.auth.primoAccesso ? 'Più tardi' : 'Indietro',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
