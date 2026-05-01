import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de licencia. Comprueba si la app está activada y valida la clave.
/// No modifica el resto de la app; solo se consulta al inicio.
class LicenseService {
  static const String _keyActivated = 'license_activated';
  static const String _keyLicense = 'license_key';
  static const String _keyMachineId = 'license_machine_id';
  static const String _keyDemoStart = 'demo_start_date';
  static const String _keyDemoDurationDays = 'demo_duration_days';
  static const String _keyDemoUsedOnce = 'demo_used_once';
  static const String _keyDemoLastSeenDate = 'demo_last_seen_date';
  static const String _keyDemoClockTampered = 'demo_clock_tampered';
  static const int _defaultDemoDurationDays = 5;
  /// ID especial: clave generada para "DEMO" vale en cualquier equipo (para muestras en local).
  static const String _demoMachineId = 'DEMO';

  /// Claves aceptadas explícitamente por ID (por si la fórmula difiere en builds). Añadir aquí cuando el keygen no coincida.
  static const Map<String, String> _acceptedKeysByMachineId = {
    'D942C0B60F8170DA': 'D942C0B60F8170DA-PPjWIAFT3_RBsgWxn9_D',
  };

  // Misma fórmula que el keygen (programa aparte). No distribuir el keygen.
  static String _getSecret() {
    const a = 'Smart';
    const b = 'Seller';
    const c = 'Lic';
    const d = '2025';
    return '$a${b}_${c}_$d';
  }

  /// Genera un ID de máquina para atar la licencia a este PC (Windows) o dispositivo (Android).
  static Future<String> getMachineId() async {
    try {
      if (Platform.isAndroid) {
        final hostname = Platform.localHostname;
        final raw = 'ANDROID-$hostname'.trim();
        final bytes = utf8.encode(raw);
        final digest = sha256.convert(bytes);
        return digest.toString().substring(0, 16).toUpperCase();
      }
      final hostname = Platform.localHostname;
      final user = Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? '';
      final raw = '$hostname|$user'.trim();
      final bytes = utf8.encode(raw);
      final digest = sha256.convert(bytes);
      return digest.toString().substring(0, 16).toUpperCase();
    } catch (_) {
      return Platform.isAndroid ? 'ANDROID-XXXX' : 'DESKTOP-XXXX';
    }
  }

  /// Genera la clave esperada para esta máquina (solo para validar).
  static Future<String> _generateKeyForMachine(String machineId) async {
    return generateKeyForMachineId(machineId);
  }

  /// Genera la clave para un ID de máquina (para keygen; no distribuir).
  static String generateKeyForMachineId(String machineId) {
    final id = machineId.trim().toUpperCase().replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final secret = _getSecret();
    final input = utf8.encode('$id$secret');
    final h = sha256.convert(input);
    final b64 = base64UrlEncode(h.bytes).replaceAll('=', '').substring(0, 20);
    return '$id-$b64';
  }

