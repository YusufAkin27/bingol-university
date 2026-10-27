package edu.bingol.backend.academic;

/** Duyuru/sinav kapsam eslemesi: kapsam alani bos = herkes; doluysa kullanicinin degeriyle (buyuk-kucuk duyarsiz) ayni olmali. */
public final class AudienceMatch {

    private AudienceMatch() {}

    public static boolean field(String scope, String userValue) {
        if (scope == null || scope.isBlank()) {
            return true;
        }
        return userValue != null && scope.strip().equalsIgnoreCase(userValue.strip());
    }

    public static boolean matches(String scopeDepartment, String scopeFaculty, String scopeGrade,
                                  String userDepartment, String userFaculty, String userGrade) {
        return field(scopeDepartment, userDepartment) && field(scopeFaculty, userFaculty) && field(scopeGrade, userGrade);
    }
}
