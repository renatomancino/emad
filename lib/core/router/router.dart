import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';
import '../dipendenze.dart';
import '../../presentation/auth/prova_auth_page.dart';
import '../../presentation/auth/segnaposto_auth.dart';
import '../../presentation/comuni/profilo_page.dart';
import '../../presentation/comuni/stati_view.dart';
import '../../presentation/nutrizionista/calendario_page.dart';
import '../../presentation/nutrizionista/invito_page.dart';
import '../../presentation/nutrizionista/nutrizionista_shell.dart';
import '../../presentation/nutrizionista/pazienti_page.dart';
import '../../presentation/paziente/andamento_page.dart';
import '../../presentation/paziente/dieta_page.dart';
import '../../presentation/paziente/oggi_page.dart';
import '../../presentation/paziente/paziente_shell.dart';
import '../../presentation/paziente/visite_page.dart';
import '../costanti/testi.dart';
import 'rotte.dart';

/// Home del ruolo dopo l'accesso (UC_GA_2, passo 6): Oggi per il paziente,
/// elenco pazienti per il nutrizionista.
String homeDelRuolo(Ruolo ruolo) => switch (ruolo) {
  Ruolo.paziente => Rotte.pazienteOggi,
  Ruolo.nutrizionista => Rotte.nutPazienti,
};

/// Decide dove portare l'utente (guard). Separata dal router per poterla
/// testare: restituisce `null` se il percorso richiesto va bene.
String? reindirizza(AuthRepository auth, String percorso) {
  if (auth.inCaricamento) {
    return percorso == Rotte.caricamento ? null : Rotte.caricamento;
  }

  final ruolo = auth.ruolo;
  final pubblica = Rotte.pubbliche.contains(percorso);

  // Senza sessione si vedono solo le schermate pubbliche.
  if (ruolo == null) return pubblica ? null : Rotte.accesso;

  final home = homeDelRuolo(ruolo);
  if (pubblica || percorso == Rotte.caricamento || percorso == '/') return home;

  // Ogni ruolo resta nella propria area.
  if (percorso.startsWith('/paziente') && ruolo != Ruolo.paziente) return home;
  if (percorso.startsWith('/nutrizionista') && ruolo != Ruolo.nutrizionista) {
    return home;
  }
  return null;
}

/// Router dell'app (go_router). Si aggiorna quando cambia la sessione.
GoRouter creaRouter(Dipendenze dip) {
  final auth = dip.auth;
  return GoRouter(
    initialLocation: Rotte.caricamento,
    refreshListenable: auth,
    redirect: (context, stato) => reindirizza(auth, stato.matchedLocation),
    routes: [
      GoRoute(path: '/', redirect: (context, stato) => Rotte.caricamento),
      GoRoute(
        path: Rotte.caricamento,
        builder: (context, stato) => const Scaffold(body: CaricamentoView()),
      ),

      // ------------------------------------------------ pubbliche
      GoRoute(
        path: Rotte.accesso,
        builder: (context, stato) => ProvaAuthPage(auth: auth),
      ),
      GoRoute(
        path: Rotte.registrazione,
        builder: (context, stato) => const SegnapostoAuthPage(
          titolo: Testi.registrazione,
          descrizione:
              'La registrazione con scelta del ruolo, codice di invito e '
              'consenso al trattamento dei dati sanitari arriva nella fase 1 '
              '(UC_GA_1). Per ora usa l\'accesso di prova.',
        ),
      ),
      GoRoute(
        path: Rotte.recuperoPassword,
        builder: (context, stato) => const SegnapostoAuthPage(
          titolo: Testi.recuperoPassword,
          descrizione:
              'Il recupero della password via email arriva nella fase 1 '
              '(UC_GA_4).',
        ),
      ),

      // ------------------------------------------------ paziente
      StatefulShellRoute.indexedStack(
        builder: (context, stato, navigazione) =>
            PazienteShell(navigazione: navigazione),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.pazienteOggi,
                builder: (context, stato) => const OggiPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.pazienteDieta,
                builder: (context, stato) => const DietaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.pazienteAndamento,
                builder: (context, stato) => const AndamentoPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.pazienteVisite,
                builder: (context, stato) => const VisitePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Rotte.pazienteProfilo,
        builder: (context, stato) =>
            ProfiloPage(dip: dip, mostraIndietro: true),
      ),

      // ------------------------------------------------ nutrizionista
      StatefulShellRoute.indexedStack(
        builder: (context, stato, navigazione) =>
            NutrizionistaShell(navigazione: navigazione),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.nutPazienti,
                builder: (context, stato) => PazientiPage(dip: dip),
                routes: [
                  GoRoute(
                    path: 'invito',
                    builder: (context, stato) => InvitoPage(dip: dip),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.nutCalendario,
                builder: (context, stato) => const CalendarioPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Rotte.nutProfilo,
                builder: (context, stato) => ProfiloPage(dip: dip),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
