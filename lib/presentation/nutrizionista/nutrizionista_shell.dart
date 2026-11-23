import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';

/// Area del nutrizionista: Pazienti (dashboard), Calendario, Profilo e
/// abbonamento (NP_2_NUT, CLAUDE.md regola 8).
class NutrizionistaShell extends StatelessWidget {
  const NutrizionistaShell({super.key, required this.navigazione});

  final StatefulNavigationShell navigazione;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigazione,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigazione.currentIndex,
        onDestinationSelected: (indice) => navigazione.goBranch(
          indice,
          initialLocation: indice == navigazione.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: Testi.pazienti,
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: Testi.calendario,
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: Testi.profiloAbbonamento,
          ),
        ],
      ),
    );
  }
}
