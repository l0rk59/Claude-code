import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute, kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:uuid/uuid.dart';
import 'package:gal/gal.dart';
import '../controllers/model_controller.dart';
import '../controllers/settings_controller.dart';
import '../core/constants.dart';
import '../core/ui.dart';
import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../ffi/sd_backend.dart';
import '../services/hive_service.dart';
import '../services/inference_service.dart';
import '../services/cloud_service.dart';
import '../services/local_image_service.dart';
import '../services/app_log_service.dart';
import '../services/image_generation_notification_service.dart';
import '../services/document_extractor_service.dart';
import '../services/agents/agent_profiles.dart';
import '../services/agents/agent_runner.dart';
import '../services/agents/agent_tools.dart';
import '../services/chat_tools.dart';
import '../services/document_library.dart';
import '../services/document_library_service.dart';
import '../services/memory_service.dart';
import '../services/token_coalescer.dart';
import '../services/web_search_service.dart';
import '../utils/thought_parser.dart';

const int _visionImageMaxSide = 768;
const int _visionImageJpegQuality = 72;

Uint8List? _resizeVisionImageBytes(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final longestSide =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longestSide <= _visionImageMaxSide) {
    return bytes;
  }

  final resized = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? _visionImageMaxSide : null,
    height: decoded.height > decoded.width ? _visionImageMaxSide : null,
    interpolation: img.Interpolation.average,
  );
  return Uint8List.fromList(
    img.encodeJpg(resized, quality: _visionImageJpegQuality),
  );
}

class ChatController extends GetxController {
  final HiveService _hive = Get.find<HiveService>();
  final _uuid = const Uuid();

  // State
  final sessions = <ChatSession>[].obs;
  final messages = <ChatMessage>[].obs;
  final currentSessionId = ''.obs;
  final isLoading = false.obs;
  final inputText = ''.obs;
  final selectedImagePath = Rxn<String>();
  final selectedImageBase64 = Rxn<String>();
  final selectedFileName = Rxn<String>();
  final selectedFileContent = Rxn<String>();
  final selectedFilePath = Rxn<String>();
  final selectedFileType = Rxn<String>();
  final selectedFileSize = 0.obs;

  // Batch Image Generation
  final batchPrompts = <String>[].obs;
  final batchModeAccepted = false.obs;
  final lastBatchImagesBase64 = <String>[].obs;

  // Real-time streaming state — the AI response as it's being generated
  final streamingResponse = ''.obs;

  /// Groups the tokens of the reply in progress before they reach
  /// [streamingResponse]. Null when nothing is being generated.
  TokenCoalescer? _tokenStream;

  /// Look up the web before answering, and give the model what it found.
  final webSearch = false.obs;

  /// Look up the user's documents before answering.
  final useDocuments = false.obs;

  /// What the assistant is doing before it starts writing ("Searching the
  /// web…"), '' otherwise.
  final activity = ''.obs;

  /// For tests: replaces the web search.
  WebSearchService? webSearchService;

  /// The specialised assistant or team answering ('' for the plain
  /// assistant). See [AgentStore].
  final activeAgent = ''.obs;

  /// What an agent run shows while it works, throttled like tokens.
  Timer? _agentDisplayTimer;
  String? _agentDisplayPending;
  final isStreaming = false.obs;
  final streamingAttachmentType = Rxn<String>();

  // Image generation progress (lightweight, replaces text-heavy updates)
  final imageGenStep = 0.obs;
  final imageGenTotal = 0.obs;
  final imageGenEstimatedSecs = 0.obs;
  final imageGenStartTime = Rxn<DateTime>();
  final imageGenDecoding = false.obs;

  // Speech-to-text
  final isListening = false.obs;
  final sttAvailable = false.obs;
  final _speech = stt.SpeechToText();

  final textController = TextEditingController();
  final inputFocus = FocusNode();
  final scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _followStreaming = true;
  bool _scrollListenerAttached = false;
  int _generationSerial = 0;
  bool _batchCancelled = false;

