import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/dipendenze.dart';
import '../../../core/router/rotte.dart';
import '../../../domain/modelli/alimento.dart';
import 'ricerca_alimento.dart';

/// Ricerca alimenti raggiungibile dal profilo del nutrizionista (UC_GP_3).
/// Finché non c'è l'editor del piano serve a cercare, creare e tenere i
/// preferiti; l'editor riuserà lo stesso [RicercaAlimento].
class RicercaAlimentoPage extends StatelessWidget {
  const RicercaAlimentoPage({super.key, required this.dip});

  final Dipendenze dip;

  @override
  Widget build(BuildContext context) {
    void avvisa(String messaggio) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(messaggio)));

    return Scaffold(
      appBar: AppBar(title: const Text('Alimenti')),
      body: RicercaAlimento(
        repository: dip.alimenti,
        onScelto: (a) => avvisa('«${a.nome}» salvato tra i recenti.'),
        onCreaPersonalizzato: (testo) async {
          final creato = await context.push<Alimento>(
            Rotte.nutAlimentoNuovo,
            extra: testo,
          );
          if (creato != null) avvisa('«${creato.nome}» creato.');
        },
      ),
    );
  }
}
