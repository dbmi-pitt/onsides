-- Post-load synchronization script to reset sequences
-- This ensures that after a bulk load (e.g., via pg_restore or COPY),
-- the sequences pick up from the maximum ID.

DO $$
DECLARE
    rec record;
    max_val bigint;
    seq_name text;
BEGIN
    FOR rec IN
        SELECT
            table_schema,
            table_name,
            column_name
        FROM information_schema.columns
        WHERE is_identity = 'YES'
        -- Adjust schema if necessary, currently targeting public
        AND table_schema = 'public' 
    LOOP
        -- Construct the sequence name using pg_get_serial_sequence
        seq_name := pg_get_serial_sequence(format('%I.%I', rec.table_schema, rec.table_name), rec.column_name);

        IF seq_name IS NOT NULL THEN
            -- Get the maximum value from the table
            EXECUTE format('SELECT MAX(%I) FROM %I.%I', rec.column_name, rec.table_schema, rec.table_name) INTO max_val;

            IF max_val IS NOT NULL THEN
                -- Reset the sequence to the maximum value found.
                -- The next value generated will be max_val + 1 (assuming default increment).
                PERFORM setval(seq_name, max_val);
                RAISE NOTICE 'Updated sequence % for table %.% column % to %', seq_name, rec.table_schema, rec.table_name, rec.column_name, max_val;
            ELSE
                 -- Optional: Reset to start value if empty? Or leave as is.
                 -- If table is empty, usually we don't need to bump sequence unless it was already used.
                 RAISE NOTICE 'Table %.% column % is empty, skipping sequence update.', rec.table_schema, rec.table_name, rec.column_name;
            END IF;
        END IF;
    END LOOP;
END $$;
