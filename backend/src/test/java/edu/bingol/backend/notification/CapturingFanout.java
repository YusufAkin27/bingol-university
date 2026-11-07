package edu.bingol.backend.notification;

import java.util.ArrayList;
import java.util.List;

/**
 * Test yardimcisi: {@link FanoutNotifier} isleri havuza degil listeye yazar. Boylece "istek sirasinda bildirim
 * cagrisi yok, is commit sonrasi calisir" davranisi dogrulanir: {@link #runAll()} cagrilana dek hicbir is calismaz.
 */
public class CapturingFanout extends FanoutNotifier {

    public final List<Runnable> tasks = new ArrayList<>();
    public final List<String> names = new ArrayList<>();

    @Override
    public void afterCommit(String what, Runnable job) {
        names.add(what);
        tasks.add(job);
    }

    /** Biriken isleri (commit sonrasi havuzun yapacagi gibi) sirayla calistirir. */
    public void runAll() {
        List<Runnable> copy = new ArrayList<>(tasks);
        tasks.clear();
        copy.forEach(Runnable::run);
    }
}
