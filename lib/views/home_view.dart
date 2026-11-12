import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../core/ui.dart';
import '../widgets/chat_drawer.dart';
import 'chat_view.dart';

/// The app's root: the chat, with the sidebar (history and the way to every
/// other section) as a drawer on phones and pinned on wide screens.
class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final wide =
        MediaQuery.sizeOf(context).width >= HomeController.wideLayoutWidth;
    return Scaffold(
      key: controller.scaffoldKey,
      backgroundColor: t.bg,
      drawer: wide ? null : const ChatDrawer(),
      drawerScrimColor: Colors.black.withValues(alpha: t.isDark ? 0.6 : 0.32),
      drawerEdgeDragWidth: 28,
      body: wide
          ? Row(children: [
              const SizedBox(width: 320, child: ChatDrawer(pinned: true)),
              Container(width: 0.5, color: t.hairline),
              const Expanded(child: ChatView()),
            ])
          : const ChatView(),
    );
  }
}
