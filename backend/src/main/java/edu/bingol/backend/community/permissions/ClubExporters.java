package edu.bingol.backend.community.permissions;

import edu.bingol.backend.export.DataExporter;
import java.util.List;
import java.util.Map;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.PageRequest;

/** KVKK: kullanicinin kulup yetkileri, devir teklifleri, olusturdugu davetler ve denetim kayitlarindaki yeri. */
@Configuration
public class ClubExporters {

    @Bean
    DataExporter clubPermissionsExporter(ClubMemberGrantRepository grants, ClubOwnershipTransferRepository transfers,
                                         ClubInviteRepository invites, ClubAuditRepository audits) {
        return DataExporter.of("clubPermissions", uid -> Map.of(
                "grants", grants.findByUserId(uid).stream().map(g -> Map.of(
                        "communityId", g.getCommunityId(), "permissions", g.permissionSet().toString(),
                        "updatedAt", g.getUpdatedAt().toString())).toList(),
                "ownershipTransfers", transfers.findByFromUserIdOrToUserId(uid, uid).stream().map(t -> Map.of(
                        "communityId", t.getCommunityId(), "status", t.getStatus().name(),
                        "asSender", t.getFromUserId().equals(uid), "createdAt", t.getCreatedAt().toString())).toList(),
                "invitesCreated", invites.findByCreatedBy(uid).stream().map(i -> Map.of(
                        "communityId", i.getCommunityId(), "usedCount", i.getUsedCount(),
                        "expiresAt", i.getExpiresAt().toString(), "revoked", i.isRevoked())).toList(),
                "auditEntries", audits.involving(uid, PageRequest.of(0, 500)).stream().map(a -> Map.of(
                        "communityId", a.getCommunityId(), "action", a.getAction(),
                        "asActor", uid.equals(a.getActorId()), "at", a.getCreatedAt().toString())).toList()));
    }
}
