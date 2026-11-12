import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Free and total memory of one device a llama.cpp RPC server serves, in
/// bytes.
typedef RpcDeviceMemory = ({int free, int total});

/// What a llama.cpp RPC server says about itself: the `ggml-rpc-server` program
/// on a computer, or the worker inside PrivateLM on a phone.
class RpcServerInfo {
  final int major;
  final int minor;
  final int patch;

  /// One entry per device the server offers (its processor, or each of its
  /// graphics cards). Empty when the server speaks another version: its
  /// other answers can't be trusted then.
  final List<RpcDeviceMemory> devices;

  const RpcServerInfo({
    required this.major,
    required this.minor,
    required this.patch,
    this.devices = const [],
  });

  String get version => '$major.$minor.$patch';

  /// Whether this app's engine can use the server. llama.cpp accepts the
  /// same major version and a minor version it knows.
  bool get compatible =>
      major == RpcProbe.protocolMajor && minor <= RpcProbe.protocolMinor;

  int get totalMb =>
      devices.fold<int>(0, (sum, d) => sum + d.total) ~/ (1024 * 1024);

  /// Memory to suggest handing to the cluster, in MB.
  ///
  /// A processor on Linux or macOS reports all of its memory as free (the
  /// engine doesn't measure it there), so only 60% of it is counted, to
  /// leave room for the system. A measured figure (Windows, or a graphics
  /// card) is trusted at 85%.
  int get suggestedMb {
    var bytes = 0.0;
    for (final d in devices) {
      bytes += d.free >= d.total ? d.total * 0.6 : d.free * 0.85;
    }
    return bytes ~/ (1024 * 1024);
  }
}

/// Asks a llama.cpp RPC server for its version and memory, speaking just
/// enough of ggml's RPC protocol:
///
///     request:  command (1 byte) | size (8 bytes) | payload
///     response: size (8 bytes) | payload
///
/// with little-endian integers. A test checks the numbers below against the
/// engine's source, so an engine update can't silently break this.
class RpcProbe {
  static const protocolMajor = 7;
  static const protocolMinor = 0;

  /// Size of the transport capabilities exchanged in HELLO. Sending zeros
  /// keeps the connection on plain TCP.
  static const capsSize = 24;

  static const cmdGetDeviceMemory = 11;
  static const cmdHello = 14;
  static const cmdDeviceCount = 15;

  /// No server offers more devices than this; a bigger count means the
  /// answer isn't from a llama.cpp RPC server.
  static const _maxDevices = 16;

  /// Connects to [host]:[port] and asks what it is. Throws a
  /// [SocketException] when nothing answers there, a [TimeoutException]
  /// when it accepts the connection but stays silent (a worker already busy
  /// with another master does that), and a [FormatException] when it
  /// answers something else than the RPC protocol.
  static Future<RpcServerInfo> query(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
      return await _ask(socket).timeout(timeout);
    } finally {
      socket.destroy();
    }
  }

  static Future<RpcServerInfo> _ask(Socket socket) async {
    final replies = _Replies(socket);
    try {
      // HELLO must come first: version, then transport capabilities.
      socket.add(_request(cmdHello, Uint8List(capsSize)));
      final hello = await replies.next(4 + capsSize);
      final info =
          RpcServerInfo(major: hello[0], minor: hello[1], patch: hello[2]);
      if (!info.compatible) return info;

      socket.add(_request(cmdDeviceCount, Uint8List(0)));
      final count = ByteData.sublistView(await replies.next(4))
          .getUint32(0, Endian.little);
      if (count > _maxDevices) {
        throw FormatException('Unexpected device count: $count');
      }

      final devices = <RpcDeviceMemory>[];
      for (var device = 0; device < count; device++) {
        final which = ByteData(4)..setUint32(0, device, Endian.little);
        socket.add(_request(cmdGetDeviceMemory, which.buffer.asUint8List()));
        final memory = ByteData.sublistView(await replies.next(16));
        devices.add((
          free: memory.getUint64(0, Endian.little),
          total: memory.getUint64(8, Endian.little),
        ));
      }
      return RpcServerInfo(
        major: info.major,
        minor: info.minor,
        patch: info.patch,
        devices: devices,
      );
    } finally {
      await replies.cancel();
    }
  }

  static Uint8List _request(int command, Uint8List payload) {
    final message = Uint8List(1 + 8 + payload.length);
    message[0] = command;
    ByteData.sublistView(message).setUint64(1, payload.length, Endian.little);
    message.setRange(9, message.length, payload);
    return message;
  }
}

/// Reads the server's replies off the socket, one framed message at a time.
class _Replies {
  final StreamIterator<Uint8List> _chunks;
  final _pending = <int>[];

  _Replies(Socket socket) : _chunks = StreamIterator(socket);

  /// The payload of the next reply, which must be [size] bytes long.
  Future<Uint8List> next(int size) async {
    final announced =
        ByteData.sublistView(await _take(8)).getUint64(0, Endian.little);
    if (announced != size) {
      throw FormatException('Expected a $size-byte reply, got $announced');
    }
    return _take(size);
  }

  Future<Uint8List> _take(int count) async {
    while (_pending.length < count) {
      if (!await _chunks.moveNext()) {
        throw const FormatException('The server closed the connection');
      }
      _pending.addAll(_chunks.current);
    }
    final bytes = Uint8List.fromList(_pending.sublist(0, count));
    _pending.removeRange(0, count);
    return bytes;
  }

  Future<void> cancel() => _chunks.cancel();
}
