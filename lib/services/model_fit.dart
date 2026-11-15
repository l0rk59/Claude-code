/// How well a model suits a phone, from the model's size and the phone's
/// total memory.
enum ModelFit {
  /// Comfortable: room left for long chats.
  ideal,

  /// Loads, but with little room: can be slow, or fail when other apps hold
  /// memory.
  tight,

  /// Needs more memory than the phone can give one app.
  tooBig,

  /// Size or memory unknown.
  unknown,
}

const _gb = 1024 * 1024 * 1024;

/// Memory a loaded model takes: its weights, plus the context cache and the
/// runtime's working buffers.
int modelMemoryBytes(int modelBytes) =>
    (modelBytes * 1.15).round() + (0.6 * _gb).round();

/// What one app can realistically hold: the system and other apps keep the
/// rest (about 4.5 GB of an 8 GB phone).
int usableMemoryBytes(double totalRamGb) => (totalRamGb * 0.57 * _gb).round();

/// The fit of a model file of [modelBytes] on a phone with [totalRamGb].
ModelFit modelFit({required int modelBytes, required double totalRamGb}) {
  if (modelBytes <= 0 || totalRamGb <= 0) return ModelFit.unknown;
  final needed = modelMemoryBytes(modelBytes);
  final usable = usableMemoryBytes(totalRamGb);
  if (needed > usable) return ModelFit.tooBig;
  return needed <= usable * 0.75 ? ModelFit.ideal : ModelFit.tight;
}

/// The largest model file (bytes) that is still [ModelFit.ideal] on a phone
/// with [totalRamGb].
int idealModelBytes(double totalRamGb) =>
    ((usableMemoryBytes(totalRamGb) * 0.75 - 0.6 * _gb) / 1.15)
        .floor()
        .clamp(0, 1 << 62);

/// What a computer can give a model, as the memory of a phone that could
/// give the same (so the rules above apply): most of its memory, plus the
/// memory of a separate graphics card ([vramGb], 0 without one).
double computerEquivalentRamGb(double ramGb, {double vramGb = 0}) =>
    (0.75 * ramGb + 0.9 * vramGb) / 0.57;

/// Whether a graphics card has memory of its own (not shared with the
/// processor, which the computer's memory already counts).
bool isDiscreteGpu(String name) => RegExp(
        r'NVIDIA|GeForce|RTX|Quadro|Tesla|Radeon RX|Radeon Pro|Radeon VII|Arc A|Arc B|Instinct',
        caseSensitive: false)
    .hasMatch(name);
