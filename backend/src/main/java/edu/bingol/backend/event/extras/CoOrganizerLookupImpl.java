package edu.bingol.backend.event.extras;

import java.util.Collection;
import java.util.HashSet;
import java.util.Set;
import org.springframework.stereotype.Component;

@Component
public class CoOrganizerLookupImpl implements CoOrganizerLookup {

    private final CoOrganizerRepository repo;

    public CoOrganizerLookupImpl(CoOrganizerRepository repo) {
        this.repo = repo;
    }

    @Override
    public boolean isCoOrganizer(Long eventId, Long userId) {
        return eventId != null && userId != null && repo.existsByEventIdAndUserId(eventId, userId);
    }

    @Override
    public Set<Long> coOrganizedAmong(Collection<Long> eventIds, Long userId) {
        if (eventIds.isEmpty() || userId == null) {
            return Set.of();
        }
        return new HashSet<>(repo.coOrganizedAmong(eventIds, userId));
    }
}
