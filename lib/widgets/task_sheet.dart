import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/ui.dart';
import '../services/hive_service.dart';
import '../services/task_templates.dart';

/// Reusable requests: picking one starts the message with it. The current
/// message can be kept as a new one.
class TaskSheet extends StatefulWidget {
  /// The text in the message box now (to save it as a task).
  final String current;

  /// Puts the task's text in the message box.
  final void Function(String prompt) onPick;

  const TaskSheet({super.key, required this.current, required this.onPick});

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  HiveService get _hive => Get.find<HiveService>();
  late List<TaskTemplate> _mine = TaskTemplates.custom(_hive);

  Future<void> _saveCurrent() async {
    final name = TextEditingController();
    final title = await showAppSheet<String>(
      context,
      title: 'Save as a task'.tr,
      subtitle: widget.current.length > 80
          ? '${widget.current.substring(0, 80)}…'
          : widget.current,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: name,
            autofocus: true,
            decoration: appInputDecoration(ctx, hint: 'Name of the task'.tr),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
              label: 'Save'.tr, onPressed: () => Navigator.pop(ctx, name.text)),
        ],
      ),
    );
    name.dispose();
    if (title == null || title.trim().isEmpty) return;
    await TaskTemplates.save(_hive, title, '${widget.current.trim()}\n\n');
    setState(() => _mine = TaskTemplates.custom(_hive));
  }

  Future<void> _delete(TaskTemplate task) async {
    await TaskTemplates.delete(_hive, task.title);
    setState(() => _mine = TaskTemplates.custom(_hive));
  }

  Widget _row(TaskTemplate task) => AppRow(
        title: task.title,
        subtitle: task.prompt.trim(),
        onTap: () {
          Navigator.pop(context);
          widget.onPick(task.prompt);
        },
        trailing: task.custom
            ? IconButton(
                tooltip: 'Delete'.tr,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () => _delete(task),
              )
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.current.trim().isNotEmpty) ...[
          PillButton(
            label: 'Save this message as a task'.tr,
            icon: Icons.bookmark_add_outlined,
            onPressed: _saveCurrent,
          ),
          const SizedBox(height: 14),
        ],
        if (_mine.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text('Your tasks'.tr, style: t.label),
          ),
          AppGroup(dividerIndent: 16, children: [
            for (final task in _mine) _row(task),
          ]),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('Ready-made'.tr, style: t.label),
        ),
        AppGroup(dividerIndent: 16, children: [
          for (final task in TaskTemplates.builtIn()) _row(task),
        ]),
      ],
    );
  }
}
