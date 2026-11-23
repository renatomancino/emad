import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/dipendenze.dart';
import '../../core/tema/tema.dart';
import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';
import '../../domain/repository/pazienti_repository.dart';
import '../nutrizionista/abbonamento_view.dart';
import 'segnaposto_page.dart';

/// Profilo dell'utente con il logout (UC_GA_2, passi 7-8).
/// Nutrizionista: abbonamento (UC_GAD_3). Paziente: interruzione del
/// collegamento (UC_GI_5). Modifica dei dati ed eliminazione dell'account
/// arrivano con la scheda "Profilo ed eliminazione account" (UC_GA_3, UC_GA_5).
class ProfiloPage extends StatefulWidget {
  const ProfiloPage({
    super.key,
    required this.dip,
    this.mostraIndietro = false,
  });

  final Dipendenze dip;

  /// `true` quando la pagina è aperta sopra una sezione (paziente).
  final bool mostraIndietro;

  @override
  State<ProfiloPage> createState() => _ProfiloPageState();
}

class _ProfiloPageState extends State<ProfiloPage> {
  bool _inCorso = false;

  Future<bool> _conferma(String titolo, String testo, String azione) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titolo),
        content: Text(testo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Testi.annulla),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(azione),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _avvisa(String messaggio) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(messaggio)));
  }

  Future<void> _esci() async {
    if (!await _conferma(Testi.esci, Testi.esciConferma, Testi.esci)) return;
    setState(() => _inCorso = true);
    try {
      // Il router torna da solo alla schermata di accesso.
      await widget.dip.auth.esci();
    } on ErroreAuth catch (e) {
      await _avvisa(e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _scollegati() async {
    final ok = await _conferma(
      'Interrompere il collegamento?',
      'Il tuo nutrizionista non vedrà più i nuovi dati e le visite future '
          'verranno annullate. I dati già registrati restano nel suo storico. '
          'Per tornare a essere seguito servirà un nuovo invito.',
      'Interrompi',
    );
    if (!ok) return;
    setState(() => _inCorso = true);
    try {
      await widget.dip.pazienti.scollegati();
      await _avvisa('Collegamento interrotto.');
    } on ErroreOperazione catch (e) {
      await _avvisa(e.messaggio);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = widget.dip.auth.profilo;
    final nutrizionista = profilo?.ruolo == Ruolo.nutrizionista;
    final testo = Theme.of(context).textTheme;
    return Scaffold(
      appBar: widget.mostraIndietro
          ? AppBar(title: const Text(Testi.profilo))
          : IntestazioneSezione(
              titolo: nutrizionista
                  ? Testi.profiloAbbonamentoTitolo
                  : Testi.profilo,
              sottotitolo: profilo?.ruolo.etichetta,
            ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: const CircleAvatar(
                backgroundColor: ColoriCenato.primarioChiaro,
                child: Icon(Icons.person, color: ColoriCenato.primario),
              ),
              title: Text(profilo?.nome ?? '', style: testo.titleMedium),
              subtitle: Text(profilo?.ruolo.etichetta ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          if (nutrizionista)
            AbbonamentoView(repository: widget.dip.abbonamento)
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'In arrivo: dati del profilo, promemoria ed eliminazione '
                  'dell\'account (UC_GA_3, UC_GN_2, UC_GA_5).',
                  style: testo.bodyMedium?.copyWith(
                    color: ColoriCenato.testoSecondario,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _inCorso ? null : _scollegati,
              icon: const Icon(Icons.link_off),
              label: const Text('Interrompi il collegamento'),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _inCorso ? null : _esci,
            icon: const Icon(Icons.logout),
            label: const Text(Testi.esci),
          ),
        ],
      ),
    );
  }
}
