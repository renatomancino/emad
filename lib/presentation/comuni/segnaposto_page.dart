import 'package:material_ui/material_ui.dart';

import '../../core/costanti/testi.dart';
import '../../core/tema/tema.dart';
import 'componenti.dart';
import 'stati_view.dart';

/// Intestazione delle sezioni: titolo grande e sottotitolo su sfondo chiaro,
/// come nelle app salute (sostituisce la fascia verde dei mock-up del RAD).
///
/// L'altezza della barra è fissa, quindi il testo dell'intestazione segue la
/// dimensione di sistema solo fino a 1,3×: oltre, titolo e sottotitolo restano
/// comunque più grandi che al 100% (sono già testo grande) e non vanno mai in
/// overflow. Titolo e sottotitolo stanno su una riga con puntini. I colori
/// sono impostati qui: `titleTextStyle` del tema non viene ricolorato da
/// `foregroundColor`.
class IntestazioneSezione extends StatelessWidget
    implements PreferredSizeWidget {
  const IntestazioneSezione({
    super.key,
    required this.titolo,
    this.sottotitolo,
    this.azioni = const [],
  });

  /// Dimensione massima del testo dell'intestazione rispetto a quella di sistema.
  static const double scalaTestoMassima = 1.3;

  final String titolo;
  final String? sottotitolo;
  final List<Widget> azioni;

  @override
  Size get preferredSize => const Size.fromHeight(96);

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final c = context.colori;
    return AppBar(
      toolbarHeight: 96,
      backgroundColor: c.sfondo,
      titleSpacing: 20,
      actions: azioni,
      title: MediaQuery.withClampedTextScaling(
        maxScaleFactor: scalaTestoMassima,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              titolo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: testo.headlineMedium?.copyWith(
                color: c.testo,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (sottotitolo != null)
              Semantics(
                container: true,
                child: Text(
                  sottotitolo!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: testo.bodyMedium?.copyWith(color: c.testoSecondario),
                ),
              ),
          ],
        ),
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

/// Etichetta a pillola (es. "Seguito", "Da fare" nei mock-up). Il testo c'è
/// sempre: il colore del [tono] rinforza il significato, non lo sostituisce.
class EtichettaStato extends StatelessWidget {
  const EtichettaStato({
    super.key,
    required this.testo,
    this.tono = TonoStato.positivo,
  });

  final String testo;
  final TonoStato tono;

  @override
  Widget build(BuildContext context) {
    final c = context.colori;
    final (sfondo, colore) = switch (tono) {
      TonoStato.positivo => (c.primarioTonale, c.primario),
      TonoStato.attenzione => (c.avvisoTonale, c.avviso),
      TonoStato.errore => (c.erroreTonale, c.errore),
      TonoStato.neutro => (c.bordo, c.testoSecondario),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: sfondo, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          testo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colore,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
