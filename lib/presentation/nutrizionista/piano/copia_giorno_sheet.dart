import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../comuni/controlli.dart';

/// Sceglie su quali giorni copiare [da] (RF_GP_13, UC_GP_1 passo 6). Mostra
/// per ogni giorno se ha già dei pasti (verrebbero sostituiti). Restituisce i
/// giorni scelti, o `null` se si annulla.
Future<Set<int>?> scegliGiorniDestinazione(
  BuildContext context, {
  required PianoAlimentare piano,
  required int da,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CopiaGiornoSheet(piano: piano, da: da),
  );
}

class _CopiaGiornoSheet extends StatefulWidget {
  const _CopiaGiornoSheet({required this.piano, required this.da});

  final PianoAlimentare piano;
  final int da;

  @override
  State<_CopiaGiornoSheet> createState() => _CopiaGiornoSheetState();
}

class _CopiaGiornoSheetState extends State<_CopiaGiornoSheet> {
  final _scelti = <int>{};

  List<int> get _altri => [
    for (final g in GiorniSettimana.tutti)
      if (g != widget.da) g,
  ];

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final tutti = _scelti.length == _altri.length;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Copia ${GiorniSettimana.nome(widget.da).toLowerCase()} su…',
              style: testo.titleLarge,
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                CheckboxListTile(
                  key: const Key('copia-tutti'),
                  value: tutti,
                  title: const Text('Tutti gli altri giorni'),
                  onChanged: (v) => setState(() {
                    _scelti
                      ..clear()
                      ..addAll(v == true ? _altri : const <int>[]);
                  }),
                ),
                for (final g in _altri)
                  CheckboxListTile(
                    key: Key('copia-giorno-$g'),
                    value: _scelti.contains(g),
                    title: Text(GiorniSettimana.nome(g)),
                    subtitle: Text(
                      (widget.piano
                                  .giorno(g)
                                  ?.pasti
                                  .any((p) => p.voci.isNotEmpty) ??
                              false)
                          ? 'Ha già dei pasti: verranno sostituiti'
                          : widget.piano.giorno(g) == null
                          ? 'Giorno nuovo'
                          : 'Vuoto',
                      style: TextStyle(color: c.testoSecondario),
                    ),
                    onChanged: (v) => setState(
                      () => v == true ? _scelti.add(g) : _scelti.remove(g),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: PulsantePrimario(
              etichetta: 'Copia',
              onPressed: _scelti.isEmpty
                  ? null
                  : () => Navigator.of(context).pop({..._scelti}),
            ),
          ),
        ],
      ),
    );
  }
}
