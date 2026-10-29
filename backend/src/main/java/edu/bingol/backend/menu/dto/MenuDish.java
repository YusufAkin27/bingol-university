package edu.bingol.backend.menu.dto;

/** Menudeki bir yemek: ad + yonetici kalorisi (kcal; girilmediyse null). */
public record MenuDish(String name, Integer kcal) {
}
