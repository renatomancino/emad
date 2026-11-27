-- =============================================================================
-- Cenato · 009_codice_barre_personalizzati.sql
-- Codice a barre unico per fonte e per nutrizionista · RF_GP_4, RF_GP_5, UC_GP_3
-- Scheda Trello: [MC] Scansione barcode. Scelta annotata in
-- docs/decisioni-sviluppo.md (D28).
--
-- Prima (001) `alimenti.codice_barre` era unico in tutta la tabella. Con la
-- scansione, un prodotto che Open Food Facts non conosce si inserisce a mano
-- come alimento PERSONALIZZATO con il codice letto (SC_GP_2, passo 5). Ma i
-- personalizzati sono privati (007): se Giulia ha già inserito il codice X,
-- Elena non lo vede e, inserendo anche lei X, riceverebbe un errore di
-- unicità che le rivela un dato altrui e le impedisce di lavorare.
-- Ora:
--   * gli alimenti di Open Food Facts restano unici per codice (la cache
--     condivisa non si duplica);
--   * tra i personalizzati, un codice si ripete al massimo una volta per
--     nutrizionista;
--   * un personalizzato e uno di Open Food Facts possono avere lo stesso codice
--     (il prodotto compare su Open Food Facts dopo che lo si era inserito a
--     mano): l'app preferisce il personalizzato proprio.
-- =============================================================================

alter table public.alimenti drop constraint if exists alimenti_codice_barre_key;

create unique index if not exists alimenti_codice_barre_off_key
  on public.alimenti (codice_barre)
  where fonte = 'open_food_facts' and codice_barre is not null;

create unique index if not exists alimenti_codice_barre_personalizzato_key
  on public.alimenti (creato_da, codice_barre)
  where fonte = 'personalizzato' and codice_barre is not null;

-- La scansione cerca per codice qualunque sia la fonte.
create index if not exists alimenti_codice_barre_idx
  on public.alimenti (codice_barre)
  where codice_barre is not null;

comment on column public.alimenti.codice_barre is
  'EAN-13/EAN-8 (UPC come EAN-13). Unico tra gli alimenti di Open Food Facts; tra i personalizzati unico per nutrizionista (009). RF_GP_4.';
