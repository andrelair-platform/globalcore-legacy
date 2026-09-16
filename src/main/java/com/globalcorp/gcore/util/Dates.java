package com.globalcorp.gcore.util;

import javax.xml.datatype.DatatypeFactory;
import javax.xml.datatype.XMLGregorianCalendar;
import java.sql.Date;

/** Convert between java.sql.Date and the XMLGregorianCalendar JAXB insists on for xs:date. */
public final class Dates {
    private Dates() {}

    public static XMLGregorianCalendar toXml(Date d) {
        if (d == null) return null;
        try {
            java.time.LocalDate ld = d.toLocalDate();
            XMLGregorianCalendar x = DatatypeFactory.newInstance().newXMLGregorianCalendar();
            x.setYear(ld.getYear());
            x.setMonth(ld.getMonthValue());
            x.setDay(ld.getDayOfMonth());
            return x;
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public static Date toSql(XMLGregorianCalendar x) {
        if (x == null) return null;
        return Date.valueOf(java.time.LocalDate.of(x.getYear(), x.getMonth(), x.getDay()));
    }
}
