package edu.bingol.backend.profile;

/** Kullanicinin bolum veya sinifi degisti (ProfileService.update); academic modulu resmi ders programini yeniler. */
public record AcademicProfileChanged(Long userId) {}
