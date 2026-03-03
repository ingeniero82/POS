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
  /// ID especial: clave generada para "DEMO" vale en cualquier equipo (para muestras en local).
  static const String _demoMachineId = 'DEMO';

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
        final raw = 'ANDROID-${hostname ?? 'device'}'.trim();
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
    final secret = _getSecret();
    final input = utf8.encode('$machineId$secret');
    final h = sha256.convert(input);
    final b64 = base64UrlEncode(h.bytes).replaceAll('=', '').substring(0, 20);
    return '$machineId-$b64';
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
        final expectedDemoKey = await _generateKeyForMachine(_demoMachineId);
        return savedKey == expectedDemoKey;
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

  /// Activa como DEMO sin pedir clave (para que el cliente pueda usar ya).
  static Future<bool> activateAsDemo() async {
    try {
      final expectedDemoKey = await _generateKeyForMachine(_demoMachineId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyLicense, expectedDemoKey);
      await prefs.setString(_keyMachineId, _demoMachineId);
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
  }

  /// Normaliza la clave pegada: quita espacios y caracteres raros que impiden que coincida.
  static String _normalizeEnteredKey(String key) {
    final onlyValid = key.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '').trim();
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
      if (normalized == expectedDemoKey.toUpperCase()) {
        await prefs.setBool(_keyActivated, true);
        await prefs.setString(_keyLicense, expectedDemoKey);
        await prefs.setString(_keyMachineId, _demoMachineId);
        return true;
      }

      // Clave atada a este equipo.
      final machineId = await getMachineId();
      final expectedKey = await _generateKeyForMachine(machineId);
      if (normalized != expectedKey.toUpperCase()) return false;
      await prefs.setBool(_keyActivated, true);
      await prefs.setString(_keyLicense, expectedKey);
      await prefs.setString(_keyMachineId, machineId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
