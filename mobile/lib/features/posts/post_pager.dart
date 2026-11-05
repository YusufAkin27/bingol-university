import 'package:flutter/material.dart';

import '../../widgets/bu.dart';
import 'post_models.dart';

/// İki yönlü dikey gönderi akışı (Instagram Keşfet gibi): açılan gönderi AKIŞIN ORTASINDA (kaydırma 0 konumunda ekranın
/// başında) durur; ÜSTÜNDE ızgarada ondan önce gelenler ([before], yukarı kaydırınca), ALTINDA ondan sonrakiler
/// ([after], ilk eleman açılan gönderi) ve sayfa sonu bileşeni ([footer]) gelir.
///
/// `CustomScrollView.center` tekniği: [after] listesi merkez sliver'dır; [before] merkezin üstüne ters yönde büyür
/// (indeks 0 = merkeze en yakın = ızgarada hemen önceki gönderi). Altta yeni sayfa eklenince veya üstte liste değişince
/// görünen gönderiler yerinden oynamaz.
class PostPager extends StatelessWidget {
  const PostPager({
    super.key,
    required this.controller,
    required this.before,
    required this.after,
    required this.itemBuilder,
    this.footer,
    this.bottomPadding = 0,
  });

  final ScrollController controller;

  /// Izgara sırasıyla (yukarıdan aşağıya) açılan gönderiden ÖNCEKİLER.
  final List<Post> before;

  /// Merkez ve altı: [0] açılan gönderi.
  final List<Post> after;
  final Widget Function(BuildContext context, Post post) itemBuilder;
  final Widget? footer;
  final double bottomPadding;

  static const centerKey = ValueKey<String>('postStreamCenter');

  Widget _entry(BuildContext context, Post p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [itemBuilder(context, p), const PostStreamDivider()],
      );

  SliverChildDelegate _delegate(List<Post> posts) {
    final index = {for (var i = 0; i < posts.length; i++) 'stream-entry-${posts[i].id}': i};
    return SliverChildBuilderDelegate(
      (context, i) {
        final p = posts[i];
        return KeyedSubtree(key: ValueKey('stream-entry-${p.id}'), child: _entry(context, p));
      },
      childCount: posts.length,
      findChildIndexCallback: (k) => k is ValueKey<String> ? index[k.value] : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Merkezin üstündeki sliver ters büyür: ilk çocuk merkeze en yakın olmalı -> ters sıra.
    final above = before.reversed.toList(growable: false);
    return CustomScrollView(
      key: const ValueKey('postStream'),
      controller: controller,
      center: centerKey,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverList(key: const ValueKey('postStreamAbove'), delegate: _delegate(above)),
        SliverList(key: centerKey, delegate: _delegate(after)),
        if (footer != null) SliverToBoxAdapter(child: footer),
        SliverToBoxAdapter(child: SizedBox(height: bottomPadding)),
      ],
    );
  }
}

/// Gönderiler arası ayırıcı: 1 dp `bd` çizgi (20 dp kenar) + altında 24 dp boşluk. Gönderinin kendi alt boşluğu çizginin
/// üstündeki payı verir.
class PostStreamDivider extends StatelessWidget {
  const PostStreamDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(BuSpace.page, 0, BuSpace.page, BuSpace.xxl),
        child: Divider(key: const ValueKey('postStreamDivider'), height: 1, thickness: 1, color: context.bu.bd),
      );
}
