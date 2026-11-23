import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';

/// Area del paziente: barra inferiore con le quattro sezioni Oggi, Dieta,
/// Andamento e Visite, raggiungibili con un tocco (RNF_U_6, NP_1_PAZ).
class PazienteShell extends StatelessWidget {
  const PazienteShell({super.key, required this.navigazione});

  final StatefulNavigationShell navigazione;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigazione,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigazione.currentIndex,
        onDestinationSelected: (indice) => navigazione.goBranch(
          indice,
          // Un secondo tocco sulla sezione aperta torna al suo inizio.
          initialLocation: indice == navigazione.currentIndex,
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: Testi.oggi,
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: Testi.dieta,
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: Testi.andamento,
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: Testi.visite,
          ),
        ],
      ),
    );
  }
}
