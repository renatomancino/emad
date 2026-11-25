-- =============================================================================
-- Cenato · 008_salva_piano.sql
-- Salvataggio e assegnazione del piano alimentare come NUOVA VERSIONE, in una
-- sola transazione · RF_GP_1, RF_GP_2, RF_GP_7 · UC_GP_1, UC_GP_2
-- Scheda Trello: [RM] Editor del piano: giorni, pasti, quantità, macro e scostamento.
--
-- Perché una RPC: le policy di 002 permettono di scrivere la struttura solo su
-- una versione in `bozza`, e per assegnarla bisogna poi scambiare la versione
-- `corrente`. Fatto dall'app, sarebbero molte chiamate: se la rete cade a metà
-- il paziente potrebbe restare senza piano. Qui è tutto o niente.
--
-- Cosa fa `public.salva_piano(paziente, data_inizio, struttura)`:
--   1. controlla che il chiamante sia il nutrizionista di un paziente ATTIVO;
--   2. controlla la struttura (giorni, pasti con almeno un alimento, quantità);
--   3. crea la versione n+1, la riempie e ricalcola kcal e macro di ogni voce
--      dai valori per 100 g dell'alimento (l'app non può falsarli);
--   4. porta la versione corrente precedente a `superato` e la nuova a
--      `corrente`. Le versioni vecchie restano: i check-in già registrati
--      restano legati ai loro pasti (UC_GP_1, note).
--
-- Formato di `struttura` (alternative facoltative, le gestisce la scheda
-- "Alternative…" ma qui si conservano già):
--   {"giorni":[{"giorno":1,"pasti":[{"tipo":"colazione","orario":"08:00",
--      "voci":[{"alimento_id":"…","quantita_g":200,
--               "alternative":[{"alimento_id":"…","quantita_g":35}]}]}]}]}
--
-- Codici di errore (SQLSTATE), oltre a quelli di 002 e 004:
--   CN020 paziente non tuo o non attivo   CN021 struttura del piano non valida
--   CN022 pasto senza alimenti            CN023 alimento non disponibile
--   CN024 quantità non valida
--
-- Aggancio per la scheda Notifiche: alla fine di `salva_piano` va creata la
-- notifica `nuovo_piano` per il paziente (RF_GN_*): è il punto segnato sotto.
-- =============================================================================

