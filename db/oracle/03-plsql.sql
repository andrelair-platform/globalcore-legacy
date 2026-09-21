-- GlobalCore (Oracle) — CLAIMS business logic IN the database (S002). Classic legacy trait:
-- claim creation, reserve calc, the state machine and the audit all live in PL/SQL, not the app layer.

CREATE OR REPLACE PACKAGE PKG_CLAIMS AS
    -- Allocates the claim number + the initial state (N). The ACL calls this over SOAP (S003).
    PROCEDURE PROC_CREATE_CLAIM(
        p_polno  IN  GC_CLAIM.POLNO%TYPE,
        p_lossdt IN  GC_CLAIM.LOSSDT%TYPE,
        p_prlcd  IN  GC_CLAIM.PRLCD%TYPE,
        p_clmtnm IN  GC_CLAIM.CLMTNM%TYPE,
        o_clmno  OUT GC_CLAIM.CLMNO%TYPE
    );
    -- Suggested initial reserve = a peril-weighted fraction of the policy sum insured.
    FUNCTION FUNC_CALCULATE_RESERVE(p_clmno IN GC_CLAIM.CLMNO%TYPE) RETURN NUMBER;
END PKG_CLAIMS;
/

CREATE OR REPLACE PACKAGE BODY PKG_CLAIMS AS

    PROCEDURE PROC_CREATE_CLAIM(
        p_polno  IN  GC_CLAIM.POLNO%TYPE,
        p_lossdt IN  GC_CLAIM.LOSSDT%TYPE,
        p_prlcd  IN  GC_CLAIM.PRLCD%TYPE,
        p_clmtnm IN  GC_CLAIM.CLMTNM%TYPE,
        o_clmno  OUT GC_CLAIM.CLMNO%TYPE
    ) IS
    BEGIN
        o_clmno := 'CLM-' || TO_CHAR(SYSDATE, 'YYYY') || '-' ||
                   LPAD(TO_CHAR(GC_CLMSEQ.NEXTVAL), 6, '0');
        INSERT INTO GC_CLAIM (CLMNO, POLNO, LOSSDT, PRLCD, CLMTNM, STATCD)
        VALUES (o_clmno, p_polno, p_lossdt, p_prlcd, p_clmtnm, 'N');
    END PROC_CREATE_CLAIM;

    FUNCTION FUNC_CALCULATE_RESERVE(p_clmno IN GC_CLAIM.CLMNO%TYPE) RETURN NUMBER IS
        v_sumins GC_POLICY.SUMINS%TYPE;
        v_prlcd  GC_CLAIM.PRLCD%TYPE;
        v_factor NUMBER;
    BEGIN
        SELECT p.SUMINS, c.PRLCD
          INTO v_sumins, v_prlcd
          FROM GC_CLAIM c JOIN GC_POLICY p ON p.POLNO = c.POLNO
         WHERE c.CLMNO = p_clmno;
        v_factor := CASE v_prlcd
                        WHEN 'FIRE' THEN 0.10
                        WHEN 'STRM' THEN 0.08
                        WHEN 'WATR' THEN 0.05
                        WHEN 'THFT' THEN 0.03
                        ELSE 0.02
                    END;
        RETURN ROUND(v_sumins * v_factor, 2);
    END FUNC_CALCULATE_RESERVE;

END PKG_CLAIMS;
/

-- State machine enforced IN the DB — an illegal STATCD transition is rejected here, not just in the app.
CREATE OR REPLACE TRIGGER TRG_CLAIM_STATE
BEFORE UPDATE OF STATCD ON GC_CLAIM
FOR EACH ROW
DECLARE
    v_ok BOOLEAN := FALSE;
BEGIN
    IF :OLD.STATCD = :NEW.STATCD THEN
        RETURN;
    END IF;
    v_ok := CASE
                WHEN :OLD.STATCD = 'N' AND :NEW.STATCD IN ('U','R','X') THEN TRUE
                WHEN :OLD.STATCD = 'U' AND :NEW.STATCD IN ('R','X')     THEN TRUE
                WHEN :OLD.STATCD = 'R' AND :NEW.STATCD IN ('S','X')     THEN TRUE
                WHEN :OLD.STATCD = 'S' AND :NEW.STATCD = 'C'            THEN TRUE
                ELSE FALSE
            END;
    IF NOT v_ok THEN
        RAISE_APPLICATION_ERROR(-20001,
            'Illegal claim status transition ' || :OLD.STATCD || ' -> ' || :NEW.STATCD);
    END IF;
END;
/

-- Append-only audit trail — every create + status change is recorded automatically.
CREATE OR REPLACE TRIGGER TRG_CLAIM_AUDIT
AFTER INSERT OR UPDATE OF STATCD ON GC_CLAIM
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        INSERT INTO GC_CLMAUD (CLMNO, AUDACT, OLDSTAT, NEWSTAT)
        VALUES (:NEW.CLMNO, 'CREATE', NULL, :NEW.STATCD);
    ELSIF UPDATING AND :OLD.STATCD <> :NEW.STATCD THEN
        INSERT INTO GC_CLMAUD (CLMNO, AUDACT, OLDSTAT, NEWSTAT)
        VALUES (:NEW.CLMNO, 'STATUS-CHG', :OLD.STATCD, :NEW.STATCD);
    END IF;
END;
/

-- The audit is immutable: block any UPDATE/DELETE on GC_CLMAUD.
CREATE OR REPLACE TRIGGER TRG_CLMAUD_FREEZE
BEFORE UPDATE OR DELETE ON GC_CLMAUD
BEGIN
    RAISE_APPLICATION_ERROR(-20009, 'GC_CLMAUD is append-only');
END;
/
