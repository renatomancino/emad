# Campioni di risposte di Open Food Facts

Risposte **vere** dell'API, salvate il 25/11/2026 con gli stessi parametri e campi che usa il client (`code, product_name, product_name_it, brands, nutriments`):

- `off_ricerca_pane_italia.json`: `GET /cgi/search.pl?search_terms=pane&...&tagtype_0=countries&tag_contains_0=contains&tag_0=italy` (20 prodotti). Contiene casi reali utili ai test: un prodotto senza nome, uno con `energy-kcal_100g` assurdo (1289 kcal, ma 950 kJ coerenti), risultati poco pertinenti ("Wasa", "Piadelle") e nomi in francese.
- `off_prodotto_<codice>.json`: `GET /api/v2/product/<codice>` per Nutella, spaghetti Barilla, biscotti e Nocciolata.

Le varianti (senza kcal, solo kJ, duplicati) si costruiscono nei test modificando questi file.
