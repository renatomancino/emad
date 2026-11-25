# Campioni di risposte di Open Food Facts

- `off_prodotto_<codice>.json`: risposte **vere** di `GET /api/v2/product/<codice>` (25/11/2026, campi `code, product_name, product_name_it, brands, nutriments`), usate per provare il parsing.
- `off_ricerca_pane.json`: busta nella forma della ricerca per nome (`count`, `page`, `page_size`, `products`). Quando è stata scritta gli endpoint di ricerca di Open Food Facts rispondevano 503 dal container di sviluppo, quindi **la busta è costruita a mano** con i quattro prodotti veri sopra più quattro varianti sintetiche (codici `99999999999xx`): senza kcal, con solo kJ, senza nome, duplicato di un nome già presente. Sostituire con una risposta vera appena la ricerca torna raggiungibile.
