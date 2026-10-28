package edu.bingol.backend.mail.campaign;

/**
 * Kampanya alici satiri (mail_campaign_recipient). Satirlar toplu islem icin JDBC ile yazilir; varlik sinifi yoktur.
 * (campaign_id, user_id) benzersizdir: ayni kullaniciya ayni kampanyadan iki e-posta gitmez.
 */
public final class MailCampaignRecipient {

    private MailCampaignRecipient() {}

    public enum Status { PENDING, QUEUED, SKIPPED, FAILED, CANCELLED }

    /** skip_reason degerleri (bastirma kapisindan gelenler ayrica SUPPRESSED/OPTED_OUT vb. olabilir). */
    public static final String INACTIVE = "INACTIVE";
    public static final String DUPLICATE_ADDRESS = "DUPLICATE_ADDRESS";
    public static final String INVALID_ADDRESS = "INVALID_ADDRESS";
    public static final String SUPPRESSED = "SUPPRESSED";
}
