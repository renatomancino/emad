import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../data/dispositivo/permesso_fotocamera.dart';
import 'scansione_codice_page.dart';

/// Permesso simulato per `CENATO_RUOLO_FINTO`: la prima volta non c'è (si
/// vede la spiegazione), poi resta concesso finché l'app è aperta.
class PermessoFotocameraSimulato implements PermessoFotocamera {
  static bool _concesso = false;

  @override
  Future<bool> concesso() async => _concesso;

  @override
  Future<void> apriImpostazioni() async => _concesso = true;
}

/// Codici del catalogo finto (`FonteAlimentiOnlineFinta`), tutti inventati.
const _letture = [
  ('Yogurt greco (trovato)', '8000000000095'),
  ('Prodotto senza dati (incompleto)', '8000000000125'),
  ('Codice sconosciuto', '8000000000132'),
];

/// Anteprima della fotocamera simulata: al posto dell'immagine, pulsanti che
/// "leggono" un codice o negano il permesso. Serve per la demo nel browser e
/// sul simulatore, dove non si inquadrano prodotti veri. Mai nell'app vera.
Widget anteprimaSimulata(
  BuildContext context, {
  required void Function(String grezzo, bool upcE) onLetto,
  required void Function(ErroreFotocamera errore) onErrore,
}) {
  final testo = Theme.of(context).textTheme;
  final c = context.colori;
  return ColoredBox(
    color: c.fotocamera,
    child: SafeArea(
      child: Align(
        alignment: const Alignment(0, -0.85),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  'Fotocamera simulata (modalità di prova)',
                  textAlign: TextAlign.center,
                  style: testo.titleSmall?.copyWith(color: c.sullaFotocamera),
                ),
              ),
              for (final (etichetta, codice) in _letture)
                ActionChip(
                  label: Text(etichetta),
                  onPressed: () => onLetto(codice, false),
                ),
              ActionChip(
                label: const Text('Nega il permesso'),
                onPressed: () {
                  PermessoFotocameraSimulato._concesso = false;
                  onErrore(ErroreFotocamera.permessoNegato);
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
