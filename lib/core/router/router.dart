import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/modelli/profilo.dart';
import '../../domain/repository/auth_repository.dart';
import '../dipendenze.dart';
import '../tema/transizioni.dart';
import '../../presentation/auth/accesso_page.dart';
import '../../presentation/auth/nuova_password_page.dart';
import '../../presentation/auth/recupero_password_page.dart';
import '../../presentation/auth/registrazione_page.dart';
import '../../presentation/comuni/elimina_account_page.dart';
import '../../presentation/comuni/profilo_page.dart';
import '../../presentation/comuni/stati_view.dart';
import '../../presentation/nutrizionista/alimenti/alimento_personalizzato_page.dart';
import '../../presentation/nutrizionista/alimenti/ricerca_alimento_page.dart';
import '../../presentation/nutrizionista/calendario_page.dart';
import '../../presentation/nutrizionista/disponibilita_page.dart';
import '../../presentation/nutrizionista/invito_page.dart';
import '../../presentation/nutrizionista/nutrizionista_shell.dart';
import '../../presentation/nutrizionista/obiettivi_page.dart';
import '../../presentation/nutrizionista/pazienti_page.dart';
import '../../presentation/nutrizionista/piano/piano_editor_page.dart';
import '../../presentation/paziente/andamento_page.dart';
import '../../presentation/paziente/collegamento_page.dart';
import '../../presentation/paziente/dieta_page.dart';
import '../../presentation/paziente/oggi_page.dart';
import '../../presentation/paziente/paziente_shell.dart';
import '../../presentation/paziente/visite_page.dart';
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

  // Dal link di recupero si entra con una sessione di recupero: si resta sulla
  // scelta della nuova password finché non è salvata (UC_GA_4, passo 5).
  if (auth.inRecuperoPassword) {
    return percorso == Rotte.nuovaPassword ? null : Rotte.nuovaPassword;
  }
  if (percorso == Rotte.nuovaPassword) {
    return ruolo == null ? Rotte.accesso : homeDelRuolo(ruolo);
  }

  // Senza sessione si vedono solo le schermate pubbliche.
  if (ruolo == null) return pubblica ? null : Rotte.accesso;

  // Paziente non collegato: può solo inserire il codice di invito (UC_GI_2)
  // o uscire dal profilo. Succede dopo la registrazione con email da
  // confermare e dopo uno scollegamento.
  if (ruolo == Ruolo.paziente && !auth.collegato) {
    return percorso == Rotte.pazienteCollegamento ||
            percorso == Rotte.pazienteProfilo ||
            percorso == Rotte.eliminaAccount
        ? null
        : Rotte.pazienteCollegamento;
  }

  // Nutrizionista appena registrato: passo "disponibilità" (UC_GA_1, passo 8).
  if (ruolo == Ruolo.nutrizionista && auth.primoAccesso) {
    return percorso == Rotte.nutDisponibilita ? null : Rotte.nutDisponibilita;
  }

  final home = homeDelRuolo(ruolo);
  if (pubblica ||
      percorso == Rotte.caricamento ||
      percorso == '/' ||
      percorso == Rotte.pazienteCollegamento) {
    return home;
  }

  // Ogni ruolo resta nella propria area.
  if (percorso.startsWith('/paziente') && ruolo != Ruolo.paziente) return home;
  if (percorso.startsWith('/nutrizionista') && ruolo != Ruolo.nutrizionista) {
    return home;
  }
  return null;
}

/// Schede della barra in basso con dissolvenza al cambio di scheda.
Widget _schedeConDissolvenza(
  BuildContext context,
  StatefulNavigationShell navigazione,
  List<Widget> rami,
) => RamiConDissolvenza(indice: navigazione.currentIndex, rami: rami);

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
        builder: (context, stato) => AccessoPage(dip: dip),
      ),
      GoRoute(
        path: Rotte.registrazione,
        builder: (context, stato) => RegistrazionePage(dip: dip),
      ),
      GoRoute(
        path: Rotte.recuperoPassword,
        builder: (context, stato) => RecuperoPasswordPage(dip: dip),
      ),
      GoRoute(
        path: Rotte.nuovaPassword,
        builder: (context, stato) => NuovaPasswordPage(dip: dip),
      ),

      // ------------------------------------------------ paziente
      StatefulShellRoute(
        builder: (context, stato, navigazione) =>
            PazienteShell(navigazione: navigazione),
        navigatorContainerBuilder: _schedeConDissolvenza,
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
        path: Rotte.eliminaAccount,
        builder: (context, stato) => EliminaAccountPage(dip: dip),
      ),
      GoRoute(
        path: Rotte.pazienteCollegamento,
        builder: (context, stato) => CollegamentoPage(dip: dip),
      ),
      GoRoute(
        path: Rotte.pazienteProfilo,
        builder: (context, stato) =>
            ProfiloPage(dip: dip, mostraIndietro: true),
      ),

      // ------------------------------------------------ nutrizionista
      GoRoute(
        path: Rotte.nutDisponibilita,
        builder: (context, stato) => DisponibilitaPage(dip: dip),
      ),
      StatefulShellRoute(
        builder: (context, stato, navigazione) =>
            NutrizionistaShell(navigazione: navigazione),
        navigatorContainerBuilder: _schedeConDissolvenza,
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
                  GoRoute(
                    path: ':id/piano',
                    builder: (context, stato) => PianoEditorPage(
                      dip: dip,
                      pazienteId: stato.pathParameters['id']!,
                      nomePaziente: stato.extra is String
                          ? stato.extra! as String
                          : null,
                    ),
                  ),
                  GoRoute(
                    path: ':id/obiettivi',
                    builder: (context, stato) => ObiettiviPage(
                      repository: dip.obiettivi,
                      pazienteId: stato.pathParameters['id']!,
                      nomePaziente: stato.extra is String
                          ? stato.extra! as String
                          : null,
                    ),
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
                routes: [
                  GoRoute(
                    path: 'alimenti',
                    builder: (context, stato) => RicercaAlimentoPage(dip: dip),
                    routes: [
                      GoRoute(
                        path: 'nuovo',
                        builder: (context, stato) => AlimentoPersonalizzatoPage(
                          repository: dip.alimenti,
                          nomeIniziale: stato.extra is String
                              ? stato.extra! as String
                              : '',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
