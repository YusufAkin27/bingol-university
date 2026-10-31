package edu.bingol.bu_kampus

import androidx.core.content.FileProvider

/**
 * KVKK veri dosyasi paylasimi icin ozel FileProvider alt sinifi: eklentilerin kendi FileProvider bildirimleriyle
 * manifest birlestirme cakismasi olmaz (ayni sinif adi iki kez bildirilemez).
 */
class ExportFileProvider : FileProvider()
