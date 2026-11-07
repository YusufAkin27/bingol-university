package edu.bingol.backend.dbmaint;

import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.function.Function;
import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * Gece bakimindaki TEK, genis tarama gerektiren sorgular (gunluk toplulastirma, bildirim ust sinir adayi) icin
 * {@code SET LOCAL statement_timeout}'li kisa islem (FIX-P09 / A08#5): normal havuz baglantilarinda 8 sn
 * {@code statement_timeout} vardir; bu sorgular gercek hacimde onu asip hatayi {@code safe()} icinde yutuyordu.
 * {@code SET LOCAL} commit/rollback'te kendiliginden geri alinir (havuza sizmaz). PostgreSQL disinda (H2 testleri),
 * zaman asimi 0 ise ya da cagiran bir islem acikken sorgu oldugu gibi calisir.
 */
final class LongSql {

    /** Bakim sorgulari icin varsayilan sinir (ms): ChunkedDeleter'in parca siniri ile ayni buyukluk sirasi. */
    static final long DEFAULT_TIMEOUT_MS = 120_000;

    private LongSql() {
    }

    static <T> T run(NamedParameterJdbcTemplate jdbc, long timeoutMs, Function<NamedParameterJdbcTemplate, T> work) {
        if (timeoutMs <= 0 || TransactionSynchronizationManager.isActualTransactionActive()) {
            return work.apply(jdbc);
        }
        return jdbc.getJdbcTemplate().execute((ConnectionCallback<T>) con -> onConnection(con, timeoutMs, work));
    }

    private static <T> T onConnection(Connection con, long timeoutMs, Function<NamedParameterJdbcTemplate, T> work)
            throws SQLException {
        NamedParameterJdbcTemplate same = new NamedParameterJdbcTemplate(new SingleConnectionDataSource(con, true));
        if (!"PostgreSQL".equalsIgnoreCase(con.getMetaData().getDatabaseProductName())) {
            return work.apply(same);
        }
        boolean auto = con.getAutoCommit();
        con.setAutoCommit(false);
        try {
            try (Statement st = con.createStatement()) {
                st.execute("SET LOCAL statement_timeout = " + timeoutMs); // sayi, kullanici girdisi degil
            }
            T result = work.apply(same);
            con.commit();
            return result;
        } catch (RuntimeException e) {
            rollbackQuietly(con);
            throw e;
        } catch (SQLException e) {
            rollbackQuietly(con);
            throw e;
        } finally {
            try {
                con.setAutoCommit(auto);
            } catch (SQLException ignored) {
                // baglanti bozuksa havuz zaten atar
            }
        }
    }

    private static void rollbackQuietly(Connection con) {
        try {
            con.rollback();
        } catch (SQLException ignored) {
            // asil hata yayilir
        }
    }
}
