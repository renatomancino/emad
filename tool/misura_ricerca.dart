// Misura i tempi della ricerca alimenti su Open Food Facts (RNF_P_3: meno di
// 2 secondi in condizioni normali) con lo stesso client dell'app.
//
//   dart run tool/misura_ricerca.dart                 # pane latte pasta mela
//   dart run tool/misura_ricerca.dart riso uova       # altri termini
//
// Per ogni termine stampa i risultati e i millisecondi; un errore del servizio
// (503, timeout, rete assente) è un esito previsto, non un guasto dello script.
import 'dart:io';

import 'package:cenato/data/open_food_facts/open_food_facts_client.dart';
import 'package:cenato/domain/repository/alimenti_repository.dart';

Future<void> main(List<String> args) async {
  final termini = args.isEmpty ? ['pane', 'latte', 'pasta', 'mela'] : args;
  final client = OpenFoodFactsClient();
  stdout.writeln('User-Agent: ${client.userAgent}\n');

  for (final termine in termini) {
    final orologio = Stopwatch()..start();
    try {
      final trovati = await client.cercaPerNome(termine);
      final ms = orologio.elapsedMilliseconds;
      final incompleti = trovati.where((a) => !a.completo).length;
      stdout.writeln(
        '"$termine": ${trovati.length} risultati in $ms ms '
        '($incompleti incompleti) ${ms < 2000 ? 'OK' : 'OLTRE 2 s'}',
      );
      for (final a in trovati.take(3)) {
        stdout.writeln(
          '   - ${a.nome}${a.marca == null ? '' : ' (${a.marca})'}: '
          '${a.kcal100g ?? '?'} kcal',
        );
      }
    } on ServizioAlimentiNonDisponibile catch (e) {
      stdout.writeln(
        '"$termine": servizio non disponibile dopo '
        '${orologio.elapsedMilliseconds} ms (${e.dettaglio})',
      );
    }
  }

  // Ricerca per codice a barre (Nutella), riusata dalla scheda barcode.
  final orologio = Stopwatch()..start();
  try {
    final nutella = await client.perCodiceBarre('3017620422003');
    stdout.writeln(
      '\ncodice a barre 3017620422003: ${nutella?.nome ?? 'non trovato'} in '
      '${orologio.elapsedMilliseconds} ms',
    );
  } on ServizioAlimentiNonDisponibile catch (e) {
    stdout.writeln(
      '\ncodice a barre: servizio non disponibile (${e.dettaglio})',
    );
  }
  exit(0);
}
