import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../core/ui.dart';
import '../services/document_library.dart';
import '../services/document_library_service.dart';

/// The documents the chat can search: added from the phone's files, read
/// once, and searched on the phone when "My documents" is on.
class DocumentsView extends StatefulWidget {
  const DocumentsView({super.key});

  @override
  State<DocumentsView> createState() => _DocumentsViewState();
}

class _DocumentsViewState extends State<DocumentsView> {
  bool _adding = false;

  DocumentLibraryService? get _service =>
      Get.isRegistered<DocumentLibraryService>()
          ? Get.find<DocumentLibraryService>()
          : null;

  Future<void> _add() async {
    final service = _service;
    if (service == null) return;
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: const ['pdf', 'txt', 'md', 'docx', 'csv', 'json', 'html'],
    );
    if (picked == null) return;
    setState(() => _adding = true);
    var added = 0;
    for (final file in picked.files) {
      if (file.path == null) continue;
      try {
        await service.addFile(file.path!, file.name);
        added++;
      } catch (e) {
        showToast(file.name, e.toString().replaceFirst('Exception: ', ''),
            tone: ToastTone.error);
      }
    }
    if (!mounted) return;
    setState(() => _adding = false);
    if (added > 0) {
      showToast('Documents added'.tr,
          'Switch on "My documents" in the + menu to ask about them.'.tr,
          tone: ToastTone.success);
    }
  }

  Future<void> _remove(LibraryDocument document) async {
    final ok = await confirmSheet(
      context,
      title: 'Remove this document?'.tr,
      message: '@name will no longer be searched. The file itself stays on the phone.'
          .trParams({'name': document.name}),
      confirmLabel: 'Remove'.tr,
      destructive: true,
    );
    if (ok) await _service?.remove(document.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final service = _service;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: appScreenBar(context, title: 'My documents'.tr),
      body: service == null
          ? EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'Not available here'.tr,
              message: 'Documents need the phone app.'.tr,
            )
          : Obx(() {
              final docs = service.documents.toList()
                ..sort((a, b) => b.added.compareTo(a.added));
              return ListView(
                padding: kPagePadding,
                children: [
                  Text(
                    'Add your files (PDF, Word, text): when "My documents" is on, the passages that answer your question are given to the model with it. Everything stays on the phone.'
                        .tr,
                    style: t.caption,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Add documents'.tr,
                    icon: Icons.add_rounded,
                    busy: _adding,
                    onPressed: _adding ? null : _add,
                  ),
                  if (docs.isEmpty)
                    EmptyState(
                      icon: Icons.description_outlined,
                      title: 'No documents yet'.tr,
                    )
                  else ...[
                    SectionHeader('@count documents'
                        .trParams({'count': '${docs.length}'})),
                    AppGroup(dividerIndent: 60, children: [
                      for (final d in docs)
                        AppRow(
                          icon: Icons.description_outlined,
                          title: d.name,
                          subtitle: [
                            DateFormat.yMMMd(Get.locale?.languageCode)
                                .format(d.added),
                            '@count passages'
                                .trParams({'count': '${d.chunks.length}'}),
                          ].join(' · '),
                          trailing: IconButton(
                            tooltip: 'Remove'.tr,
                            icon: Icon(Icons.close_rounded, color: t.muted),
                            onPressed: () => _remove(d),
                          ),
                        ),
                    ]),
                  ],
                ],
              );
            }),
    );
  }
}
