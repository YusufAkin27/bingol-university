package edu.bingol.backend.forum.topic.dto;

/** Konu kartindaki kategori etiketi ({@code name} istek diline gore). */
public record CategoryRef(Long id, String name, String slug) {}
