import 'package:material_ui/material_ui.dart';

import '../../../core/tema/tema.dart';
import '../../../domain/modelli/alimento.dart';
import '../../../domain/modelli/piano_alimentare.dart';
import '../../../domain/regole/calcoli_piano.dart';
import '../../../domain/repository/alimenti_repository.dart';
import '../../comuni/componenti.dart';
import '../alimenti/ricerca_alimento.dart' show formattaValore;
import 'aggiungi_alimento_page.dart';
import 'quantita_sheet.dart';
import 'riepilogo_giorno.dart';

/// Alternative ammesse per una voce del pasto (UC_GP_2 passo 6, RF_GP_6).
/// Sono le **uniche scelte** che il paziente avrà nel check-in "Alternativa":
/// si scelgono alimenti, non si scrive testo libero. Ogni alternativa mostra
/// il confronto con l'originale. Ogni modifica è riportata subito al piano
/// tramite [onCambia].
class AlternativePage extends StatefulWidget {
  const AlternativePage({
    super.key,
    required this.alimenti,
    required this.voce,
    required this.onCambia,
  });

  final AlimentiRepository alimenti;
  final VocePiano voce;
  final ValueChanged<List<AlternativaPiano>> onCambia;

  @override
  State<AlternativePage> createState() => _AlternativePageState();
}

class _AlternativePageState extends State<AlternativePage> {
  late List<AlternativaPiano> _alternative = [...widget.voce.alternative];

  void _cambia(List<AlternativaPiano> nuove) {
    setState(() => _alternative = nuove);
    widget.onCambia(nuove);
  }

  void _avvisa(String messaggio) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(messaggio)));

  Future<void> _aggiungi() async {
    final alimento = await Navigator.of(context).push<Alimento>(
      MaterialPageRoute(
        builder: (_) => AggiungiAlimentoPage(
          alimenti: widget.alimenti,
          etichettaConferma: 'Usa come alternativa',
        ),
      ),
    );
    if (alimento == null || !mounted) return;
    if (!alimento.completo || alimento.id == null) {
      _avvisa('«${alimento.nome}» non ha tutti i valori nutrizionali.');
      return;
    }
    if (alimento.id == widget.voce.alimento.id) {
      _avvisa('«${alimento.nome}» è già l\'alimento del pasto.');
      return;
    }
    if (_alternative.any((a) => a.alimento.id == alimento.id)) {
      _avvisa('«${alimento.nome}» è già tra le alternative.');
      return;
    }
    final q = await chiediQuantita(context, alimento: alimento);
    if (q == null || !mounted) return;
    _cambia([
      ..._alternative,
      AlternativaPiano(alimento: alimento, quantitaG: q),
    ]);
  }

  Future<void> _cambiaQuantita(int i) async {
    final a = _alternative[i];
    final q = await chiediQuantita(
      context,
      alimento: a.alimento,
      iniziale: a.quantitaG,
      etichettaConferma: 'Salva quantità',
    );
    if (q == null || !mounted) return;
    _cambia([
      for (var k = 0; k < _alternative.length; k++)
        if (k == i) _alternative[k].copyWith(quantitaG: q) else _alternative[k],
    ]);
  }

  void _togli(int i) => _cambia([
    for (var k = 0; k < _alternative.length; k++)
      if (k != i) _alternative[k],
  ]);

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    final voce = widget.voce;
    final originale = macroVoce(voce.alimento, voce.quantitaG);
    return Scaffold(
      appBar: AppBar(title: const Text('Alternative')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Invece di', style: testo.labelLarge),
                const SizedBox(height: 4),
                SchedaSezione(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(voce.alimento.nome, style: testo.titleMedium),
                      Text(
                        '${formattaValore(voce.quantitaG)} g · '
                        '${kcalTesto(originale.kcal)} kcal',
                        style: testo.bodyMedium?.copyWith(
                          color: c.testoSecondario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Il paziente potrà scegliere solo tra queste nel check-in '
                  '«Alternativa».',
                  style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
                ),
                const SizedBox(height: 8),
                if (_alternative.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Nessuna alternativa ancora.',
                      key: const Key('nessuna-alternativa'),
                      style: testo.bodyLarge,
                    ),
                  ),
                for (var i = 0; i < _alternative.length; i++) ...[
                  _RigaAlternativa(
                    chiave: Key('alternativa-$i'),
                    alternativa: _alternative[i],
                    voce: voce,
                    onTap: () => _cambiaQuantita(i),
                    onTogli: () => _togli(i),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _aggiungi,
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi alternativa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RigaAlternativa extends StatelessWidget {
  const _RigaAlternativa({
    required this.chiave,
    required this.alternativa,
    required this.voce,
    required this.onTap,
    required this.onTogli,
  });

  final Key chiave;
  final AlternativaPiano alternativa;
  final VocePiano voce;
  final VoidCallback onTap;
  final VoidCallback onTogli;

  @override
  Widget build(BuildContext context) {
    final macro = macroVoce(alternativa.alimento, alternativa.quantitaG);
    final diff = differenzaAlternativa(voce, alternativa).kcal;
    final confronto = diff.round() == 0
        ? 'stesse kcal dell\'originale'
        : '${conSegno(diff)} kcal rispetto all\'originale';
    return RigaElenco(
      key: chiave,
      onTap: onTap,
      titolo: alternativa.alimento.nome,
      sottotitolo:
          '${formattaValore(alternativa.quantitaG)} g · '
          '${kcalTesto(macro.kcal)} kcal · $confronto',
      trailing: IconButton(
        tooltip: 'Togli ${alternativa.alimento.nome}',
        icon: const Icon(Icons.delete_outline),
        onPressed: onTogli,
      ),
    );
  }
}
