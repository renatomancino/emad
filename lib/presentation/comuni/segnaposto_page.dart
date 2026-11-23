import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/tema/tema.dart';
import 'stati_view.dart';

/// Intestazione delle sezioni come nei mock-up: titolo e sottotitolo
/// bianchi su verde (UI_GD_1, UI_GP_1, UI_GM_1).
class IntestazioneSezione extends StatelessWidget
    implements PreferredSizeWidget {
  const IntestazioneSezione({
    super.key,
    required this.titolo,
    this.sottotitolo,
    this.azioni = const [],
  });

  final String titolo;
  final String? sottotitolo;
  final List<Widget> azioni;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    return AppBar(
      toolbarHeight: 76,
      actions: azioni,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titolo,
            style: testo.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sottotitolo != null)
            Text(
              sottotitolo!,
              style: testo.bodyMedium?.copyWith(color: Colors.white70),
            ),
        ],
      ),
    );
  }
}

/// Schermata segnaposto di una sezione ancora da implementare.
/// Indica quale caso d'uso la riempirà, così chi prova l'app sa cosa aspettarsi.
class SegnapostoPage extends StatelessWidget {
  const SegnapostoPage({
    super.key,
    required this.titolo,
    required this.icona,
    required this.descrizione,
    this.sottotitolo,
    this.azioni = const [],
    this.contenutoExtra,
  });

  final String titolo;
  final String? sottotitolo;
  final IconData icona;
  final String descrizione;
  final List<Widget> azioni;
  final Widget? contenutoExtra;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: IntestazioneSezione(
        titolo: titolo,
        sottotitolo: sottotitolo,
        azioni: azioni,
      ),
      body: Column(
        children: [
          Expanded(
            child: StatoVuotoView(
              icona: icona,
              titolo: '$titolo · ${Testi.inArrivo.toLowerCase()}',
              messaggio: descrizione,
            ),
          ),
          if (contenutoExtra != null)
            Padding(padding: const EdgeInsets.all(16), child: contenutoExtra),
        ],
      ),
    );
  }
}

/// Etichetta a pillola (es. "Seguito", "Da fare" nei mock-up).
class EtichettaStato extends StatelessWidget {
  const EtichettaStato({super.key, required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const ShapeDecoration(
        color: ColoriCenato.primarioChiaro,
        shape: StadiumBorder(),
      ),
      child: Text(
        testo,
        style: const TextStyle(
          color: ColoriCenato.primario,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
