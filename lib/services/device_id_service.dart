import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provides a stable per-installation device identifier.
///
/// This is used for PRO "active device" binding. It must NOT use Supabase access
/// tokens because those rotate/expire and would incorrectly look like a new
/// device after inactivity.
class DeviceIdService {
  static const _storage = FlutterSecureStorage();
  static const _key = 'device_id_v1';

  Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final generated = _generateUuidV4();
    await _storage.write(key: _key, value: generated);
    return generated;
  }

  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));

    // Set version to 4
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    // Set variant to RFC 4122
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String two(int n) => n.toRadixString(16).padLeft(2, '0');
    final b = bytes.map(two).toList();

    return '${b[0]}${b[1]}${b[2]}${b[3]}-'
        '${b[4]}${b[5]}-'
        '${b[6]}${b[7]}-'
        '${b[8]}${b[9]}-'
        '${b[10]}${b[11]}${b[12]}${b[13]}${b[14]}${b[15]}';
  }
}









