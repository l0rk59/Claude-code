import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/chat_controller.dart';
import '../controllers/home_controller.dart';
import '../models/chat_session.dart';
import '../services/cluster_service.dart';
import '../core/haptics.dart';
import '../core/colors.dart';
import '../core/ui.dart';

/// Two-bar "sidebar" glyph — the long bar over a short one reads as a list
/// rather than the generic hamburger.
class SidebarGlyph extends StatelessWidget {
  final Color color;
  const SidebarGlyph({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(
          width: w,
          height: 2,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(1)),
        );
    return SizedBox(
      width: 22,
      height: 22,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [bar(18), const SizedBox(height: 5), bar(11)],
      ),
    );
  }
}

/// The sidebar: new chat, search, history grouped by date, and the way to
/// every other section (models, server, cluster, settings).
class ChatDrawer extends StatefulWidget {
  /// Shown permanently next to the chat (wide screens) instead of as a
  /// drawer.
  final bool pinned;
  const ChatDrawer({super.key, this.pinned = false});

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  ChatController get _chat => Get.find<ChatController>();

  void _newChat() {
    Haptics.selectionClick();
    // Reuse the current blank chat instead of piling up empty sessions.
    if (_chat.messages.isNotEmpty || _chat.currentSessionId.value.isEmpty) {
      _chat.createNewChat();
    }
    Get.find<HomeController>().showChat();
  }

  void _open(ChatSession s) {
    Haptics.selectionClick();
    if (_chat.currentSessionId.value != s.id) _chat.openChat(s.id);
    Get.find<HomeController>().showChat();
  }

  Future<void> _confirmDelete(BuildContext context, ChatSession s) async {
    Haptics.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: isDark ? AppColors.elevatedDark : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isDark ? AppColors.textDark : AppColors.textLight)),
              const SizedBox(height: 4),
              Text('This conversation will be permanently deleted.'.tr,
                  style: GoogleFonts.inter(
                      fontSize: 13.5, color: Theme.of(ctx).hintColor)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(
                  child: TonalButton.neutral(ctx,
                      label: 'Cancel'.tr,
                      onTap: () => Navigator.pop(ctx, false)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TonalButton.destructive(ctx,
                      label: 'Delete'.tr,
                      onTap: () => Navigator.pop(ctx, true)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true) _chat.deleteChat(s.id);
  }

  /// Buckets sessions (already sorted newest first) into date sections.
  List<(String, List<ChatSession>)> _group(List<ChatSession> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String bucket(DateTime d) {
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff <= 0) return 'Today'.tr;
      if (diff == 1) return 'Yesterday'.tr;
      if (diff < 7) return 'Previous 7 days'.tr;
      if (diff < 30) return 'Previous 30 days'.tr;
      return 'Older'.tr;
    }

    final out = <(String, List<ChatSession>)>[];
    for (final s in list) {
      final b = bucket(s.updatedAt);
      if (out.isEmpty || out.last.$1 != b) out.add((b, []));
      out.last.$2.add(s);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final home = Get.find<HomeController>();
    final bg = t.isDark ? AppColors.sunkenDark : AppColors.sunkenLight;

    final content = SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Brand
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(children: [
            Image.asset('assets/icons/appicon.png', width: 28, height: 28),
            const SizedBox(width: 10),
            Text('PrivateLM',
                style: GoogleFonts.inter(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: t.text)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PrimaryButton(
              label: 'New chat'.tr,
              icon: Icons.add_rounded,
              onPressed: _newChat),
        ),
        const SizedBox(height: 10),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
                color: t.fill, borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: GoogleFonts.inter(fontSize: 15, color: t.text),
              cursorColor: t.accent,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search'.tr,
                hintStyle: GoogleFonts.inter(fontSize: 15, color: t.muted),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 19, color: t.muted),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 38, minHeight: 40),
                suffixIcon: _query.isEmpty
                    ? null
                    : GestureDetector(
                        onTap: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        child: Icon(Icons.cancel_rounded,
                            size: 17, color: t.muted),
                      ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        // History
        Expanded(child: Obx(() {
          final current = _chat.currentSessionId.value;
          // Hide blank "New chat" shells, except the one that's open.
          final all = _chat.sessions
              .where((s) =>
                  (s.lastMessage ?? '').trim().isNotEmpty || s.id == current)
              .where((s) =>
                  _query.isEmpty ||
                  s.title.toLowerCase().contains(_query) ||
                  (s.lastMessage ?? '').toLowerCase().contains(_query))
              .toList();

          if (all.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
              child: Column(children: [
                Icon(
                    _query.isEmpty
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.search_off_rounded,
                    size: 28,
                    color: t.faint),
                const SizedBox(height: 12),
                Text(
                    _query.isEmpty
                        ? 'No conversations yet'.tr
                        : 'No matches'.tr,
                    style: t.bodyStrong),
                const SizedBox(height: 4),
                Text(
                    _query.isEmpty
                        ? 'Your chats will show up here.'.tr
                        : 'Try a different word.'.tr,
                    textAlign: TextAlign.center,
                    style: t.caption),
              ]),
            );
          }

          final groups = _group(all);
          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            children: [
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
                  child: Text(g.$1,
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: t.muted)),
                ),
                for (final s in g.$2)
                  _SessionRow(
                    session: s,
                    active: s.id == current,
                    text: t.text,
                    selected:
                        t.accent.withValues(alpha: t.isDark ? 0.18 : 0.10),
                    onTap: () => _open(s),
                    onLongPress: () => _confirmDelete(context, s),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
                child: Text('Long-press a chat to delete it'.tr,
                    style: GoogleFonts.inter(fontSize: 12, color: t.faint)),
              ),
            ],
          );
        })),
        // Sections
        Container(height: 0.5, color: t.hairline),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(children: [
            _NavRow(
                icon: Icons.layers_outlined,
                label: 'Models'.tr,
                onTap: home.openModels),
            _NavRow(
                icon: Icons.lan_outlined,
                label: 'Local API server'.tr,
                onTap: home.openServer),
            if (Get.isRegistered<ClusterService>())
              _NavRow(
                  icon: Icons.hub_outlined,
                  label: 'Phone cluster'.tr,
                  onTap: home.openCluster),
            _NavRow(
                icon: Icons.settings_outlined,
                label: 'Settings'.tr,
                onTap: home.openSettings),
          ]),
        ),
      ]),
    );

    if (widget.pinned) return Material(color: bg, child: content);

    final width = (MediaQuery.of(context).size.width * 0.86).clamp(0.0, 340.0);
    return Drawer(
      width: width,
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(24))),
      child: content,
    );
  }
}

/// A section link at the bottom of the sidebar.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _NavRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        highlightColor: t.fill,
        onTap: () {
          Haptics.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(children: [
            Icon(icon, size: 21, color: t.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.15,
                      color: t.text)),
            ),
            Icon(Icons.chevron_right_rounded, size: 19, color: t.faint),
          ]),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final ChatSession session;
  final bool active;
  final Color text;
  final Color selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _SessionRow({
    required this.session,
    required this.active,
    required this.text,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: active ? selected : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          onLongPress: onLongPress,
          splashFactory: NoSplash.splashFactory,
          highlightColor: selected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            child: Text(session.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    letterSpacing: -0.15,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: text)),
          ),
        ),
      ),
    );
  }
}
