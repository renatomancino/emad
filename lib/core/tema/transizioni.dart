import 'package:material_ui/material_ui.dart';

/// Transizione di pagina che rispetta "riduci animazioni" del telefono: in
/// quel caso la pagina compare senza effetti. Altrimenti usa [delegato].
class TransizionePagina extends PageTransitionsBuilder {
  const TransizionePagina(this.delegato);

  final PageTransitionsBuilder delegato;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegato.delegatedTransition;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return delegato.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Durata della dissolvenza tra le schede della barra in basso.
const Duration durataDissolvenzaSchede = Duration(milliseconds: 220);

/// Contenitore delle schede della barra in basso (una per ramo di
/// navigazione): cambiando scheda la nuova compare in dissolvenza mentre la
/// precedente svanisce. Ogni scheda ha la propria animazione, che riparte
/// dal punto in cui si trova: cambi rapidi (A→B→A, A→B→C) non fanno scatti.
/// Come un `IndexedStack`, tutte le schede restano vive: testo digitato e
/// posizione di scorrimento non si perdono; quelle nascoste sono fuori
/// schermo, senza tocchi, senza semantica e senza animazioni in corso.
/// Con "riduci animazioni" il cambio è immediato.
class RamiConDissolvenza extends StatefulWidget {
  const RamiConDissolvenza({
    super.key,
    required this.indice,
    required this.rami,
  });

  final int indice;
  final List<Widget> rami;

  @override
  State<RamiConDissolvenza> createState() => _RamiConDissolvenzaState();
}

class _RamiConDissolvenzaState extends State<RamiConDissolvenza> {
  /// Schede che stanno ancora svanendo: restano visibili fino a fine animazione.
  final Set<int> _inUscita = {};

  @override
  void didUpdateWidget(RamiConDissolvenza vecchio) {
    super.didUpdateWidget(vecchio);
    if (vecchio.indice == widget.indice) return;
    _inUscita.remove(widget.indice);
    if (MediaQuery.disableAnimationsOf(context)) {
      _inUscita.clear();
    } else {
      _inUscita.add(vecchio.indice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final durata = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : durataDissolvenzaSchede;
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.rami.length; i++)
          // Stessa struttura per ogni scheda, così non viene ricreata.
          Builder(
            builder: (context) {
              final attiva = i == widget.indice;
              final visibile = attiva || _inUscita.contains(i);
              return Offstage(
                offstage: !visibile,
                child: IgnorePointer(
                  ignoring: !attiva,
                  child: ExcludeSemantics(
                    excluding: !attiva,
                    child: TickerMode(
                      enabled: visibile,
                      child: AnimatedOpacity(
                        key: ValueKey('dissolvenza-$i'),
                        opacity: attiva ? 1 : 0,
                        duration: durata,
                        onEnd: () {
                          if (i != widget.indice && _inUscita.remove(i)) {
                            setState(() {});
                          }
                        },
                        child: widget.rami[i],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