  /// Indica si la app está activada en este equipo.
  static Future<bool> isActivated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activated = prefs.getBool(_keyActivated);
      if (activated != true) return false;
      final savedKey = prefs.getString(_keyLicense);
      final savedMachineId = prefs.getString(_keyMachineId);
      if (savedKey == null || savedMachineId == null) return false;
      // Licencia demo: válida en cualquier equipo (para muestras en local).
      if (savedMachineId == _demoMachineId) {
        // Si la demo es de una version vieja sin fecha de inicio, se considera invalida.
        if (!prefs.containsKey(_keyDemoStart)) return false;
        final expectedDemoKey = await _generateKeyForMachine(_demoMachineId);
        if (savedKey != expectedDemoKey) return false;
        if (await _isClockTamperedForDemo()) return false;
        return !(await isDemoExpired());
      }
      final currentMachineId = await getMachineId();
      if (savedMachineId != currentMachineId) return false;
      final expectedKey = await _generateKeyForMachine(currentMachineId);
      return savedKey == expectedKey;
    } catch (_) {
      return false;
    }
  }

  /// Indica si la licencia actual es de tipo demo (muestras en local).
  static Future<bool> isDemoLicense() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMachineId = prefs.getString(_keyMachineId);
      return savedMachineId == _demoMachineId;
    } catch (_) {
      return false;
    }
  }

  /// Indica si ya se inició una demo en este equipo.
  static Future<bool> hasStartedDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_keyDemoStart);
    } catch (_) {
      return false;
    }
  }

  /// Indica si este equipo ya consumio su demo al menos una vez.
  static Future<bool> hasUsedDemoOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyDemoUsedOnce) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Detecta si el reloj del sistema fue atrasado durante la demo.
  static Future<bool> _isClockTamperedForDemo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyTampered = prefs.getBool(_keyDemoClockTampered) ?? false;
      if (alreadyTampered) return true;

      if (!prefs.containsKey(_keyDemoStart)) return false;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final lastSeenRaw = prefs.getString(_keyDemoLastSeenDate);

      if (lastSeenRaw != null && lastSeenRaw.isNotEmpty) {
        final lastSeen = DateTime.tryParse(lastSeenRaw);
        if (lastSeen != null) {
          final lastDate = DateTime(lastSeen.year, lastSeen.month, lastSeen.day);
          if (today.isBefore(lastDate)) {
            await prefs.setBool(_keyDemoClockTampered, true);
            return true;
          }
        }
      }

      await prefs.setString(_keyDemoLastSeenDate, today.toIso8601String());
      return false;
    } catch (_) {
      return false;
    }
  }

  /// True cuando se detecto manipulacion de reloj en demo.
  static Future<bool> isDemoBlockedByClockTampering() async {
    return _isClockTamperedForDemo();
  }

  /// Fecha de vencimiento de demo (si existe).
  static Future<DateTime?> getDemoExpirationDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startRaw = prefs.getString(_keyDemoStart);
      if (startRaw == null || startRaw.isEmpty) return null;
      final startDate = DateTime.tryParse(startRaw);
      if (startDate == null) return null;
      final duration = prefs.getInt(_keyDemoDurationDays) ?? _defaultDemoDurationDays;
      return startDate.add(Duration(days: duration));
    } catch (_) {
      return null;
    }
  }

  /// Días restantes de demo. Retorna 0 si ya expiró.
  static Future<int> getDemoDaysLeft() async {
    final expiration = await getDemoExpirationDate();
    if (expiration == null) return 0;
    final now = DateTime.now();
    final nowDate = DateTime(now.year, now.month, now.day);
    final expDate = DateTime(expiration.year, expiration.month, expiration.day);
    final diff = expDate.difference(nowDate).inDays;
    return diff <= 0 ? 0 : diff;
  }

  /// True cuando el periodo demo ya terminó.
  static Future<bool> isDemoExpired() async {
    final started = await hasStartedDemo();
    if (!started) return false;
    final left = await getDemoDaysLeft();
    return left <= 0;
  }

  /// Activa como DEMO sin pedir clave (para que el cliente pueda usar ya).
  static Future<bool> activateAsDemo({int durationDays = _defaultDemoDurationDays}) async {
    try {
      final expectedDemoKey = await _generateKeyForMachine(_demoMachineId);
      final prefs = await SharedPreferences.getInstance();
      final alreadyUsedDemo = prefs.getBool(_keyDemoUsedOnce) ?? false;
      if (alreadyUsedDemo) return false;
      final safeDuration = durationDays <= 0 ? _defaultDemoDurationDays : durationDays;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyLicense, expectedDemoKey);
      await prefs.setString(_keyMachineId, _demoMachineId);
      await prefs.setString(_keyDemoStart, now.toIso8601String());
      await prefs.setInt(_keyDemoDurationDays, safeDuration);
      await prefs.setBool(_keyDemoUsedOnce, true);
      await prefs.setString(_keyDemoLastSeenDate, today.toIso8601String());
      await prefs.setBool(_keyDemoClockTampered, false);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Borra la licencia guardada (para poder ingresar otra clave).
  static Future<void> clearStoredLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyActivated);
    await prefs.remove(_keyLicense);
    await prefs.remove(_keyMachineId);
    await prefs.remove(_keyDemoStart);
    await prefs.remove(_keyDemoDurationDays);
    // No se borra _keyDemoUsedOnce: la demo debe ser de un solo uso por equipo.
    await prefs.remove(_keyDemoLastSeenDate);
    await prefs.remove(_keyDemoClockTampered);
  }

  /// Normaliza la clave pegada: quita espacios y caracteres raros (mantiene guión y guión bajo, base64url).
  static String _normalizeEnteredKey(String key) {
    final onlyValid = key.replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '').trim();
    return onlyValid.toUpperCase();
  }

  /// Valida la clave ingresada y, si es correcta, guarda la activación.
  /// Acepta clave de equipo (solo este PC) o clave demo (válida en cualquier PC).
  static Future<bool> validateAndSave(String enteredKey) async {
    try {
      final normalized = _normalizeEnteredKey(enteredKey);
      if (normalized.isEmpty) return false;
      final prefs = await SharedPreferences.getInstance();

      // Comprobar si es la clave DEMO (para muestras en local; vale en cualquier equipo).
      final expectedDemoKey = await _generateKeyForMachine(_demoMachineId);
      if (normalized == _normalizeEnteredKey(expectedDemoKey)) {
        final alreadyUsedDemo = prefs.getBool(_keyDemoUsedOnce) ?? false;
        final machineId = prefs.getString(_keyMachineId);
        final alreadyActiveDemo = machineId == _demoMachineId && prefs.containsKey(_keyDemoStart);
        if (alreadyUsedDemo && !alreadyActiveDemo) return false;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        await prefs.setBool(_keyActivated, true);
        await prefs.setString(_keyLicense, expectedDemoKey);
        await prefs.setString(_keyMachineId, _demoMachineId);
        if (!prefs.containsKey(_keyDemoStart)) {
          await prefs.setString(_keyDemoStart, now.toIso8601String());
          await prefs.setInt(_keyDemoDurationDays, _defaultDemoDurationDays);
          await prefs.setBool(_keyDemoUsedOnce, true);
          await prefs.setString(_keyDemoLastSeenDate, today.toIso8601String());
          await prefs.setBool(_keyDemoClockTampered, false);
        }
        return true;
      }

      // Clave atada a este equipo.
      final machineId = await getMachineId();
      // Comprobar primero si hay una clave aceptada explícita para este ID.
      final acceptedForThisId = _acceptedKeysByMachineId[machineId];
      if (acceptedForThisId != null && normalized == _normalizeEnteredKey(acceptedForThisId)) {
        await prefs.setBool(_keyActivated, true);
        await prefs.setString(_keyLicense, acceptedForThisId);
        await prefs.setString(_keyMachineId, machineId);
        return true;
      }
      // Validación por fórmula (con o sin guiones bajos).
      final expectedKey = await _generateKeyForMachine(machineId);
      final expectedNormalized = _normalizeEnteredKey(expectedKey);
      final normNoUnderscore = normalized.replaceAll('_', '');
      final expectedNoUnderscore = expectedNormalized.replaceAll('_', '');
      if (normalized != expectedNormalized && normNoUnderscore != expectedNoUnderscore) return false;
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyLicense, expectedKey);
      await prefs.setString(_keyMachineId, machineId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
