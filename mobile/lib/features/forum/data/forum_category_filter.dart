/// Forum kategori listesi için saf yardımcılar (UI'siz test edilir): arama katlaması, süzme, gruplama, çip seçimi.
library;

import 'forum_models.dart';

/// Yatay çip satırında gösterilen en çok kategori sayısı (kalanı "Tüm kategoriler" seçicisindedir).
const int kForumChipLimit = 8;

const Map<String, String> _trFold = {
  'ç': 'c', 'Ç': 'c', 'ğ': 'g', 'Ğ': 'g', 'ı': 'i', 'İ': 'i', 'I': 'i', 'ö': 'o', 'Ö': 'o', 'ş': 's', 'Ş': 's', 'ü': 'u',
  'Ü': 'u', 'â': 'a', 'Â': 'a', 'î': 'i', 'Î': 'i', 'û': 'u', 'Û': 'u',
  // Arapça: elif biçimleri tek elif, ye/te marbuta yazım farkları, tatwil
  'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ـ': '',
};

final RegExp _arabicMarks = RegExp('[ً-ٰٟ]');
final RegExp _splitter = RegExp(r'[\s&/,.\-_]+');

/// Aramada büyük/küçük harf, Türkçe karakter (İ/I/ı/i, ç ğ ö ş ü) ve Arapça hareke farkını yok sayan katlama.
String foldForumSearch(String s) {
  final b = StringBuffer();
  for (final ch in s.replaceAll(_arabicMarks, '').split('')) {
    b.write(_trFold[ch] ?? ch.toLowerCase());
  }
  return b.toString();
}

/// Sorguyu katlanmış sözcüklere böler (en çok 6). Boş/boşluk = boş liste.
List<String> forumCategoryTokens(String q) =>
    [for (final p in foldForumSearch(q.trim()).split(_splitter)) if (p.isNotEmpty) p].take(6).toList();

/// Kategorileri [q] ile süzer: her sözcük ad, slug ya da grup adında geçmeli (VE). Sıra korunur.
List<ForumCategory> filterForumCategories(List<ForumCategory> all, String q) {
  final tokens = forumCategoryTokens(q);
  if (tokens.isEmpty) return all;
  return [
    for (final c in all)
      if (_matches(tokens, c)) c,
  ];
}

bool _matches(List<String> tokens, ForumCategory c) {
  final hay = foldForumSearch('${c.name} ${c.slug.replaceAll('-', ' ')} ${c.groupName ?? ''}');
  for (final t in tokens) {
    if (!hay.contains(t)) return false;
  }
  return true;
}

/// Seçicideki bir bölüm: grup başlığı (grupsuz = [name] null) + kategoriler.
class ForumCategorySection {
  const ForumCategorySection({required this.key, required this.name, required this.items});

  final String? key;
  final String? name;
  final List<ForumCategory> items;
}

/// Kategorileri gruplara böler: bölümler `groupOrder` (sonra grup adı) sırasında, bölüm içi `sortOrder` sırasında;
/// grupsuz kategoriler en sonda tek bölümde. Hiç grup yoksa tek başlıksız bölüm döner.
List<ForumCategorySection> groupForumCategories(List<ForumCategory> all) {
  final grouped = <String, List<ForumCategory>>{};
  final order = <String, int>{};
  final names = <String, String>{};
  final loose = <ForumCategory>[];
  for (final c in all) {
    final k = c.groupKey;
    if (k == null || k.isEmpty) {
      loose.add(c);
      continue;
    }
    grouped.putIfAbsent(k, () => []).add(c);
    order[k] = c.groupOrder;
    names[k] = c.groupName ?? k;
  }
  final keys = grouped.keys.toList()
    ..sort((a, b) {
      final d = order[a]!.compareTo(order[b]!);
      return d != 0 ? d : names[a]!.compareTo(names[b]!);
    });
  int bySort(ForumCategory a, ForumCategory b) {
    final d = a.sortOrder.compareTo(b.sortOrder);
    return d != 0 ? d : a.id.compareTo(b.id);
  }

  return [
    for (final k in keys)
      ForumCategorySection(key: k, name: names[k], items: (grouped[k]!.toList()..sort(bySort))),
    if (loose.isNotEmpty) ForumCategorySection(key: null, name: null, items: (loose.toList()..sort(bySort))),
  ];
}

/// Yatay çip satırında gösterilecek kategoriler: `sortOrder` sırasıyla ilk [limit]; seçili kategori bunların dışındaysa
/// (seçiciden seçildi) başa eklenir ki seçim görünür kalsın.
List<ForumCategory> forumChipCategories(List<ForumCategory> all, int? selectedId, {int limit = kForumChipLimit}) {
  final sorted = [...all]..sort((a, b) {
      final d = a.sortOrder.compareTo(b.sortOrder);
      return d != 0 ? d : a.id.compareTo(b.id);
    });
  final head = sorted.take(limit).toList();
  if (selectedId != null && !head.any((c) => c.id == selectedId)) {
    final sel = sorted.where((c) => c.id == selectedId);
    if (sel.isNotEmpty) head.insert(0, sel.first);
  }
  return head;
}
