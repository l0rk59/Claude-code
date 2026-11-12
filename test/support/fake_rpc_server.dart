import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:privatelm/services/rpc_probe.dart';

/// A stand-in RPC server: answers HELLO, DEVICE_COUNT and GET_DEVICE_MEMORY
/// with the protocol's framing.
Future<ServerSocket> serveFakeRpc({
  int major = RpcProbe.protocolMajor,
  int minor = 0,
  List<RpcDeviceMemory> devices = const [],
  bool silent = false,
  List<int>? garbage,
}) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((client) {
    final pending = <int>[];
    void reply(List<int> payload) {
      final size = ByteData(8)..setUint64(0, payload.length, Endian.little);
      client.add([...size.buffer.asUint8List(), ...payload]);
    }

    client.listen((chunk) {
      if (silent) return;
      if (garbage != null) {
        client.add(garbage);
        return;
      }
      pending.addAll(chunk);
      while (pending.length >= 9) {
        final command = pending[0];
        final size = ByteData.sublistView(Uint8List.fromList(pending), 1, 9)
            .getUint64(0, Endian.little);
        if (pending.length < 9 + size) return;
        final payload = Uint8List.fromList(pending.sublist(9, 9 + size));
        pending.removeRange(0, 9 + size);
        if (command == RpcProbe.cmdHello) {
          expect(size, RpcProbe.capsSize);
          reply([major, minor, 3, 0, ...List.filled(RpcProbe.capsSize, 0)]);
        } else if (command == RpcProbe.cmdDeviceCount) {
          reply((ByteData(4)..setUint32(0, devices.length, Endian.little))
              .buffer
              .asUint8List());
        } else if (command == RpcProbe.cmdGetDeviceMemory) {
          final d = devices[ByteData.sublistView(payload)
              .getUint32(0, Endian.little)];
          reply((ByteData(16)
                ..setUint64(0, d.free, Endian.little)
                ..setUint64(8, d.total, Endian.little))
              .buffer
              .asUint8List());
        }
      }
    }, onError: (_) {});
  });
  return server;
}
