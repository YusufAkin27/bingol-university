package edu.bingol.backend.event.extras;

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
}
