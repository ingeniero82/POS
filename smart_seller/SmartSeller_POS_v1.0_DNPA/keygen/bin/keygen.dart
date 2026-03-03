import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Generador de claves de activación. Uso interno únicamente.
///   dart run keygen              → pide el ID por teclado (recomendado).
///   dart run keygen <ID>         → clave para ese equipo.
///   dart run keygen --demo       → clave DEMO (cualquier PC).
void main(List<String> args) async {
  String machineId = '';
  if (args.isNotEmpty) {
    final arg = args.first.trim();
    if (arg == '--demo' || arg == '-d') {
      machineId = 'DEMO';
    } else {
      machineId = _normalizeMachineId(arg);
    }
  }
  if (machineId.isEmpty) {
    print('Pegue el ID del equipo (los 16 caracteres de la pantalla de activación) y Enter:');
    final line = stdin.readLineSync();
    machineId = _normalizeMachineId(line ?? '');
    if (machineId.isEmpty) {
      print('ID vacío. Vuelva a ejecutar y pegue el ID cuando se le pida.');
      exit(1);
    }
    print('');
  }
  final key = _generateKey(machineId);
  if (machineId == 'DEMO') {
    print('Clave DEMO (vale en cualquier equipo):');
    print('');
    print(key);
    print('');
    print('>>> COPIE LA LINEA COMPLETA DE ARRIBA (debe empezar por DEMO-)');
  } else {
    print('Clave para este equipo (ID $machineId):');
    print('');
    print(key);
    print('');
    print('>>> COPIE LA LINEA COMPLETA DE ARRIBA y péguela en la app del cliente.');
  }
}

/// Deja solo 16 caracteres hex mayúsculas (como los genera la app).
String _normalizeMachineId(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final hex = raw.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();
  if (hex.isEmpty) return '';
  return hex.length >= 16 ? hex.substring(0, 16) : hex.padRight(16, '0').substring(0, 16);
}

String _getSecret() {
  const a = 'Smart';
  const b = 'Seller';
  const c = 'Lic';
  const d = '2025';
  return '$a${b}_${c}_$d';
}

String _generateKey(String machineId) {
  final secret = _getSecret();
  final input = utf8.encode('$machineId$secret');
  final h = sha256.convert(input);
  final b64 = base64UrlEncode(h.bytes).replaceAll('=', '').substring(0, 20);
  return '$machineId-$b64';
}
