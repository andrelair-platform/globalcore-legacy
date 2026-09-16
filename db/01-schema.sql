-- GlobalCore legacy schema — PostgreSQL "pretending to be DB2/Oracle".
-- Deliberately legacy: one shared schema, cryptic <=8-char names, codes (not enums),
-- no FKs enforced with nice names, business meaning hidden in short columns.
-- (This is the System of Record. Once seeded, it is FROZEN — we wrap it, never edit it.)

CREATE SCHEMA IF NOT EXISTS gcore;
SET search_path TO gcore;

-- Brokers
CREATE TABLE GC_BROKER (
    BRKCD    CHAR(8)      NOT NULL PRIMARY KEY,   -- broker code
    BRKNM    VARCHAR(40)  NOT NULL,               -- broker name
    COMMPCT  NUMERIC(5,2) NOT NULL DEFAULT 10.00  -- commission %
);

-- Customers (insured legal entities)
CREATE TABLE GC_CUST (
    CUSTNO   CHAR(8)      NOT NULL PRIMARY KEY,    -- customer number
    CUSTNM   VARCHAR(40)  NOT NULL,               -- insured name
    CTRYCD   CHAR(2)      NOT NULL,               -- country code (FR/DE/GB..)
    CURRCD   CHAR(3)      NOT NULL DEFAULT 'EUR'  -- base currency
);

-- Policy header (STATCD: P=pending A=active L=lapsed C=cancelled ; LOBCD: MAR/PRO/AVI)
CREATE TABLE GC_POLICY (
    POLNO    CHAR(10)     NOT NULL PRIMARY KEY,    -- policy number
    CUSTNO   CHAR(8)      NOT NULL,               -- -> GC_CUST
    BRKCD    CHAR(8)      NOT NULL,               -- -> GC_BROKER
    LOBCD    CHAR(3)      NOT NULL,               -- line of business code
    STATCD   CHAR(1)      NOT NULL DEFAULT 'P',   -- status code
    CURRCD   CHAR(3)      NOT NULL DEFAULT 'EUR',
    CRETS    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Effective-dated policy VERSIONS (a policy has 1..N versions over time)
CREATE TABLE GC_POLVER (
    POLNO    CHAR(10)     NOT NULL,               -- -> GC_POLICY
    VERNO    SMALLINT     NOT NULL,               -- version number (1,2,3..)
    EFFDT    DATE         NOT NULL,               -- effective date
    EXPDT    DATE         NOT NULL,               -- expiry date
    SUMINS   NUMERIC(15,2) NOT NULL,              -- sum insured
    PREMAMT  NUMERIC(15,2) NOT NULL DEFAULT 0,    -- premium (computed by the rating proc)
    VERSTS   CHAR(1)      NOT NULL DEFAULT 'A',   -- version status
    PRIMARY KEY (POLNO, VERNO)
);

-- Mid-term endorsements (changes to a version, with premium adjustment)
CREATE TABLE GC_ENDMT (
    POLNO    CHAR(10)     NOT NULL,
    VERNO    SMALLINT     NOT NULL,
    ENDNO    SMALLINT     NOT NULL,               -- endorsement number
    ENDDT    DATE         NOT NULL,
    ENDTYP   CHAR(3)      NOT NULL,               -- endorsement type code (ADR/LIM/CAN..)
    PREMADJ  NUMERIC(15,2) NOT NULL DEFAULT 0,    -- premium adjustment (+/-)
    ENDDESC  VARCHAR(60),
    PRIMARY KEY (POLNO, VERNO, ENDNO)
);

-- Renewal batch output log (the nightly batch writes here)
CREATE TABLE GC_RENEW (
    RENID    SERIAL       PRIMARY KEY,
    POLNO    CHAR(10)     NOT NULL,
    GENTS    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    NEWVER   SMALLINT,
    NEWEFFDT DATE,
    RENSTS   VARCHAR(20)  NOT NULL                -- GENERATED / SKIPPED-...
);
