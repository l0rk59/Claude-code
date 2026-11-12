import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../views/cluster_view.dart';
import '../views/model_view.dart';
import '../views/server_view.dart';
import '../views/settings_view.dart';
import 'model_controller.dart';

/// The chat is the home screen. Every other section (models, server,
/// cluster, settings) opens over it, from the sidebar or a shortcut.
class HomeController extends GetxController {
  /// Layouts at least this wide keep the sidebar pinned next to the chat.
  static const wideLayoutWidth = 900.0;

  /// Root scaffold key: the sidebar hangs off the root scaffold.
  final scaffoldKey = GlobalKey<ScaffoldState>();

  void openSidebar() => scaffoldKey.currentState?.openDrawer();

  void closeSidebar() => scaffoldKey.currentState?.closeDrawer();

  /// Back to the chat: closes the sidebar and any section opened over it.
  void showChat() {
    closeSidebar();
    Get.until((route) => route.isFirst);
  }

  /// Opens Models, optionally on a scope: 'local', 'browse' or 'online'.
  void openModels({String? scope}) {
    if (scope != null) Get.find<ModelController>().modelScope.value = scope;
    _open(() => const ModelView());
  }

  void openServer() => _open(() => const ServerView());

  void openCluster() => _open(() => const ClusterView());

  void openSettings() => _open(() => const SettingsView());

  void _open(Widget Function() page) {
    closeSidebar();
    Get.to(page);
  }
}
