package edu.bingol.backend.user;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import edu.bingol.backend.common.Hashing;
import org.junit.jupiter.api.Test;

class UserEmailHashTest {

    @Test
    void hashIsOfLowercasedTrimmedEmail() {
        User u = new User();
        u.setEmail(" Ali@Bingol.edu.tr ");
        u.syncEmailHash();
        assertEquals(Hashing.sha256("ali@bingol.edu.tr"), u.getEmailSha256());
    }

    @Test
    void deletedAccountHasNoHash() {
        User u = new User();
        u.setEmail("ali@bingol.edu.tr");
        u.syncEmailHash();
        u.setStatus(UserStatus.DELETED);
        u.syncEmailHash();
        assertNull(u.getEmailSha256());
    }
}
