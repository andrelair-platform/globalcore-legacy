-- GlobalCore (Oracle) — CLAIMS domain schema (S001).
-- Deliberately legacy: cryptic <=8-char names, codes (not enums), business meaning hidden in short
-- columns. Owned by the least-privilege app user GCORE (never SYS/SYSTEM). FROZEN once seeded — the
-- modern ktayl-claims ACL wraps this over SOAP, never edits it.

-- Customers (insured legal entities)
CREATE TABLE GC_CUST (
    CUSTNO  CHAR(8)      NOT NULL PRIMARY KEY,   -- customer number
    CUSTNM  VARCHAR2(40) NOT NULL,               -- insured name
    CTRYCD  CHAR(2)      NOT NULL,               -- country (FR/DE/GB..)
    CURRCD  CHAR(3)      DEFAULT 'EUR' NOT NULL   -- base currency
);

-- Policy (flattened for the Claims slice: one Property version; STATCD A=active L=lapsed C=cancelled)
CREATE TABLE GC_POLICY (
    POLNO   CHAR(10)     NOT NULL PRIMARY KEY,   -- policy number
    CUSTNO  CHAR(8)      NOT NULL,               -- -> GC_CUST
    LOBCD   CHAR(3)      NOT NULL,               -- line of business (PRO=property)
    STATCD  CHAR(1)      DEFAULT 'A' NOT NULL,
    EFFDT   DATE         NOT NULL,               -- cover start
    EXPDT   DATE         NOT NULL,               -- cover end
    SUMINS  NUMBER(15,2) NOT NULL,               -- sum insured
    CONSTRAINT FK_POL_CUST FOREIGN KEY (CUSTNO) REFERENCES GC_CUST(CUSTNO)
);

-- Perils covered per policy (cryptic codes: FIRE/WATR/STRM/THFT). The ACL translates these to clean names.
CREATE TABLE GC_POLPRL (
    POLNO   CHAR(10)  NOT NULL,
    PRLCD   CHAR(4)   NOT NULL,
    CONSTRAINT PK_POLPRL PRIMARY KEY (POLNO, PRLCD),
    CONSTRAINT FK_POLPRL_POL FOREIGN KEY (POLNO) REFERENCES GC_POLICY(POLNO)
);

-- Claim header. STATCD state machine (enforced in-DB, S002):
--   N notified -> U review / R reserved / X rejected ; U -> R / X ; R -> S settled / X ; S -> C closed
CREATE TABLE GC_CLAIM (
    CLMNO   CHAR(15)     NOT NULL PRIMARY KEY,   -- CLM-YYYY-NNNNNN (allocated by the legacy)
    POLNO   CHAR(10)     NOT NULL,               -- -> GC_POLICY
    LOSSDT  DATE         NOT NULL,               -- date of loss
    PRLCD   CHAR(4)      NOT NULL,               -- peril code
    CLMTNM  VARCHAR2(40) NOT NULL,               -- claimant name
    STATCD  CHAR(1)      DEFAULT 'N' NOT NULL,
    CRETS   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT FK_CLM_POL FOREIGN KEY (POLNO) REFERENCES GC_POLICY(POLNO),
    CONSTRAINT CK_CLM_STAT CHECK (STATCD IN ('N','U','R','S','C','X'))
);

-- Reserve history (set / adjust)
CREATE TABLE GC_CLMRSV (
    CLMNO   CHAR(15)     NOT NULL,
    RSVSEQ  NUMBER(6)    NOT NULL,
    RSVAMT  NUMBER(15,2) NOT NULL,
    RSVTS   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_CLMRSV PRIMARY KEY (CLMNO, RSVSEQ),
    CONSTRAINT FK_RSV_CLM FOREIGN KEY (CLMNO) REFERENCES GC_CLAIM(CLMNO)
);

-- Payments
CREATE TABLE GC_PAYMT (
    CLMNO   CHAR(15)     NOT NULL,
    PAYSEQ  NUMBER(6)    NOT NULL,
    PAYAMT  NUMBER(15,2) NOT NULL,
    PAYTS   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT PK_PAYMT PRIMARY KEY (CLMNO, PAYSEQ),
    CONSTRAINT FK_PAY_CLM FOREIGN KEY (CLMNO) REFERENCES GC_CLAIM(CLMNO)
);

-- Append-only claim audit (every create + status change lands here, S002)
CREATE TABLE GC_CLMAUD (
    AUDID   NUMBER       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    CLMNO   CHAR(15)     NOT NULL,
    AUDACT  VARCHAR2(12) NOT NULL,               -- CREATE / STATUS-CHG
    OLDSTAT CHAR(1),
    NEWSTAT CHAR(1)      NOT NULL,
    AUDTS   TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL
);

-- The legacy allocates the claim number from this sequence.
CREATE SEQUENCE GC_CLMSEQ START WITH 1 INCREMENT BY 1 NOCACHE;
