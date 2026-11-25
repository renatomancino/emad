import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/modello_piano.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../../domain/repository/modelli_repository.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../comuni/stati_view.dart';

/// Chiede il nome con cui salvare un modello (RF_GP_9). Restituisce il nome
/// pulito, o `null` se si annulla.
Future<String?> chiediNomeModello(
  BuildContext context, {
  required String titolo,
  String suggerimento = '',
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _NomeModelloDialog(titolo: titolo, suggerimento: suggerimento),
);

class _NomeModelloDialog extends StatefulWidget {
  const _NomeModelloDialog({required this.titolo, required this.suggerimento});

  final String titolo;
  final String suggerimento;

  @override
  State<_NomeModelloDialog> createState() => _NomeModelloDialogState();
}

class _NomeModelloDialogState extends State<_NomeModelloDialog> {
  late final _nome = TextEditingController(text: widget.suggerimento);
  String? _errore;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _conferma() {
    final errore = validaNomeModello(_nome.text);
    if (errore != null) {
      setState(() => _errore = errore);
      return;
    }
    Navigator.of(context).pop(_nome.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titolo),
      content: TextField(
        controller: _nome,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _conferma(),
        onChanged: (_) => setState(() => _errore = null),
        decoration: InputDecoration(labelText: 'Nome', errorText: _errore),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(onPressed: _conferma, child: const Text('Salva')),
      ],
    );
  }
}

/// Elenco dei modelli di un tipo da cui sceglierne uno (RF_GP_9): pasti
/// salvati per l'editor, piani modello per un piano nuovo. Si può anche
/// eliminare un modello (i piani già creati con esso non cambiano).
Future<ModelloPiano?> scegliModello(
  BuildContext context, {
  required ModelliRepository repository,
  required TipoModello tipo,
}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  return showModalBottomSheet<ModelloPiano>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ModelliSheet(repository: repository, tipo: tipo),
  );
}

class _ModelliSheet extends StatefulWidget {
  const _ModelliSheet({required this.repository, required this.tipo});

  final ModelliRepository repository;
  final TipoModello tipo;

  @override
  State<_ModelliSheet> createState() => _ModelliSheetState();
}

class _ModelliSheetState extends State<_ModelliSheet> {
  bool _caricamento = true;
  String? _errore;
  List<ModelloPiano> _modelli = [];

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final m = await widget.repository.elenco(widget.tipo);
      if (!mounted) return;
      setState(() {
        _modelli = m;
        _caricamento = false;
      });
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.messaggio;
        _caricamento = false;
      });
    }
  }

  Future<void> _elimina(ModelloPiano m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare «${m.nome}»?'),
        content: const Text(
          'I piani già creati con questo modello non cambiano.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.repository.elimina(m.id);
      if (mounted) setState(() => _modelli = [..._modelli]..remove(m));
    } on ErroreOperazione catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.messaggio)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    final altezza = MediaQuery.sizeOf(context).height * 0.7;
    return SafeArea(
      child: SizedBox(
        height: altezza,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                widget.tipo.etichetta,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: _caricamento
                  ? const CaricamentoView()
                  : _errore != null
                  ? ErroreView(messaggio: _errore!, onRiprova: _carica)
                  : _modelli.isEmpty
                  ? StatoVuotoView(
                      icona: Icons.bookmark_border,
                      titolo: widget.tipo == TipoModello.pasto
                          ? 'Nessun pasto salvato'
                          : 'Nessun piano modello',
                      messaggio: widget.tipo == TipoModello.pasto
                          ? 'Dal menu di un pasto scegli «Salva come modello».'
                          : 'Dal menu dell\'editor scegli «Salva piano come '
                                'modello».',
                    )
                  : ListView(
                      children: [
                        for (final m in _modelli)
                          ListTile(
                            key: Key('modello-${m.id}'),
                            title: Text(m.nome),
                            subtitle: Text(
                              m.descrizione,
                              style: TextStyle(color: c.testoSecondario),
                            ),
                            onTap: () => Navigator.of(context).pop(m),
                            trailing: IconButton(
                              tooltip: 'Elimina ${m.nome}',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _elimina(m),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
