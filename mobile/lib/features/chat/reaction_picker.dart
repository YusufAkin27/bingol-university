import 'package:flutter/material.dart';

import '../../core/locale_controller.dart';
import '../../widgets/bu.dart';
import 'recent_reactions.dart';

const _catalog =
    '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😋 😛 😜 🤪 🤨 🧐 🤓 😎 🥳 🤩 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🤢 🤮 🤧 😷 🤒 🤕 🤑 🤠 😈 👿 👻 💀 ☠️ 👽 🤖 🎃 😺 😸 😹 😻 🙈 🙉 🙊 ❤️ 🧡 💛 💚 💙 💜 🤎 🖤 🤍 🩷 🩵 🩶 💔 ❤️‍🔥 💕 💞 💓 💗 💖 💘 💝 💯 💢 💥 🔥 ⭐ 🌟 ✨ 💫 🎉 🎊 🎈 🎁 🏆 🥇 👋 🤚 🖐️ ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🫰 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ 👍 👎 ✊ 👊 🤛 🤜 👏 🙌 🫶 👐 🤲 🤝 🙏 💪 🫡 🤷‍♀️ 🤷‍♂️ 👀 🧠 🫀 🌹 🌻 🌸 🌷 🍀 🌿 🌍 🌞 🌙 🌈 ☀️ ☁️ ⚡ ❄️ 🐱 🐶 🦋 🐝 🦊 🐼 🐻 🐸 🦁 🦄 🍕 🍔 🍟 🍰 🎂 🍫 🍓 🍉 🍎 ☕ 🧋 🥤 ⚽ 🏀 🏐 🎮 🎧 🎵 📚 🎓 💻 📷 💡 ⏰ 📌 ✅ ❌ ❓ ❗ 🚀 ✈️ 🏠 🏫 🏖️ 🇹🇷 🏳️‍🌈';

Future<String?> showReactionPicker(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.bu.sf,
      showDragHandle: true,
      builder: (_) => const _ReactionPicker(),
    );

class _ReactionPicker extends StatefulWidget {
  const _ReactionPicker();
  @override
  State<_ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<_ReactionPicker> {
  final _input = TextEditingController();
  bool _invalid = false;
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _choose(String value) {
    final emoji = value.trim();
    if (RecentReactions.isEmoji(emoji)) {
      Navigator.pop(context, RecentReactions.display(emoji));
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.bu;
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .64,
        child: Column(children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 8, 12),
            child: Row(children: [
              Expanded(
                  child: Text(l.chatReactionPickerTitle,
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  icon: const Icon(BuIcons.x)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const ValueKey('reactionEmojiInput'),
              controller: _input,
              onChanged: (_) {
                if (_invalid) setState(() => _invalid = false);
              },
              onSubmitted: _choose,
              decoration: InputDecoration(
                hintText: l.chatReactionKeyboardHint,
                errorText: _invalid ? l.chatReactionOneEmoji : null,
                suffixIcon: IconButton(
                    tooltip: l.chatDetailSend,
                    onPressed: () => _choose(_input.text),
                    icon: Icon(BuIcons.check, color: t.prPressed)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
                builder: (context, c) => GridView.count(
                      key: const ValueKey('reactionEmojiGrid'),
                      crossAxisCount: (c.maxWidth / 48).floor().clamp(4, 10),
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                      children: [
                        for (final emoji in _catalog.split(' '))
                          Semantics(
                            button: true,
                            label: l.chatDetailReactionLabel(emoji),
                            child: InkWell(
                              onTap: () => _choose(emoji),
                              borderRadius: BorderRadius.circular(16),
                              child: Center(
                                  child: Text(
                                emoji,
                                textScaler: TextScaler.noScaling,
                                style: const TextStyle(
                                    fontSize: 30,
                                    fontFamily: 'Apple Color Emoji',
                                    fontFamilyFallback: [
                                      'Noto Color Emoji',
                                      'Segoe UI Emoji'
                                    ]),
                              )),
                            ),
                          ),
                      ],
                    )),
          ),
        ]),
      ),
    );
  }
}
