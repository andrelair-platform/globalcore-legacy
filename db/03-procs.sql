-- "Stored procedures" (PL/pgSQL) — business logic living IN the database, DB2-style.
-- The rating engine + the nightly-batch operations are here on purpose: this is a
-- classic legacy trait (rules embedded in the core, not in the app layer).
SET search_path TO gcore;

-- Rating engine: premium = sum-insured * LOB rate + net endorsement adjustments.
CREATE OR REPLACE FUNCTION gcore_calc_premium(p_polno CHAR, p_verno SMALLINT)
RETURNS NUMERIC LANGUAGE plpgsql SET search_path = gcore AS $$
DECLARE
    v_lob   CHAR(3);
    v_rate  NUMERIC(8,5);
    v_sum   NUMERIC(15,2);
    v_adj   NUMERIC(15,2);
    v_prem  NUMERIC(15,2);
BEGIN
    SELECT LOBCD INTO v_lob FROM GC_POLICY WHERE POLNO = p_polno;
    v_rate := CASE v_lob
                WHEN 'MAR' THEN 0.00200   -- marine
                WHEN 'PRO' THEN 0.00120   -- property
                WHEN 'AVI' THEN 0.00350   -- aviation
                ELSE 0.00150 END;
    SELECT SUMINS INTO v_sum FROM GC_POLVER WHERE POLNO = p_polno AND VERNO = p_verno;
    SELECT COALESCE(SUM(PREMADJ),0) INTO v_adj FROM GC_ENDMT WHERE POLNO = p_polno AND VERNO = p_verno;
    v_prem := ROUND(v_sum * v_rate, 2) + v_adj;
    UPDATE GC_POLVER SET PREMAMT = v_prem WHERE POLNO = p_polno AND VERNO = p_verno;
    RETURN v_prem;
END; $$;

-- Batch step 1: make PENDING policies official (the "not real-time" rule).
CREATE OR REPLACE FUNCTION gcore_activate_pending()
RETURNS INTEGER LANGUAGE plpgsql SET search_path = gcore AS $$
DECLARE v_cnt INTEGER;
BEGIN
    UPDATE GC_POLICY SET STATCD = 'A' WHERE STATCD = 'P';
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    RETURN v_cnt;
END; $$;

-- Batch step 2: generate renewal versions for active policies expiring within p_days.
-- Creates VERNO+1 (eff = old expiry, exp = +1 year), re-rates it, logs to GC_RENEW.
CREATE OR REPLACE FUNCTION gcore_gen_renewals(p_days INTEGER)
RETURNS INTEGER LANGUAGE plpgsql SET search_path = gcore AS $$
DECLARE
    r        RECORD;
    v_newver SMALLINT;
    v_cnt    INTEGER := 0;
BEGIN
    FOR r IN
        SELECT p.POLNO, v.VERNO, v.EXPDT, v.SUMINS
        FROM GC_POLICY p
        JOIN GC_POLVER v ON v.POLNO = p.POLNO
        WHERE p.STATCD = 'A'
          AND v.VERNO = (SELECT MAX(VERNO) FROM GC_POLVER x WHERE x.POLNO = p.POLNO)
          AND v.EXPDT <= CURRENT_DATE + p_days
    LOOP
        -- skip if a later version already exists for this expiry
        IF EXISTS (SELECT 1 FROM GC_POLVER x WHERE x.POLNO = r.POLNO AND x.EFFDT > r.EXPDT) THEN
            INSERT INTO GC_RENEW (POLNO, RENSTS) VALUES (r.POLNO, 'SKIPPED-EXISTS');
            CONTINUE;
        END IF;
        v_newver := r.VERNO + 1;
        INSERT INTO GC_POLVER (POLNO, VERNO, EFFDT, EXPDT, SUMINS, PREMAMT, VERSTS)
        VALUES (r.POLNO, v_newver, r.EXPDT, (r.EXPDT + INTERVAL '1 year')::date, r.SUMINS, 0, 'A');
        PERFORM gcore_calc_premium(r.POLNO, v_newver);
        INSERT INTO GC_RENEW (POLNO, NEWVER, NEWEFFDT, RENSTS)
        VALUES (r.POLNO, v_newver, r.EXPDT, 'GENERATED');
        v_cnt := v_cnt + 1;
    END LOOP;
    RETURN v_cnt;
END; $$;
