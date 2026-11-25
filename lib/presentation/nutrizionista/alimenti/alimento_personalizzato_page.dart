import 'package:material_ui/material_ui.dart';

import '../../../domain/modelli/alimento.dart';
import '../../../domain/regole/validazione_alimento.dart';
import '../../../domain/repository/alimenti_repository.dart';
import '../../../domain/repository/pazienti_repository.dart';
import '../../comuni/controlli.dart';

/// Modulo per un alimento personalizzato (RF_GP_5): nome e valori per 100 g,
/// fonte "personalizzato". Al salvataggio restituisce l'[Alimento] creato.
class AlimentoPersonalizzatoPage extends StatefulWidget {
  const AlimentoPersonalizzatoPage({
    super.key,
    required this.repository,
    this.nomeIniziale = '',
  });

  final AlimentiRepository repository;
  final String nomeIniziale;

  @override
  State<AlimentoPersonalizzatoPage> createState() =>
      _AlimentoPersonalizzatoPageState();
}

class _AlimentoPersonalizzatoPageState
    extends State<AlimentoPersonalizzatoPage> {
  late final _nome = TextEditingController(text: widget.nomeIniziale);
  final _marca = TextEditingController();
  final _kcal = TextEditingController();
  final _proteine = TextEditingController();
  final _carboidrati = TextEditingController();
  final _grassi = TextEditingController();

  final Map<String, String?> _errori = {};
  ErroreOperazione? _errore;
  bool _inCorso = false;

  @override
  void dispose() {
    for (final c in [_nome, _marca, _kcal, _proteine, _carboidrati, _grassi]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pulisci(String campo) {
    if (_errori[campo] != null || _errore != null) {
      setState(() {
        _errori[campo] = null;
        _errore = null;
      });
    }
  }

  Future<void> _salva() async {
    final errori = <String, String?>{
      'nome': ValidazioneAlimento.nome(_nome.text),
      'kcal': ValidazioneAlimento.kcal(_kcal.text),
      'proteine': ValidazioneAlimento.macro(_proteine.text, 'Proteine'),
      'carboidrati': ValidazioneAlimento.macro(
        _carboidrati.text,
        'Carboidrati',
      ),
      'grassi': ValidazioneAlimento.macro(_grassi.text, 'Grassi'),
    };
    final p = ValidazioneAlimento.leggiNumero(_proteine.text);
    final c = ValidazioneAlimento.leggiNumero(_carboidrati.text);
    final g = ValidazioneAlimento.leggiNumero(_grassi.text);
    if (errori['proteine'] == null &&
        errori['carboidrati'] == null &&
        errori['grassi'] == null) {
      errori['grassi'] = ValidazioneAlimento.somma(p!, c!, g!);
    }
    setState(() {
      _errori
        ..clear()
        ..addAll(errori);
      _errore = null;
    });
    if (errori.values.any((e) => e != null)) return;

    setState(() => _inCorso = true);
    try {
      final creato = await widget.repository.creaPersonalizzato(
        nome: _nome.text,
        marca: _marca.text,
        kcal100g: ValidazioneAlimento.leggiNumero(_kcal.text)!,
        proteine100g: p!,
        carboidrati100g: c!,
        grassi100g: g!,
      );
      if (mounted) Navigator.of(context).pop<Alimento>(creato);
    } on ErroreOperazione catch (e) {
      // I campi restano compilati: si corregge o si riprova.
      if (mounted) setState(() => _errore = e);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    const numerica = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo alimento')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Inserisci i valori per 100 g di prodotto. L\'alimento resta '
                  'tra i tuoi e lo ritrovi nella ricerca.',
                  style: testo.bodyLarge,
                ),
                const SizedBox(height: 16),
                CampoTesto(
                  controller: _nome,
                  etichetta: 'Nome dell\'alimento',
                  errore: _errori['nome'],
                  azioneTastiera: TextInputAction.next,
                  onCambiato: (_) => _pulisci('nome'),
                ),
                const SizedBox(height: 12),
                CampoTesto(
                  controller: _marca,
                  etichetta: 'Marca (facoltativa)',
                  azioneTastiera: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                CampoTesto(
                  controller: _kcal,
                  etichetta: 'Calorie (kcal) per 100 g',
                  errore: _errori['kcal'],
                  tastiera: numerica,
                  azioneTastiera: TextInputAction.next,
                  onCambiato: (_) => _pulisci('kcal'),
                ),
                const SizedBox(height: 12),
                CampoTesto(
                  controller: _proteine,
                  etichetta: 'Proteine (g) per 100 g',
                  errore: _errori['proteine'],
                  tastiera: numerica,
                  azioneTastiera: TextInputAction.next,
                  onCambiato: (_) => _pulisci('proteine'),
                ),
                const SizedBox(height: 12),
                CampoTesto(
                  controller: _carboidrati,
                  etichetta: 'Carboidrati (g) per 100 g',
                  errore: _errori['carboidrati'],
                  tastiera: numerica,
                  azioneTastiera: TextInputAction.next,
                  onCambiato: (_) => _pulisci('carboidrati'),
                ),
                const SizedBox(height: 12),
                CampoTesto(
                  controller: _grassi,
                  etichetta: 'Grassi (g) per 100 g',
                  errore: _errori['grassi'],
                  tastiera: numerica,
                  azioneTastiera: TextInputAction.done,
                  onInvio: _salva,
                  onCambiato: (_) => _pulisci('grassi'),
                ),
                if (_errore != null) ...[
                  const SizedBox(height: 12),
                  MessaggioErrore(
                    messaggio: _errore!.messaggio,
                    onRiprova: _salva,
                  ),
                ],
                const SizedBox(height: 20),
                PulsantePrimario(
                  etichetta: 'Salva alimento',
                  onPressed: _salva,
                  inCorso: _inCorso,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
