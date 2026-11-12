import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A computer on the local network that runs a model and answers the
/// OpenAI-compatible API: llama.cpp's llama-server, Ollama, LM Studio…
class LanServer {
  final String host;
  final int port;

  /// "llama.cpp", "Ollama", "LM Studio", or '' when it can't be told.
  final String software;

  /// The models it offers, as it names them.
  final List<String> models;

  const LanServer({
    required this.host,
    required this.port,
    this.software = '',
    this.models = const [],
  });

  String get address => '$host:$port';

  /// What the app's custom provider takes as its base URL.
  String get baseUrl => 'http://$host:$port/v1';
}

/// Finds computers running a model on the phone's own network, so the phone
/// can chat with a model far bigger than it could hold: the computer does
/// the work, nothing leaves the network.
class LanServerFinder {
  /// The ports these programs listen on unless told otherwise.
  static const knownPorts = <int, String>{
    8080: 'llama.cpp',
    11434: 'Ollama',
    1234: 'LM Studio',
  };

  /// Asks [host]:[port] which models it serves. Null when nothing there
  /// answers the OpenAI-compatible API (or it wants a key).
  static Future<LanServer?> probe(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client
          .getUrl(Uri(scheme: 'http', host: host, port: port, path: '/v1/models'))
          .timeout(timeout);
      final response = await request.close().timeout(timeout);
      if (response.statusCode != 200) {
        await response.drain<void>().timeout(timeout);
        return null;
      }
      final body =
          await response.transform(utf8.decoder).join().timeout(timeout);
      return parse(host, port, body);
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Whether [url] points at the local network (or this device) rather
  /// than at the Internet: what is said to such a server stays at home.
  static bool isLocal(String url) {
    final host = Uri.tryParse(url.trim())?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;
    if (host == 'localhost' || host.endsWith('.local')) return true;
    // Only a real address counts: "192.168.example.com" is a name anyone
    // can register.
    final address = InternetAddress.tryParse(host);
    if (address == null || address.type != InternetAddressType.IPv4) {
      return false;
    }
    final n = address.rawAddress;
    return n[0] == 127 ||
        n[0] == 10 ||
        (n[0] == 192 && n[1] == 168) ||
        (n[0] == 172 && n[1] >= 16 && n[1] <= 31);
  }

  /// Reads a `/v1/models` answer. Null when it isn't one.
  static LanServer? parse(String host, int port, String body) {
    Object? data;
    try {
      data = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (data is! Map || data['data'] is! List) return null;
    final entries = (data['data'] as List).whereType<Map>().toList();
    final models = [
      for (final entry in entries)
        if (entry['id'] case final String id when id.isNotEmpty) id,
    ];
    // Each program signs its models differently.
    final owner = entries.isEmpty ? '' : '${entries.first['owned_by'] ?? ''}';
    final software = switch (owner) {
      'llamacpp' => 'llama.cpp',
      'library' => 'Ollama',
      'organization_owner' => 'LM Studio',
      _ => knownPorts[port] ?? '',
    };
    return LanServer(host: host, port: port, software: software, models: models);
  }

  /// Tries what the user typed: "192.168.1.20" (the usual ports are tried)
  /// or "192.168.1.20:8080".
  static Future<List<LanServer>> find(String input) async {
    var text = input.trim();
    text = text.replaceFirst(RegExp(r'^https?://', caseSensitive: false), '');
    text = text.replaceFirst(RegExp(r'/.*$'), '');
    if (text.isEmpty || text.contains(' ')) return const [];
    final colon = text.lastIndexOf(':');
    if (colon > 0) {
      final port = int.tryParse(text.substring(colon + 1));
      if (port == null || port <= 0 || port > 65535) return const [];
      final server = await probe(text.substring(0, colon), port);
      return [if (server != null) server];
    }
    final found = await Future.wait(
        [for (final port in knownPorts.keys) probe(text, port)]);
    return found.whereType<LanServer>().toList();
  }

  /// The other addresses of the network [ownAddress] is on, assuming the
  /// usual home network where the first three numbers are shared.
  static List<String> neighbours(String ownAddress) {
    final parts = ownAddress.trim().split('.');
    if (parts.length != 4 || parts.any((p) => int.tryParse(p) == null)) {
      return const [];
    }
    final prefix = parts.take(3).join('.');
    final own = int.parse(parts[3]);
    return [
      for (var last = 1; last <= 254; last++)
        if (last != own) '$prefix.$last',
    ];
  }

  /// This phone's address on the Wi-Fi, or null when it has none.
  static Future<String?> ownAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      bool private(String a) =>
          a.startsWith('192.168.') ||
          a.startsWith('10.') ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(a);
      // Wi-Fi first: mobile data also has an address, but no neighbours.
      interfaces.sort((a, b) =>
          (b.name.startsWith('wlan') ? 1 : 0) -
          (a.name.startsWith('wlan') ? 1 : 0));
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (private(address.address)) return address.address;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Looks for servers on [hosts], on the usual [ports]. A quick connection
  /// attempt sorts out the addresses where nothing listens; the others are
  /// asked for their models. [onProgress] gets a value from 0 to 1.
  static Future<List<LanServer>> scan(
    Iterable<String> hosts, {
    Iterable<int>? ports,
    int parallel = 64,
    Duration connectTimeout = const Duration(milliseconds: 400),
    void Function(double progress)? onProgress,
    bool Function()? cancelled,
  }) async {
    final targets = [
      for (final host in hosts)
        for (final port in ports ?? knownPorts.keys) (host: host, port: port),
    ];
    final found = <LanServer>[];
    var next = 0;
    var done = 0;

    Future<void> worker() async {
      while (next < targets.length) {
        if (cancelled?.call() ?? false) return;
        final target = targets[next++];
        try {
          final socket = await Socket.connect(target.host, target.port,
              timeout: connectTimeout);
          socket.destroy();
          final server = await probe(target.host, target.port);
          if (server != null) found.add(server);
        } catch (_) {
          // Nothing listens there.
        }
        done++;
        onProgress?.call(done / targets.length);
      }
    }

    await Future.wait([for (var i = 0; i < parallel; i++) worker()]);
    found.sort((a, b) => a.address.compareTo(b.address));
    return found;
  }
}