-- Massimo di grammi per voce accettato dal database (l'app è più prudente).
-- Tiene la riga dentro numeric(6,1) con ampio margine.
create or replace function privato.quantita_max_g()
returns numeric language sql immutable set search_path = '' as $$ select 10000::numeric $$;

-- L'alimento può essere messo in un piano da questo nutrizionista? Stessa regola
-- di lettura della cache (007): Open Food Facts, senza proprietario o suo.
create or replace function privato.alimento_usabile(p_alimento uuid, p_nutrizionista uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.alimenti
    where id = p_alimento
      and (fonte = 'open_food_facts' or creato_da is null or creato_da = p_nutrizionista)
  );
$$;

create or replace function public.salva_piano(
  p_paziente    uuid,
  p_data_inizio date,
  p_struttura   jsonb
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_nut        uuid := (select auth.uid());
  v_piano      uuid;
  v_versione   integer;
  v_inizio     date := coalesce(p_data_inizio, current_date);
  v_giorno     jsonb; v_pasto jsonb; v_voce jsonb; v_alt jsonb;
  v_giorno_id  uuid;  v_pasto_id uuid; v_voce_id uuid;
  v_n_giorno   smallint; v_tipo public.tipo_pasto; v_orario time;
  v_q          numeric; v_alim_id uuid;
  v_ordine_p   smallint; v_ordine_v smallint;
  v_visti      smallint[] := '{}';
  v_al         public.alimenti%rowtype;
begin
  if v_nut is null or not privato.e_nutrizionista() then
    raise exception using errcode = 'CN020',
      message = 'Solo il nutrizionista può assegnare un piano.';
  end if;

  -- Blocca la riga del paziente: due salvataggi insieme non creano due versioni uguali.
  perform 1 from public.pazienti
   where id = p_paziente and nutrizionista_id = v_nut and stato = 'attivo'
   for update;
  if not found then
    raise exception using errcode = 'CN020',
      message = 'Puoi assegnare un piano solo a un tuo paziente attivo.';
  end if;

  if p_struttura is null or jsonb_typeof(p_struttura -> 'giorni') <> 'array'
     or jsonb_array_length(p_struttura -> 'giorni') = 0 then
    raise exception using errcode = 'CN021',
      message = 'Il piano non ha giorni: aggiungi almeno un giorno con i suoi pasti.';
  end if;

  select coalesce(max(versione), 0) + 1 into v_versione
    from public.piani where paziente_id = p_paziente;

  -- La versione corrente diventa "superata" PRIMA di creare la nuova (indice
  -- univoco: una sola `corrente` per paziente). La data di fine non precede mai l'inizio.
  update public.piani
     set stato = 'superato',
         data_fine = greatest(data_inizio, v_inizio - 1)
   where paziente_id = p_paziente and stato = 'corrente';

  insert into public.piani (paziente_id, nutrizionista_id, versione, stato, data_inizio)
  values (p_paziente, v_nut, v_versione, 'corrente', v_inizio)
  returning id into v_piano;

  for v_giorno in select * from jsonb_array_elements(p_struttura -> 'giorni') loop
    begin
      v_n_giorno := (v_giorno ->> 'giorno')::smallint;
    exception when others then
      raise exception using errcode = 'CN021', message = 'Un giorno del piano non è valido.';
    end;
    if v_n_giorno is null or v_n_giorno not between 1 and 7 or v_n_giorno = any (v_visti) then
      raise exception using errcode = 'CN021',
        message = 'I giorni del piano devono essere da 1 (lunedì) a 7 (domenica), senza ripetizioni.';
    end if;
    v_visti := v_visti || v_n_giorno;

    if jsonb_typeof(v_giorno -> 'pasti') <> 'array' or jsonb_array_length(v_giorno -> 'pasti') = 0 then
      raise exception using errcode = 'CN021',
        message = 'Un giorno del piano non ha pasti: aggiungili o togli il giorno.';
    end if;

    insert into public.giorni (piano_id, giorno_settimana) values (v_piano, v_n_giorno)
    returning id into v_giorno_id;

    v_ordine_p := 0;
    for v_pasto in select * from jsonb_array_elements(v_giorno -> 'pasti') loop
      v_ordine_p := v_ordine_p + 1;
      begin
        v_tipo := (v_pasto ->> 'tipo')::public.tipo_pasto;
        v_orario := nullif(v_pasto ->> 'orario', '')::time;
      exception when others then
        raise exception using errcode = 'CN021', message = 'Un pasto del piano non è valido.';
      end;

      if jsonb_typeof(v_pasto -> 'voci') <> 'array' or jsonb_array_length(v_pasto -> 'voci') = 0 then
        raise exception using errcode = 'CN022',
          message = 'Un pasto è senza alimenti: completalo o eliminalo.';
      end if;

      insert into public.pasti (giorno_id, tipo, orario, ordine)
      values (v_giorno_id, v_tipo, v_orario, v_ordine_p)
      returning id into v_pasto_id;

      v_ordine_v := 0;
      for v_voce in select * from jsonb_array_elements(v_pasto -> 'voci') loop
        v_ordine_v := v_ordine_v + 1;
        begin
          v_alim_id := (v_voce ->> 'alimento_id')::uuid;
          v_q := (v_voce ->> 'quantita_g')::numeric;
        exception when others then
          raise exception using errcode = 'CN021', message = 'Una voce del piano non è valida.';
        end;
        if v_q is null or v_q <= 0 or v_q > privato.quantita_max_g() then
          raise exception using errcode = 'CN024',
            message = 'La quantità di ogni alimento deve essere maggiore di zero.';
        end if;
        if not privato.alimento_usabile(v_alim_id, v_nut) then
          raise exception using errcode = 'CN023',
            message = 'Un alimento del piano non è più disponibile: sostituiscilo.';
        end if;
        select * into v_al from public.alimenti where id = v_alim_id;

        insert into public.voci_pasto
          (pasto_id, alimento_id, quantita_g, kcal, proteine_g, carboidrati_g, grassi_g, ordine)
        values (v_pasto_id, v_alim_id, round(v_q, 1),
                round(v_al.kcal_100g * v_q / 100, 1),
                round(v_al.proteine_100g * v_q / 100, 1),
                round(v_al.carboidrati_100g * v_q / 100, 1),
                round(v_al.grassi_100g * v_q / 100, 1),
                v_ordine_v)
        returning id into v_voce_id;

        if jsonb_typeof(v_voce -> 'alternative') = 'array' then
          for v_alt in select * from jsonb_array_elements(v_voce -> 'alternative') loop
            begin
              v_alim_id := (v_alt ->> 'alimento_id')::uuid;
              v_q := (v_alt ->> 'quantita_g')::numeric;
            exception when others then
              raise exception using errcode = 'CN021', message = 'Un''alternativa del piano non è valida.';
            end;
            if v_q is null or v_q <= 0 or v_q > privato.quantita_max_g() then
              raise exception using errcode = 'CN024',
                message = 'La quantità di ogni alimento deve essere maggiore di zero.';
            end if;
            if not privato.alimento_usabile(v_alim_id, v_nut) then
              raise exception using errcode = 'CN023',
                message = 'Un alimento del piano non è più disponibile: sostituiscilo.';
            end if;
            insert into public.alternative (voce_id, alimento_id, quantita_g)
            values (v_voce_id, v_alim_id, round(v_q, 1));
          end loop;
        end if;
      end loop;
    end loop;
  end loop;

  -- >>> Aggancio notifica `nuovo_piano` per il paziente (scheda Notifiche). <<<

  return v_piano;
end;
$$;

revoke all on function public.salva_piano(uuid, date, jsonb) from public, anon;
grant execute on function public.salva_piano(uuid, date, jsonb) to authenticated;
grant execute on function privato.quantita_max_g() to authenticated;
grant execute on function privato.alimento_usabile(uuid, uuid) to authenticated;

comment on function public.salva_piano(uuid, date, jsonb) is
  'Salva e assegna il piano come nuova versione (RF_GP_1, RF_GP_2, RF_GP_7). Tutto o niente.';
