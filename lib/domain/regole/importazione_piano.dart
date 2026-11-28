import '../modelli/alimento.dart';
import '../modelli/piano_alimentare.dart';
import '../modelli/riga_csv_piano.dart';

/// Regole dell'importazione di un piano da file (RF_GP_11, UC_GP_5): funzioni
/// pure, senza rete né interfaccia.

const _accenti = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  '’': "'",
  '‘': "'",
  '´': "'",
  '`': "'",
};

/// Forma di confronto di un nome: minuscolo, senza accenti, apostrofi
/// uniformati, spazi singoli. "Fiocchi  d’Avena" = "fiocchi d'avena".
String normalizzaNome(String testo) => testo
    .toLowerCase()
    .split('')
    .map((c) => _accenti[c] ?? c)
    .join()
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// 1-7 da "Lunedì", "lunedi", "lun" o "1"; `null` se non si riconosce.
int? giornoDaTesto(String testo) {
  final t = normalizzaNome(testo);
  for (final g in GiorniSettimana.tutti) {
    if (t == '$g' ||
        t == normalizzaNome(GiorniSettimana.nome(g)) ||
        t == normalizzaNome(GiorniSettimana.abbreviato(g))) {
      return g;
    }
  }
  return null;
}

/// Il tipo di pasto dal suo nome; `null` se non si riconosce. (Non si usa
/// `TipoPasto.daDb`, che in quel caso ripiega sullo spuntino.)
TipoPasto? pastoDaTesto(String testo) {
  final t = normalizzaNome(testo);
  for (final p in TipoPasto.values) {
    if (t == p.valoreDb || t == normalizzaNome(p.etichetta)) return p;
  }
  return null;
}

/// L'alimento da abbinare **da solo** a [nome]: il primo di [candidati] con il
/// nome identico (a meno di [normalizzaNome]) e con tutti i valori. I nomi
/// solo simili li sceglie il nutrizionista: un abbinamento sbagliato
/// cambierebbe kcal e macro senza che se ne accorga.
Alimento? corrispondenzaEsatta(String nome, Iterable<Alimento> candidati) {
  final cercato = normalizzaNome(nome);
  for (final a in candidati) {
    if (a.completo && normalizzaNome(a.nome) == cercato) return a;
  }
  return null;
}

/// La **bozza** del piano dalle righe abbinate (UC_GP_5, passo 7): giorni in
/// ordine di settimana, pasti in ordine di giornata con l'orario proposto,
/// voci nell'ordine del file. Non salva nulla: la bozza si apre nell'editor.
PianoAlimentare costruisciBozza(
  List<(RigaCsvPiano, Alimento)> righe, {
  required DateTime dataInizio,
}) => PianoAlimentare(
  dataInizio: dataInizio,
  giorni: [
    for (final g in GiorniSettimana.tutti)
      if (righe.any((r) => r.$1.giorno == g))
        GiornoPiano(
          giornoSettimana: g,
          pasti: [
            for (final tipo in TipoPasto.values)
              if (righe.any((r) => r.$1.giorno == g && r.$1.pasto == tipo))
                PastoPiano(
                  tipo: tipo,
                  orario: tipo.orarioPredefinito,
                  voci: [
                    for (final (riga, alimento) in righe)
                      if (riga.giorno == g && riga.pasto == tipo)
                        VocePiano(
                          alimento: alimento,
                          quantitaG: riga.quantitaG,
                        ),
                  ],
                ),
          ],
        ),
  ],
);
