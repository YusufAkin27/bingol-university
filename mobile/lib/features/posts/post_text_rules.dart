/// Gönderi metni kuralları: isteğe bağlı, tek cümle, en çok 7 kelime (~60 karakter), satır sonu yok.
const kPostMaxWords = 7;
const kPostMaxChars = 60;

/// Boşlukla ayrılmış kelime sayısı (boş metin 0).
int postWordCount(String text) {
  final t = text.trim();
  if (t.isEmpty) return 0;
  return t.split(RegExp(r'\s+')).length;
}

/// Metin sınır içinde mi (boş metin geçerlidir).
bool postTextOk(String text) => postWordCount(text) <= kPostMaxWords && text.trim().length <= kPostMaxChars;
