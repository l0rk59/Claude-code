/// Sampling settings recommended by each model family's authors, for the
/// llama.cpp engine. The temperature stays the user's setting.
class SamplingPreset {
  final double topP;
  final int topK;
  final double minP;
  final double repeatPenalty;
  final double presencePenalty;

  const SamplingPreset({
    required this.topP,
    required this.topK,
    required this.minP,
    required this.repeatPenalty,
    this.presencePenalty = 0.0,
  });

  /// What the app used for every model before presets.
  static const general =
      SamplingPreset(topP: 0.9, topK: 40, minP: 0.05, repeatPenalty: 1.1);

  /// Qwen 3.5 model card (non-thinking, with images): top_p 0.8, top_k 20,
  /// presence penalty 1.5, no repetition penalty.
  static const qwen35 = SamplingPreset(
      topP: 0.8, topK: 20, minP: 0.0, repeatPenalty: 1.0, presencePenalty: 1.5);

  /// Gemma 4 model card: top_p 0.95, top_k 64.
  static const gemma =
      SamplingPreset(topP: 0.95, topK: 64, minP: 0.0, repeatPenalty: 1.0);

  /// Liquid LFM2.5 model card: top_k 50, repetition penalty 1.05.
  static const liquid =
      SamplingPreset(topP: 1.0, topK: 50, minP: 0.0, repeatPenalty: 1.05);

  /// The preset for a model, from its file or display name.
  static SamplingPreset forModel(String name) {
    final lower = name.toLowerCase();
    if (RegExp(r'qwen[\s_-]?3[._]5').hasMatch(lower)) return qwen35;
    if (lower.contains('gemma-4') ||
        lower.contains('gemma4') ||
        lower.contains('gemma-3') ||
        lower.contains('gemma3')) {
      return gemma;
    }
    if (lower.contains('lfm2') || lower.contains('lfm3')) return liquid;
    return general;
  }
}
