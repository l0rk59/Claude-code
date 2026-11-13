import 'package:get/get.dart';

import 'hive_service.dart';

/// A request the user makes often, kept to start a message with it:
/// "Summarise in five points:", "Translate into English:"…
class TaskTemplate {
  final String title;

  /// What goes into the message box. The user adds their text after it.
  final String prompt;

  /// Made by the user (can be deleted), not one of the app's.
  final bool custom;

  const TaskTemplate(this.title, this.prompt, {this.custom = false});

  Map<String, String> toMap() => {'title': title, 'prompt': prompt};
}

/// The app's tasks and the user's own.
class TaskTemplates {
  static const _key = 'task_templates';

  /// The app's tasks, in the app's language.
  static List<TaskTemplate> builtIn() => [
        TaskTemplate('Summarise'.tr,
            'Summarise the following text in five short points:\n\n'.tr),
        TaskTemplate('Key points and actions'.tr,
            'List the key points, then the actions to take, from this text:\n\n'.tr),
        TaskTemplate('Translate into English'.tr,
            'Translate the following text into natural English:\n\n'.tr),
        TaskTemplate('Translate into French'.tr,
            'Translate the following text into natural French:\n\n'.tr),
        TaskTemplate('Correct the spelling'.tr,
            'Correct the spelling and grammar of this text without changing its meaning, then list the changes:\n\n'.tr),
        TaskTemplate('Explain simply'.tr,
            'Explain this simply, as to someone who knows nothing about it, with an example:\n\n'.tr),
        TaskTemplate('Write an email'.tr,
            'Write a short, polite email that says:\n\n'.tr),
        TaskTemplate('Reply to a message'.tr,
            'Write a reply to this message. Tone: friendly and brief.\n\n'.tr),
        TaskTemplate('Make a plan'.tr,
            'Make a step-by-step plan, with what to do first, for:\n\n'.tr),
        TaskTemplate('Pros and cons'.tr,
            'Give the pros and cons, then your recommendation, for:\n\n'.tr),
      ];

  static List<TaskTemplate> custom(HiveService hive) => [
        for (final m in hive.getSetting<List>(_key, defaultValue: const []) ??
            const [])
          if (m is Map && m['title'] is String && m['prompt'] is String)
            TaskTemplate(m['title'] as String, m['prompt'] as String,
                custom: true),
      ];

  /// Saves [prompt] as a task named [title] (replacing one of that name).
  static Future<void> save(HiveService hive, String title, String prompt) async {
    final name = title.trim();
    if (name.isEmpty || prompt.trim().isEmpty) return;
    final list = custom(hive).where((t) => t.title != name).toList()
      ..add(TaskTemplate(name, prompt, custom: true));
    await hive.setSetting(_key, [for (final t in list) t.toMap()]);
  }

  static Future<void> delete(HiveService hive, String title) async {
    final list = custom(hive).where((t) => t.title != title).toList();
    await hive.setSetting(_key, [for (final t in list) t.toMap()]);
  }
}