  @override
  void onInit() {
    super.onInit();
    activeAgent.value = AgentStore(_hive).active;
    scrollController.addListener(_handleUserScroll);
    _scrollListenerAttached = true;
    batchModeAccepted.value = _hive.getSetting<bool>(
            AppConstants.keyBatchModeWarningAccepted,
            defaultValue: false) ??
        false;
    loadSessions();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      sttAvailable.value = await _speech.initialize(
        onError: (_) => isListening.value = false,
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            isListening.value = false;
          }
        },
      );
    } catch (_) {
      sttAvailable.value = false;
    }
  }

  Future<void> toggleListening() async {
    try {
      if (isListening.value) {
        await _speech.stop();
        isListening.value = false;
        return;
      }
      if (!sttAvailable.value) {
        try {
          final ok = await _speech.initialize();
          sttAvailable.value = ok;
        } catch (_) {
          sttAvailable.value = false;
        }
        if (!sttAvailable.value) return;
      }
      await _speech.listen(
        onResult: (result) {
          textController.text = result.recognizedWords;
          inputText.value = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 60),
        pauseFor: const Duration(seconds: 4),
        // Listen in the app's language.
        localeId: Get.locale?.toString() ?? 'en_US',
      );
      isListening.value = true;
    } catch (_) {
      isListening.value = false;
    }
  }

  @override
  void onClose() {
    _scrollTimer?.cancel();
    _agentDisplayTimer?.cancel();
    if (_scrollListenerAttached) {
      scrollController.removeListener(_handleUserScroll);
    }
    textController.dispose();
    inputFocus.dispose();
    scrollController.dispose();
    super.onClose();
  }

  // ─── Session Management ─────────────────────────

  void acceptBatchMode() {
    batchModeAccepted.value = true;
    _hive.setSetting(AppConstants.keyBatchModeWarningAccepted, true);
  }

  void loadSessions() {
    final raw = _hive.getAllSessions();
    sessions.value = raw.map((m) => ChatSession.fromMap(m)).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void createNewChat() {
    final id = _uuid.v4();
    final session = ChatSession(id: id, title: 'New chat'.tr);
    _hive.saveSession(id, session.toMap());
    sessions.insert(0, session);
    openChat(id);
  }

  void _resetInferenceContext() {
    final inference = Get.find<InferenceService>();
    if (inference.isModelLoaded.value) {
      unawaited(inference.resetConversation());
    }
  }

  void openChat(String sessionId) {
    stopGenerating();
    currentSessionId.value = sessionId;
    final raw = _hive.getMessagesForChat(sessionId);
    messages.value = raw.map((m) => ChatMessage.fromMap(m)).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final inference = Get.find<InferenceService>();
    if (inference.isModelLoaded.value) {
      inference.refreshContextInfo();
    }
    _resetInferenceContext();
    _scrollToBottom(force: true);
  }

  void deleteChat(String sessionId) {
    if (currentSessionId.value == sessionId && isLoading.value) {
      stopGenerating();
    }
    _hive.deleteSession(sessionId);
    sessions.removeWhere((s) => s.id == sessionId);
    if (currentSessionId.value == sessionId) {
      currentSessionId.value = '';
      messages.clear();
    }
  }

  // ─── Image Handling ─────────────────────────────

  Future<void> pickImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      maxWidth: _visionImageMaxSide.toDouble(),
      maxHeight: _visionImageMaxSide.toDouble(),
      imageQuality: _visionImageJpegQuality,
    );
    if (file != null) {
      selectedImagePath.value = file.path;
      selectedImageBase64.value = null;
      selectedFileName.value = file.name;
      selectedFilePath.value = file.path;
      selectedFileType.value = 'image';
      selectedFileSize.value = await file.length();
      selectedFileContent.value = null;
      _checkVisionSupport();
    }
  }

  void clearImage({bool deleteFile = true}) {
    final path = selectedImagePath.value;
    selectedImagePath.value = null;
    selectedImageBase64.value = null;
    if (deleteFile && path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
    if (selectedFileType.value == 'image') {
      clearFile();
    }
  }

  void _checkVisionSupport() {
    final s = Get.find<SettingsController>();
    if (s.inferenceMode.value != 'cloud') return;

    final provider = s.cloudProvider.value;
    String modelName = '';
    switch (provider) {
      case 'anthropic':
        modelName = s.anthropicModel.value;
        break;
      case 'google':
        modelName = s.googleModel.value;
        break;
      case 'kimi':
        modelName = s.kimiModel.value;
        break;
      case 'stability':
        modelName = s.stabilityModel.value;
        break;
      case 'nvidia':
        modelName = s.nvidiaModel.value;
        break;
      case 'openrouter':
        modelName = s.openRouterModel.value;
        break;
      case 'deepseek':
        modelName = s.deepSeekModel.value;
        break;
      case 'custom':
        modelName = s.customCloudModel.value;
        break;
      default:
        modelName = s.openaiModel.value;
        break;
    }

    final model = modelName.toLowerCase();

    // Known vision keywords in cloud model names
    final isVision = model.contains('vision') ||
        model.contains('-vl') ||
        model.contains('gpt-4o') ||
        model.contains('claude-3') ||
        model.contains('gemini') ||
        model.contains('pixtral') ||
        model.contains('llava') ||
        model.contains('omni');

    if (!isVision) {
      showToast(
        'Warning: Text-Only Model'.tr,
        'The selected model (@name) might not support images. If you get an error, switch to a vision model (like Gemini, GPT-4o, or Claude 3).'
            .trParams({'name': modelName}),
        tone: ToastTone.warning,
        duration: const Duration(seconds: 6),
      );
    }
  }

  /// [documentsOnly] limits the picker to PDF/DOCX/text/code — used for
  /// text-only local models (e.g. GGUF) that can't take images or audio.
  Future<void> pickFile({bool documentsOnly = false}) async {
    try {
      const mediaExtensions = {
        'png', 'jpg', 'jpeg', 'webp', 'gif', 'heic', //
        'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac',
      };
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'gif',
          'heic',
          'pdf',
          'docx',
          'mp3',
          'm4a',
          'wav',
          'aac',
          'ogg',
          'flac',
          'txt',
          'md',
          'json',
          'csv',
          'log',
          'yaml',
          'yml',
          'xml',
          'dart',
          'kt',
          'java',
          'js',
          'ts',
          'py'
        ].where((e) => !documentsOnly || !mediaExtensions.contains(e)).toList(),
        withData: kIsWeb,
      );
      if (result == null) return;
      final file = result.files.single;
      final extension = file.extension?.toLowerCase() ?? '';
      final fileType = _attachmentTypeForExtension(extension);

      // Reject unsupported or extension-less files
      if (documentsOnly && (fileType == 'image' || fileType == 'audio')) {
        showToast(
          'Not supported by this model'.tr,
          'This model reads text only. Attach a PDF, DOCX, or text/code file.'
              .tr,
          tone: ToastTone.warning,
        );
        return;
      }

      if (extension.isEmpty || fileType == 'file') {
        showToast(
          'Unsupported file'.tr,
          'Only images, audio, PDF, DOCX, and text/code files are supported.'
              .tr,
          tone: ToastTone.warning,
        );
        return;
      }

      if (fileType == 'image') {
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) return;
        final optimizedPath = await _prepareVisionImagePath(
          bytes: bytes,
          originalName: file.name,
          fallbackPath: file.path,
        );

        selectedFileName.value = file.name;
        selectedFilePath.value = optimizedPath;
        selectedFileType.value = 'image';
        selectedFileSize.value = await File(optimizedPath).length();
        selectedFileContent.value = null;
        selectedImagePath.value = optimizedPath;
        selectedImageBase64.value = null;
        _checkVisionSupport();
        return;
      }

      selectedFileName.value = file.name;
      selectedFilePath.value = file.path;
      selectedFileType.value = fileType;
      selectedFileSize.value = file.size;
      selectedFileContent.value = null;

      selectedImagePath.value = null;
      selectedImageBase64.value = null;

      if (fileType == 'pdf' || fileType == 'docx') {
        final path = file.path;
        if (path != null) {
          try {
            var content = await DocumentExtractorService.extractText(
              path,
              extension,
            );
            selectedFileContent.value = _fitToContext(content);
          } catch (e) {
            Get.find<AppLogService>().warning(
              'Document extraction failed',
              details: e,
            );
            selectedFileContent.value =
                '[Could not extract text from ${selectedFileName.value}: $e]';
          }
        }
      } else if (fileType == 'text') {
        final bytes = file.bytes ??
            (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) return;
        selectedFileSize.value = file.size > 0 ? file.size : bytes.length;
        selectedFileContent.value =
            _fitToContext(utf8.decode(bytes, allowMalformed: true));
      }
    } catch (e) {
      Get.find<AppLogService>().warning('File attachment failed', details: e);
      showToast('File not attached'.tr, '$e', tone: ToastTone.error);
    }
  }

  /// Trims extracted document text so it fits the model's context window.
  /// Cloud models get up to 12k chars; local models get roughly half their
  /// context (~4 chars per token), leaving room for history and the reply.
  String _fitToContext(String content) {
    var limit = 12000;
    final s = Get.find<SettingsController>();
    if (s.inferenceMode.value == 'local') {
      final inf = Get.find<InferenceService>();
      final ctx = inf.contextTokensTotal.value > 0
          ? inf.contextTokensTotal.value
          : s.contextSize.value;
      if (ctx > 0) limit = (ctx * 2).clamp(2000, 12000).toInt();
    }
    if (content.length <= limit) return content;
    return '${content.substring(0, limit)}\n\n[File truncated to fit the model\'s context window]';
  }

  void clearFile() {
    selectedFileName.value = null;
    selectedFileContent.value = null;
    selectedFilePath.value = null;
    selectedFileType.value = null;
    selectedFileSize.value = 0;
  }

  Future<String> _prepareVisionImagePath({
    required Uint8List bytes,
    required String originalName,
    String? fallbackPath,
  }) async {
    final resized = await compute(_resizeVisionImageBytes, {'bytes': bytes});
    if (resized == null) {
      if (fallbackPath != null && fallbackPath.isNotEmpty) return fallbackPath;
      final tempDir = await getTemporaryDirectory();
      final failedDecodeFile = File(
        '${tempDir.path}/ai_chat_image_${DateTime.now().millisecondsSinceEpoch}_$originalName',
      );
      await failedDecodeFile.writeAsBytes(bytes, flush: false);
      return failedDecodeFile.path;
    }

    if (resized.length == bytes.length &&
        fallbackPath != null &&
        fallbackPath.isNotEmpty) {
      return fallbackPath;
    }

    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/ai_chat_vision_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(resized, flush: false);
    return file.path;
  }

  // ─── Send Message ───────────────────────────────

  Future<void> generateBatch() async {
    if (batchPrompts.isEmpty || isLoading.value || isStreaming.value) return;

    // Copy the list to avoid concurrent modification issues
    final promptsToRun = List<String>.from(batchPrompts);
    batchPrompts.clear();
    lastBatchImagesBase64.clear();

    final generatedImagesBase64 = <String>[];
    _batchCancelled = false;

    for (final prompt in promptsToRun) {
      if (_batchCancelled) break;
      textController.text = prompt;
      // sendMessage() returns once this prompt's generation has finished.
      await sendMessage();
      if (_batchCancelled) break; // User tapped stop

      // Capture generated image
      final lastMsg = messages.lastOrNull;
      if (lastMsg != null &&
          lastMsg.role == 'assistant' &&
          lastMsg.imageBase64 != null) {
        generatedImagesBase64.add(lastMsg.imageBase64!);
      }

      // Add a small delay between generations to let UI breathe
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    if (generatedImagesBase64.isNotEmpty) {
      lastBatchImagesBase64.value = generatedImagesBase64;
    }
  }

  Future<void> downloadLastBatch() async {
    if (lastBatchImagesBase64.isEmpty) return;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          showToast('Permission Denied'.tr,
              'Cannot save images without gallery access.'.tr,
              tone: ToastTone.error);
          return;
        }
      }
      for (final base64 in lastBatchImagesBase64) {
        await Gal.putImageBytes(base64Decode(base64));
      }
      showToast(
          'Success'.tr,
          'Saved @count images to gallery.'
              .trParams({'count': '${lastBatchImagesBase64.length}'}),
          tone: ToastTone.success);
      lastBatchImagesBase64.clear();
    } catch (e) {
      showToast('Error'.tr, 'Failed to save images: @error'.trParams({'error': '$e'}),
          tone: ToastTone.error);
    }
  }

  Future<void> sendMessage() async {
    if (isLoading.value || isStreaming.value) return;

    final text = textController.text.trim();
    final hasAttachment =
        selectedImagePath.value != null || selectedFileName.value != null;
    if (text.isEmpty && !hasAttachment) return;
    final fileName = selectedFileName.value;
    final fileContent = selectedFileContent.value;
    final filePath = selectedFilePath.value;
    final fileType = selectedFileType.value;
    final fileSize = selectedFileSize.value;
    final imagePath = selectedImagePath.value;
    final imageBase64 = selectedImageBase64.value;
    final visibleText =
        text.isEmpty ? _defaultAttachmentPrompt(fileType) : text;
    final effectiveText = (fileContent != null && fileContent.trim().isNotEmpty)
        ? '$visibleText\n\nAttached file: $fileName\n```text\n$fileContent\n```'
        : visibleText;

    // Create a session if none selected
    if (currentSessionId.value.isEmpty) {
      createNewChat();
    }

    // Mark busy before the first await (reading an attached image), so a
    // double tap can't pass the guard above twice and send duplicates.
    // Done after createNewChat(), which stops any in-flight generation.
    isLoading.value = true;

    // Encode image to base64 if it's not already pre-encoded, so the message
    // saved in history contains the image bytes and is 100% stable.
    String? imgBase64 = imageBase64;
    if (imgBase64 == null && imagePath != null && !kIsWeb) {
      try {
        imgBase64 = base64Encode(await File(imagePath).readAsBytes());
      } catch (_) {}
    }

    // Add user message
    final userMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: currentSessionId.value,
      role: 'user',
      content: effectiveText,
      imageBase64: imgBase64, // Always save the encoded base64 string
      imagePath: imagePath,
      fileName: fileName,
      fileContent: fileContent,
      filePath: filePath,
      fileType: fileType,
      fileSize: fileSize > 0 ? fileSize : null,
    );
    messages.add(userMsg);
    _hive.saveMessage(userMsg.id, userMsg.toMap());

    // Clear input preview UI state — but KEEP the physical file on disk
    // because the native inference engine needs to read it during generation.
    textController.clear();
    inputText.value = '';
    clearImage(deleteFile: false); // Reset visual fields, do NOT delete file!
    clearFile();
    _scrollToBottom(force: true);

    // Update session title (use first message as title)
    if (messages.where((m) => m.role == 'user').length == 1) {
      final title = visibleText.length > 40
          ? '${visibleText.substring(0, 40)}...'
          : visibleText;
      final session =
          sessions.firstWhere((s) => s.id == currentSessionId.value);
      final updated = session.copyWith(title: title, lastMessage: visibleText);
      _hive.saveSession(updated.id, updated.toMap());
      final idx = sessions.indexWhere((s) => s.id == updated.id);
      if (idx >= 0) sessions[idx] = updated;
    }

    // Start generating
    final generationId = ++_generationSerial;
    isLoading.value = true;
    isStreaming.value = true;
    streamingAttachmentType.value =
        (imagePath != null || fileType == 'audio') ? fileType : null;
    streamingResponse.value = '';
    _followStreaming = true;
    _scrollToBottom(force: true);

    try {
      DateTime? thoughtStartedAt;
      int? thoughtDurationSeconds;

      void trackThoughtTiming() {
        final parts = splitThoughtTags(streamingResponse.value);
        if (parts.hasThought && parts.isThinking && thoughtStartedAt == null) {
          thoughtStartedAt = DateTime.now();
        }
        if (parts.hasThought &&
            !parts.isThinking &&
            thoughtStartedAt != null &&
            thoughtDurationSeconds == null) {
          thoughtDurationSeconds =
              DateTime.now().difference(thoughtStartedAt!).inSeconds;
        }
      }

      // Tokens reach the screen a few times a second, not one by one:
      // every update re-reads the whole reply on the UI thread, which
      // slows the model down (see TokenCoalescer).
      // "Remember that…": kept for the next conversations too.
      final fact = Memories.requested(visibleText);
      if (fact != null && Memories.enabled(_hive)) {
        await Memories.add(_hive, fact);
        showToast('Remembered'.tr, fact, tone: ToastTone.success);
      }

      // Documents and web: what they hold goes into the question.
      var found = await _gatherContext(visibleText);
      if (generationId != _generationSerial) return;
      final promptText = ChatTools.withContext(
        effectiveText,
        ChatTools.context(found.web, found.passages),
        'Answer the question below. Use the numbered sources when they help, cite them like [1], and say so when they do not contain the answer.'
            .tr,
      );
      final tokens = TokenCoalescer(onText: (text) {
        // Ignore tokens from a generation the user already stopped.
        if (generationId != _generationSerial) return;
        streamingResponse.value += text;
        trackThoughtTiming();
        _scrollToBottom();
      });
      _tokenStream = tokens;

      final inferenceMode = _hive.getSetting(
            AppConstants.keyInferenceMode,
            defaultValue: 'local',
          ) ??
          'local';

      String rawResponse;

      // Build conversation history
      final history = messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {
                'role': m.role,
                'content': m.role == 'assistant'
                    ? ChatTools.stripFooter(splitThoughtTags(m.content).answer)
                    : m.content,
              })
          .toList();
      // The model reads this turn's question with what was found for it.
      if (promptText != effectiveText &&
          history.isNotEmpty &&
          history.last['role'] == 'user') {
        history.last['content'] = promptText;
      }

      final agentId = activeAgent.value;
      final imageModel = inferenceMode == 'local' &&
          Get.find<LocalImageService>().isModelLoaded.value;
      if (agentId.isNotEmpty && !imageModel) {
        // A specialised assistant or a team answers, with its tools.
        tokens.flush();
        final agentStarted = DateTime.now();
        final agentRun = await _runAgent(
          agentId,
          question: promptText,
          history: history.length > 1
              ? history.sublist(math.max(0, history.length - 5), history.length - 1)
              : const [],
          isCurrent: () => generationId == _generationSerial,
        );
        rawResponse = agentRun.$1;
        // The steps show as the work behind the answer, with its duration.
        if (rawResponse.startsWith('<think>')) {
          thoughtDurationSeconds =
              DateTime.now().difference(agentStarted).inSeconds;
        }
        found = (
          web: [...found.web, ...agentRun.$2.webSources],
          passages: [...found.passages, ...agentRun.$2.passages],
        );
      } else if (inferenceMode == 'local') {
        final localImage = Get.find<LocalImageService>();

        if (localImage.isModelLoaded.value) {
          // Local image generation
          final settings = Get.find<SettingsController>();
          final imageNotifications =
              Get.find<ImageGenerationNotificationService>();
          final steps = _hive.getSetting<int>(AppConstants.keyImageSteps,
                  defaultValue: AppConstants.defaultImageSteps) ??
              AppConstants.defaultImageSteps;
          final sizeSetting = settings.imageGenSize.value;
          final sizeLabel =
              sizeSetting == 0 ? 'Auto size'.tr : '${sizeSetting}x$sizeSetting';
          final backendLabel = localImage.currentBackend.value == Backend.cpu
              ? 'CPU'
              : localImage.currentBackend.value.displayName
                  .split(' ')
                  .first
                  .toUpperCase();
          imageGenStep.value = 0;
          imageGenTotal.value = steps;
          imageGenEstimatedSecs.value = 0;
          imageGenStartTime.value = DateTime.now();
          imageGenDecoding.value = false;
          await imageNotifications.start(
            modelName: localImage.loadedModelName.value,
            backend: backendLabel,
            steps: steps,
            sizeLabel: sizeLabel,
          );
          print('[ChatController] Starting image generation for: $text');
          final pngBytes = await localImage.generateImage(
            prompt: text,
            onProgress: (step, total) {
              if (generationId != _generationSerial) return;
              print(
                  '[ChatController] Progress callback: step=$step, total=$total');
              imageGenStep.value = step;
              imageGenTotal.value = total;
              if (step >= total && total > 0) {
                imageGenDecoding.value = true;
                print(
                    '[ChatController] Sampling complete, VAE decode in progress');
                imageNotifications.decoding();
              }
              if (step > 0 && total > 0 && step < total) {
                final start = imageGenStartTime.value;
                if (start != null) {
                  final elapsed =
                      DateTime.now().difference(start).inMilliseconds;
                  final avgMsPerStep = elapsed / step;
                  final remainingSteps = total - step;
                  imageGenEstimatedSecs.value =
                      (avgMsPerStep * remainingSteps / 1000).ceil();
                }
              }
              imageNotifications.update(
                step: step,
                total: total,
                etaSeconds: imageGenEstimatedSecs.value,
                elapsedSeconds: imageGenStartTime.value == null
                    ? 0
                    : DateTime.now()
                        .difference(imageGenStartTime.value!)
                        .inSeconds,
              );
              _scrollToBottom();
            },
          );
          // Calculate total generation time
          final genDurationMs = imageGenStartTime.value != null
              ? DateTime.now()
                  .difference(imageGenStartTime.value!)
                  .inMilliseconds
              : null;
          print(
              '[ChatController] generateImage returned, bytes=${pngBytes?.length}, duration=${genDurationMs}ms');

          // A stopped job must not post a completed/failed notification.
          if (generationId != _generationSerial) return;
          if (pngBytes != null) {
            await imageNotifications.complete(durationMs: genDurationMs ?? 0);
            rawResponse = '[IMAGE_BASE64]${base64Encode(pngBytes)}';
          } else {
            await imageNotifications.failed();
            final reason = localImage.lastFailureReason;
            rawResponse = reason != null
                ? '⏳ $reason'
                : '❌ ${'Local image generation failed.'.tr}';
          }
        } else {
          final inference = Get.find<InferenceService>();

          // LiteRT models can consume image/audio attachments. GGUF currently
          // returns a clear unsupported message from the inference layer.

          rawResponse = await inference.generate(
            prompt: promptText,
            systemPrompt: _effectiveSystemPrompt,
            conversationHistory: history,
            source: 'chat',
            imagePath: imagePath,
            audioPath: fileType == 'audio' ? filePath : null,
            stopSequences:
                Get.find<SettingsController>().stopSequences.toList(),
            onToken: tokens.add,
          );
        }
      } else {
        final cloud = Get.find<CloudService>();
        final apiMessages = [
          {'role': 'system', 'content': _effectiveSystemPrompt},
          ...history,
        ];
        rawResponse = await cloud.sendMessage(
          messages: apiMessages,
          imageBase64: imgBase64, // already encoded before clearImage()
          onToken: tokens.add,
        );
      }

      // Show the last tokens before the reply is read as finished.
      tokens.flush();
      if (identical(_tokenStream, tokens)) _tokenStream = null;

      if (thoughtStartedAt != null && thoughtDurationSeconds == null) {
        thoughtDurationSeconds =
            DateTime.now().difference(thoughtStartedAt!).inSeconds;
      }

      if (generationId != _generationSerial) return;

      // Stop streaming UI
      final tps = inferenceMode == 'local'
          ? Get.find<InferenceService>().tokensPerSecond.value
          : null;
      isStreaming.value = false;
      streamingAttachmentType.value = null;
      streamingResponse.value = '';
      imageGenStep.value = 0;
      imageGenTotal.value = 0;
      imageGenDecoding.value = false;

      // The sources, under an answer (not under an error).
      // (An agent may have found more on its own.)
      final footer = ChatTools.footer(
        web: found.web,
        passages: found.passages,
        webTitle: 'Sources',
        passagesTitle: 'Excerpts used'.tr,
      );
      if (footer.isNotEmpty &&
          !rawResponse.startsWith('ERROR') &&
          !rawResponse.startsWith('[IMAGE_BASE64]')) {
        rawResponse = '${rawResponse.trimRight()}$footer';
      }

      String? outImageBase64;
      if (rawResponse.startsWith('[IMAGE_BASE64]')) {
        outImageBase64 = rawResponse.substring('[IMAGE_BASE64]'.length);
        rawResponse = 'Here is your generated image:'.tr;
      }

      // Calculate total generation time for image gen
      final genDurationMs = imageGenStartTime.value != null
          ? DateTime.now().difference(imageGenStartTime.value!).inMilliseconds
          : null;

      // Display response directly (no command processing)
      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: currentSessionId.value,
        role: 'assistant',
        content: rawResponse,
        imageBase64: outImageBase64,
        tokensPerSec: tps,
        thoughtDurationSeconds: thoughtDurationSeconds,
        imageGenDurationMs: genDurationMs,
      );
      messages.add(aiMsg);
      _hive.saveMessage(aiMsg.id, aiMsg.toMap());
      imageGenStartTime.value = null;

      // Update session
      final session =
          sessions.firstWhereOrNull((s) => s.id == currentSessionId.value);
      if (session != null) {
        final updated = session.copyWith(lastMessage: aiMsg.content);
        _hive.saveSession(updated.id, updated.toMap());
        final idx = sessions.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) sessions[idx] = updated;
      }
    } catch (e) {
      if (generationId != _generationSerial) return;
      // Nothing may arrive on screen after the reply has failed.
      _tokenStream?.flush();
      _tokenStream = null;
      isStreaming.value = false;
      streamingAttachmentType.value = null;
      streamingResponse.value = '';
      imageGenStep.value = 0;
      imageGenTotal.value = 0;
      imageGenDecoding.value = false;
      if (imageGenStartTime.value != null) {
        await Get.find<ImageGenerationNotificationService>().failed();
      }
      imageGenStartTime.value = null;
      Get.find<AppLogService>().error('Chat response failed', details: e);
      final errorMsg = ChatMessage(
        id: _uuid.v4(),
        chatId: currentSessionId.value,
        role: 'assistant',
        content: '❌ ${'Error: @error'.trParams({'error': '$e'})}',
      );
      messages.add(errorMsg);
      _hive.saveMessage(errorMsg.id, errorMsg.toMap());
    }

    if (generationId == _generationSerial) {
      isLoading.value = false;
      _scrollToBottom();
    }
  }

  void stopGenerating() {
    if (!isLoading.value && !isStreaming.value) return;
    // The tokens still waiting are part of what was generated so far.
    _tokenStream?.flush();
    _tokenStream = null;
    final partialResponse = streamingResponse.value.trim();
    if (partialResponse.isNotEmpty) {
      final tps = Get.find<InferenceService>().tokensPerSecond.value;
      _saveAssistantMessage(
        content: partialResponse,
        tokensPerSec: tps > 0 ? tps : null,
      );
    }
    _generationSerial++;
    isLoading.value = false;
    isStreaming.value = false;
    streamingAttachmentType.value = null;
    streamingResponse.value = '';
    Get.find<ImageGenerationNotificationService>().cancel();
    imageGenStep.value = 0;
    imageGenTotal.value = 0;
    imageGenEstimatedSecs.value = 0;
    imageGenStartTime.value = null;
    imageGenDecoding.value = false;
    _batchCancelled = true;
    unawaited(Get.find<InferenceService>().stopGeneration());
    Get.find<LocalImageService>().cancelGeneration();
    Get.find<CloudService>().cancel();
  }

  void _saveAssistantMessage({
    required String content,
    String? imageBase64,
    double? tokensPerSec,
    int? thoughtDurationSeconds,
  }) {
    final aiMsg = ChatMessage(
      id: _uuid.v4(),
      chatId: currentSessionId.value,
      role: 'assistant',
      content: content,
      imageBase64: imageBase64,
      tokensPerSec: tokensPerSec,
      thoughtDurationSeconds: thoughtDurationSeconds,
    );
    messages.add(aiMsg);
    _hive.saveMessage(aiMsg.id, aiMsg.toMap());

    final session =
        sessions.firstWhereOrNull((s) => s.id == currentSessionId.value);
    if (session != null) {
      final updated = session.copyWith(lastMessage: aiMsg.content);
      _hive.saveSession(updated.id, updated.toMap());
      final idx = sessions.indexWhere((s) => s.id == updated.id);
      if (idx >= 0) sessions[idx] = updated;
    }
  }

  void _handleUserScroll() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (!isStreaming.value) {
      _followStreaming = distanceFromBottom <= 180;
    } else if (distanceFromBottom <= 48) {
      _followStreaming = true;
    }
  }

  void pauseStreamingFollow() {
    if (isStreaming.value) {
      _followStreaming = false;
    }
  }

  void resumeStreamingFollowIfNearBottom() {
    if (!scrollController.hasClients) return;
    final position = scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    if (distanceFromBottom <= 48) {
      _followStreaming = true;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!force && isStreaming.value && !_followStreaming) return;
    if (_scrollTimer?.isActive == true) return;

    _scrollTimer = Timer(const Duration(milliseconds: 80), () {
      if (!scrollController.hasClients) return;
      if (!force && isStreaming.value && !_followStreaming) return;
      final target = scrollController.position.maxScrollExtent;
      if ((target - scrollController.position.pixels).abs() < 8) return;
      scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String get _effectiveSystemPrompt {
    final settings = Get.find<SettingsController>();
    final inference = Get.find<InferenceService>();
    final modelName = settings.inferenceMode.value == 'local'
        ? inference.loadedModelName.value
        : settings.selectedCloudModelName;
    final base = settings.effectiveSystemPromptForModel(modelName);
    // What the user asked to be remembered, in every conversation.
    if (!Memories.enabled(_hive)) return base;
    final facts = Memories.forSystemPrompt(
      Memories.all(_hive),
      'What you know about the user (they asked you to remember it):'.tr,
    );
    return facts.isEmpty ? base : '$base\n\n$facts';
  }

  /// Looks up the user's documents and the web for [question], as switched
  /// on. A search that fails says why and leaves the question as it is.
  Future<({List<WebResult> web, List<DocChunk> passages})> _gatherContext(
      String question) async {
    var passages = <DocChunk>[];
    var web = <WebResult>[];
    try {
      if (useDocuments.value && Get.isRegistered<DocumentLibraryService>()) {
        activity.value = 'Searching your documents…'.tr;
        passages = Get.find<DocumentLibraryService>().library.search(question);
      }
      if (webSearch.value) {
        activity.value = 'Searching the web…'.tr;
        try {
          web = await (webSearchService ?? WebSearchService()).search(
            question,
            provider: WebSearchProvider.fromName(_hive
                .getSetting<String>(AppConstants.keyWebSearchProvider)),
            braveKey:
                _hive.getSetting<String>(AppConstants.keyBraveSearchKey) ?? '',
            searxngUrl:
                _hive.getSetting<String>(AppConstants.keySearxngUrl) ?? '',
            language: Get.locale?.languageCode == 'fr' ? 'fr' : 'en',
          );
          if (web.isEmpty) {
            showToast('Web search'.tr, 'Nothing found on the web for this.'.tr);
          }
        } on WebSearchException catch (e) {
          showToast('Web search unavailable'.tr, webSearchProblem(e.message),
              tone: ToastTone.warning, duration: const Duration(seconds: 6));
        }
      }
    } finally {
      activity.value = '';
    }
    return (web: web, passages: passages);
  }

  /// Chooses the assistant or team that answers next ('' for the plain
  /// assistant). An assistant tied to a model asks to load it.
  Future<void> chooseAgent(String id) async {
    final store = AgentStore(_hive);
    activeAgent.value = id;
    await store.setActive(id);
    final model = store.agent(id)?.model ?? '';
    if (model.isEmpty ||
        _hive.getSetting(AppConstants.keyInferenceMode, defaultValue: 'local') !=
            'local' ||
        Get.find<InferenceService>().loadedModelName.value == model ||
        !Get.isRegistered<ModelController>()) {
      return;
    }
    final models = Get.find<ModelController>();
    if (models.isDownloaded(model)) await models.loadModel(model);
  }

  /// Answers [question] with the assistant or team [id]. Returns the
  /// message to save (the steps folded in a thinking block, then the
  /// answer) and the toolbox, which holds the sources the tools found.
  Future<(String, AgentToolbox)> _runAgent(
    String id, {
    required String question,
    required List<Map<String, String>> history,
    required bool Function() isCurrent,
  }) async {
    final store = AgentStore(_hive);
    final toolbox = AgentToolbox(
      searchWeb: (query) => (webSearchService ?? WebSearchService()).search(
        query,
        provider: WebSearchProvider.fromName(
            _hive.getSetting<String>(AppConstants.keyWebSearchProvider)),
        braveKey: _hive.getSetting<String>(AppConstants.keyBraveSearchKey) ?? '',
        searxngUrl: _hive.getSetting<String>(AppConstants.keySearxngUrl) ?? '',
        language: Get.locale?.languageCode == 'fr' ? 'fr' : 'en',
      ),
      fetchPage: AgentToolbox.readWebPage,
      searchDocs: (query) => Get.isRegistered<DocumentLibraryService>()
          ? Get.find<DocumentLibraryService>().library.search(query)
          : const [],
    );
    // Each run gets its own conversation in engines that keep one.
    final runId = DateTime.now().microsecondsSinceEpoch;
    var member = 0;
    final local = (_hive.getSetting(AppConstants.keyInferenceMode,
            defaultValue: 'local') ??
        'local') == 'local';
    // A phone's context is small: fewer steps there.
    final maxSteps = local ? 4 : 6;
    AgentRunner runnerFor(AgentProfile a) => AgentRunner(
          llm: (messages, {onToken, stop = const []}) =>
              _agentLlm(messages, 'agent:$runId:$member',
                  onToken: onToken, stop: stop),
          tools: toolbox.tools(a.tools),
          maxSteps: maxSteps,
        );
    String withMemory(String instructions) {
      if (!Memories.enabled(_hive)) return instructions;
      final facts = Memories.forSystemPrompt(Memories.all(_hive),
          'What you know about the user (they asked you to remember it):'.tr);
      return facts.isEmpty ? instructions : '$instructions\n\n$facts';
    }

    final steps = <AgentStep>[];
    void show(String partial) => _showAgentWork(steps, partial, isCurrent);

    AgentRun run;
    final team = store.team(id);
    if (team != null) {
      final members = store.membersOf(team);
      run = await TeamRunner([
        for (final a in members)
          TeamMember(
              name: a.name,
              instructions: withMemory(a.instructions),
              runner: runnerFor(a)),
      ]).run(
        request: question,
        history: history,
        onMember: (name, index, count) {
          member = index;
          activity.value = '@name is working (@index of @count)…'.trParams(
              {'name': name, 'index': '${index + 1}', 'count': '$count'});
          show('');
        },
        onActivity: (a) => activity.value = a,
        onStep: (step) {
          steps.add(step);
          show('');
        },
        onPartial: show,
        cancelled: () => !isCurrent(),
      );
    } else {
      final agent = store.agent(id);
      if (agent == null) {
        activeAgent.value = AgentStore.none;
        await store.setActive(AgentStore.none);
        return ('ERROR: This assistant no longer exists.'.tr, toolbox);
      }
      activity.value = agent.usesTools
          ? '@name is working…'.trParams({'name': agent.name})
          : '';
      run = await runnerFor(agent).run(
        instructions: withMemory(agent.instructions),
        question: question,
        history: history,
        agentName: '',
        onActivity: (a) => activity.value = a,
        onStep: (step) {
          steps.add(step);
          show('');
        },
        onPartial: show,
        cancelled: () => !isCurrent(),
      );
    }
    activity.value = '';
    _agentDisplayTimer?.cancel();
    _agentDisplayTimer = null;
    if (run.answer.isEmpty) {
      return ("ERROR: The assistant didn't come to an answer.".tr, toolbox);
    }
    final work = agentStepsMarkdown(run.steps);
    return (
      work.isEmpty
          ? run.answer
          : '<think>\n$work\n</think>\n\n${run.answer}',
      toolbox,
    );
  }

  /// Asks the model in use (on this phone, or remote) for the next reply of
  /// an agent. [owner] keeps each run's conversation apart in engines that
  /// keep one.
  Future<String> _agentLlm(
    List<Map<String, String>> messages,
    String owner, {
    void Function(String token)? onToken,
    List<String> stop = const [],
  }) async {
    final local = (_hive.getSetting(AppConstants.keyInferenceMode,
            defaultValue: 'local') ??
        'local') == 'local';
    if (local) {
      final rest = messages.sublist(1);
      return Get.find<InferenceService>().generate(
        prompt: rest.isEmpty ? '' : rest.last['content'] ?? '',
        systemPrompt: messages.first['content'],
        conversationHistory: rest,
        source: owner,
        stopSequences: [
          ...Get.find<SettingsController>().stopSequences,
          ...stop,
        ],
        onToken: onToken,
      );
    }
    var reply = await Get.find<CloudService>()
        .sendMessage(messages: messages, onToken: onToken);
    // Remote models don't stop at our markers: cut there.
    for (final s in stop) {
      final at = reply.indexOf(s);
      if (at >= 0) reply = reply.substring(0, at + s.length);
    }
    return reply;
  }

  /// Shows an agent's steps so far, folded, and its answer as it comes; a
  /// few times a second at most, like tokens.
  void _showAgentWork(
      List<AgentStep> steps, String partial, bool Function() isCurrent) {
    final work = agentStepsMarkdown(steps);
    _agentDisplayPending = work.isEmpty
        ? partial
        : '<think>\n$work\n</think>\n\n$partial';
    if (_agentDisplayTimer != null) return;
    _agentDisplayTimer = Timer(const Duration(milliseconds: 80), () {
      _agentDisplayTimer = null;
      if (!isCurrent() || _agentDisplayPending == null) return;
      streamingResponse.value = _agentDisplayPending!;
      _scrollToBottom();
    });
  }

  /// The steps an agent or team took, as the user reads them.
  static String agentStepsMarkdown(List<AgentStep> steps) {
    if (steps.isEmpty) return '';
    String quote(String text) {
      final short = text.length > 600 ? '${text.substring(0, 600)}…' : text;
      return short.trim().split('\n').map((l) => '> $l').join('\n');
    }

    final lines = <String>[];
    var n = 0;
    for (final step in steps) {
      n++;
      final who = step.agent.isEmpty ? '' : '**${step.agent}** · ';
      if (step.label == step.agent && step.agent.isNotEmpty) {
        // A team member's contribution.
        lines.add('$n. **${step.agent}**\n${quote(step.result)}');
      } else {
        lines.add(
            '$n. $who${step.label}${step.failed ? ' ⚠️' : ''}');
      }
    }
    return lines.join('\n');
  }

  /// A web search failure, in words for the user.
  static String webSearchProblem(String code) => switch (code) {
        'busy' =>
          'The search engine turned the search away (too many requests). Try again in a moment, or choose another engine in Settings.'
              .tr,
        'refused' => 'The search engine refused the key. Check it in Settings.'.tr,
        'brave-key' => 'Add your Brave Search key in Settings.'.tr,
        'searxng-url' => 'Enter the address of your SearXNG server in Settings.'.tr,
        'searxng-json' =>
          'Your SearXNG server refuses JSON answers. Add "json" to its search formats.'
              .tr,
        _ => "Couldn't reach the search engine. Check your connection.".tr,
      };

  String _attachmentTypeForExtension(String extension) {
    const imageExtensions = {'png', 'jpg', 'jpeg', 'webp', 'gif', 'heic'};
    const audioExtensions = {'mp3', 'm4a', 'wav', 'aac', 'ogg', 'flac'};
    const textExtensions = {
      'txt',
      'md',
      'json',
      'csv',
      'log',
      'yaml',
      'yml',
      'xml',
      'dart',
      'kt',
      'java',
      'js',
      'ts',
      'py',
    };
    if (imageExtensions.contains(extension)) return 'image';
    if (audioExtensions.contains(extension)) return 'audio';
    if (extension == 'pdf') return 'pdf';
    if (extension == 'docx') return 'docx';
    if (textExtensions.contains(extension)) return 'text';
    return 'file';
  }

  String _defaultAttachmentPrompt(String? fileType) {
    switch (fileType) {
      case 'image':
        return 'Describe this image.'.tr;
      case 'pdf':
        return 'Summarize this PDF.'.tr;
      case 'docx':
        return 'Summarize this document.'.tr;
      case 'audio':
        return 'Transcribe or analyze this audio.'.tr;
      case 'text':
        return 'Review this file.'.tr;
      default:
        return 'Review this attachment.'.tr;
    }
  }
}
