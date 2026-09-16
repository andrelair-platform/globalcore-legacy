package com.globalcorp.gcore.dao;

import com.globalcorp.gcore.util.Dates;
import com.globalcorp.gcore.ws.CreatePolicyRequest;
import com.globalcorp.gcore.ws.CreatePolicyResponse;
import com.globalcorp.gcore.ws.Endorsement;
import com.globalcorp.gcore.ws.GetPolicyResponse;
import com.globalcorp.gcore.ws.Policy;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.Date;
import java.util.List;
import java.util.Map;

/** Raw JDBC against the shared legacy schema; business rules (rating) live in DB procs. */
@Repository
public class PolicyDao {

    private final JdbcTemplate jdbc;

    public PolicyDao(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private static String trim(String s) { return s == null ? null : s.trim(); }

    /** Read the latest version of a policy + its endorsements. rc: 00=found, 08=not found. */
    public GetPolicyResponse getPolicy(String polNo) {
        GetPolicyResponse resp = new GetPolicyResponse();
        String sql =
            "SELECT p.polno, c.custnm, p.brkcd, p.lobcd, p.statcd, p.currcd, " +
            "       v.verno, v.effdt, v.expdt, v.sumins, v.premamt " +
            "FROM gc_policy p " +
            "JOIN gc_cust c ON c.custno = p.custno " +
            "JOIN gc_polver v ON v.polno = p.polno " +
            "WHERE p.polno = ? " +
            "  AND v.verno = (SELECT MAX(verno) FROM gc_polver x WHERE x.polno = p.polno)";

        List<Map<String, Object>> rows = jdbc.queryForList(sql, polNo);
        if (rows.isEmpty()) {
            resp.setRc("08");
            return resp;
        }
        Map<String, Object> r = rows.get(0);
        Policy pol = new Policy();
        pol.setPolNo(trim((String) r.get("polno")));
        pol.setCustName(trim((String) r.get("custnm")));
        pol.setBrkCd(trim((String) r.get("brkcd")));
        pol.setLobCd(trim((String) r.get("lobcd")));
        pol.setStatCd(trim((String) r.get("statcd")));
        pol.setCurrCd(trim((String) r.get("currcd")));
        int verNo = ((Number) r.get("verno")).intValue();
        pol.setVerNo(verNo);
        pol.setEffDt(Dates.toXml((Date) r.get("effdt")));
        pol.setExpDt(Dates.toXml((Date) r.get("expdt")));
        pol.setSumIns((java.math.BigDecimal) r.get("sumins"));
        pol.setPremAmt((java.math.BigDecimal) r.get("premamt"));

        String endSql = "SELECT endno, enddt, endtyp, premadj, enddesc FROM gc_endmt " +
                        "WHERE polno = ? AND verno = ? ORDER BY endno";
        for (Map<String, Object> e : jdbc.queryForList(endSql, polNo, verNo)) {
            Endorsement end = new Endorsement();
            end.setEndNo(((Number) e.get("endno")).intValue());
            end.setEndDt(Dates.toXml((Date) e.get("enddt")));
            end.setEndTyp(trim((String) e.get("endtyp")));
            end.setPremAdj((java.math.BigDecimal) e.get("premadj"));
            end.setEndDesc((String) e.get("enddesc"));
            pol.getEndorsement().add(end);
        }
        resp.setRc("00");
        resp.setPolicy(pol);
        return resp;
    }

    /** Create a policy. It is inserted PENDING ('P') — it becomes official only when the
     *  nightly batch runs. Premium is computed synchronously by the DB rating proc. */
    public CreatePolicyResponse createPolicy(CreatePolicyRequest req) {
        CreatePolicyResponse resp = new CreatePolicyResponse();
        String polNo = jdbc.queryForObject(
            "SELECT 'POL' || LPAD((COALESCE(MAX(CAST(TRIM(SUBSTRING(polno FROM 4)) AS INTEGER)),0)+1)::text, 7, '0') " +
            "FROM gc_policy", String.class);

        jdbc.update("INSERT INTO gc_policy (polno, custno, brkcd, lobcd, statcd, currcd) " +
                    "VALUES (?,?,?,?,'P',?)",
                polNo, req.getCustNo(), req.getBrkCd(), req.getLobCd(), req.getCurrCd());

        jdbc.update("INSERT INTO gc_polver (polno, verno, effdt, expdt, sumins, premamt, versts) " +
                    "VALUES (?, 1, ?, ?, ?, 0, 'A')",
                polNo, Dates.toSql(req.getEffDt()), Dates.toSql(req.getExpDt()), req.getSumIns());

        // rating engine lives in the DB (legacy trait)
        jdbc.queryForObject("SELECT gcore_calc_premium(?, CAST(1 AS SMALLINT))",
                java.math.BigDecimal.class, polNo);

        resp.setRc("00");
        resp.setPolNo(polNo);
        resp.setStatCd("P");
        resp.setMsg("Policy created PENDING; becomes active on the next nightly batch.");
        return resp;
    }
}
