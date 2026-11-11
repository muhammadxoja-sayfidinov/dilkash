import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class LocalDiscoveryService {
  LocalDiscoveryService._();

  static const int discoveryPort = 8089;
  static const int hubHttpPort = 8088;

  static Future<bool> probeHealth(
    String baseUrl, {
    http.Client? client,
    Duration timeout = const Duration(milliseconds: 1200),
  }) async {
    final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return false;
    final c = client ?? http.Client();
    final shouldClose = client == null;
    try {
      final res = await c.get(Uri.parse('$trimmed/health/')).timeout(timeout);
      if (res.statusCode != 200) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data is Map && data['service'] == 'dilkash-pos-hub';
    } catch (_) {
      return false;
    } finally {
      if (shouldClose) c.close();
    }
  }

  static Future<String?> discoverPosHub({
    String? savedUrl,
    http.Client? client,
    Duration timeout = const Duration(milliseconds: 1600),
  }) async {
    final candidates = <String>[];

    // 1. Check already-saved LAN POS URL first
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      if (await probeHealth(savedUrl, client: client)) {
        return savedUrl.trim().replaceAll(RegExp(r'/+$'), '');
      }
    }

    // 2. UDP broadcast discovery on port 8089 (no internet needed)
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final completer = Completer<void>();
      final sub = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final dg = socket!.receive();
          if (dg == null) return;
          try {
            final text = utf8.decode(dg.data);
            final json = jsonDecode(text);
            if (json is Map && json['service'] == 'dilkash-pos-hub') {
              final port = (json['port'] as num?)?.toInt() ?? hubHttpPort;
              candidates.add('http://${dg.address.address}:$port');
              final rawUrls = json['urls'];
              if (rawUrls is List) {
                for (final u in rawUrls) {
                  candidates.add(u.toString());
                }
              }
              if (!completer.isCompleted) completer.complete();
            }
          } catch (_) {}
        }
      });

      final msg = utf8.encode('DILKASH_DISCOVER');
      socket.send(msg, InternetAddress('255.255.255.255'), discoveryPort);
      await Future.any([
        completer.future,
        Future<void>.delayed(timeout),
      ]);
      await sub.cancel();
    } catch (_) {
      // Broadcast may be unavailable in restricted sandboxes / unit tests
    } finally {
      socket?.close();
    }

    // 3. Fallback quick local emulator/desktop probes if UDP returned nothing
    if (candidates.isEmpty) {
      candidates.addAll([
        'http://10.0.2.2:$hubHttpPort',
        'http://127.0.0.1:$hubHttpPort',
      ]);
    }

    for (final url in candidates.toSet()) {
      if (await probeHealth(url, client: client, timeout: const Duration(milliseconds: 900))) {
        return url.replaceAll(RegExp(r'/+$'), '');
      }
    }
    return null;
  }
}
