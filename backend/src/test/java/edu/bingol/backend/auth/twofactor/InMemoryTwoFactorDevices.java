package edu.bingol.backend.auth.twofactor;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

/** Bellek ici cihaz deposu (birim/akis testleri icin; arayuz bilerek dar tutuldu). */
public class InMemoryTwoFactorDevices implements TwoFactorDeviceRepository {

    public final List<TwoFactorDevice> rows = new ArrayList<>();
    private final AtomicLong ids = new AtomicLong(100);

    @Override
    public TwoFactorDevice save(TwoFactorDevice d) {
        if (d.getId() == null) {
            d.setId(ids.incrementAndGet());
            rows.add(d);
        }
        return d;
    }

    @Override
    public Optional<TwoFactorDevice> findByUserIdAndDeviceHash(Long userId, String deviceHash) {
        return rows.stream().filter(d -> d.getUserId().equals(userId) && d.getDeviceHash().equals(deviceHash)).findFirst();
    }

    @Override
    public Optional<TwoFactorDevice> findByIdAndUserId(Long id, Long userId) {
        return rows.stream().filter(d -> d.getId().equals(id) && d.getUserId().equals(userId)).findFirst();
    }

    @Override
    public List<TwoFactorDevice> findByUserIdOrderByLastUsedAtDesc(Long userId) {
        return rows.stream().filter(d -> d.getUserId().equals(userId))
                .sorted(Comparator.comparing(TwoFactorDevice::getLastUsedAt).reversed()).toList();
    }

    @Override
    public long countByUserId(Long userId) {
        return rows.stream().filter(d -> d.getUserId().equals(userId)).count();
    }

    @Override
    public void delete(TwoFactorDevice device) {
        rows.remove(device);
    }

    @Override
    public int deleteAllForUserInNewTx(Long userId) {
        return deleteAllForUser(userId);
    }

    @Override
    public int deleteAllForUser(Long userId) {
        int n = (int) countByUserId(userId);
        rows.removeIf(d -> d.getUserId().equals(userId));
        return n;
    }
}
