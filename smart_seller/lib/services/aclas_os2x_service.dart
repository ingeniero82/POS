import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class AclasOS2XService {
  Process? _process;
  Timer? _weightTimer;
  final StreamController<double> _weightController = StreamController<double>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  
  // Streams para la UI
  Stream<double> get weightStream => _weightController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  
  // Estado actual
  bool _isConnected = false;
  double _currentWeight = 0.0;
  
  bool get isConnected => _isConnected;
  double get currentWeight => _currentWeight;
  
  // Configuración específica para Aclas OS2X
  static const String _targetPort = 'COM3';
  static const int _baudRate = 9600;
  static const int _dataBits = 8;
  
  // Comando para solicitar peso
  static const String _weightCommand = 'W\r\n';
  
  /// Conectar a la balanza Aclas OS2X en COM3
  Future<bool> connect() async {
    try {
      print('🔌 Conectando a balanza Aclas OS2X...');
      
      // ✅ NUEVO: Usar PowerShell para comunicación más confiable
      final result = await _testConnectionWithPowerShell();
      
      if (result) {
        _isConnected = true;
        _connectionController.add(true);
        print('✅ Conectado a balanza Aclas OS2X');
        
        // Iniciar lectura continua
        _startContinuousReading();
        return true;
      } else {
        print('❌ No se pudo conectar a la balanza');
        return false;
      }
    } catch (e) {
      print('❌ Error conectando a balanza: $e');
      return false;
    }
  }
  
  /// ✅ NUEVO: Probar conexión usando PowerShell
  Future<bool> _testConnectionWithPowerShell() async {
    try {
      print('🧪 Probando conexión con PowerShell...');
      
      // Comando PowerShell para probar puerto COM
      final command = '''
try {
  \$port = New-Object System.IO.Ports.SerialPort "$_targetPort", $_baudRate, "None", $_dataBits, "One"
  \$port.ReadTimeout = 1000
  \$port.WriteTimeout = 1000
  \$port.Open()
  Start-Sleep -Milliseconds 500
  
  # Enviar comando de peso
  \$port.WriteLine("$_weightCommand")
  Start-Sleep -Milliseconds 200
  
  # Leer respuesta
  \$data = \$port.ReadExisting()
  \$port.Close()
  
  Write-Host "SUCCESS: \$data"
} catch {
  Write-Host "ERROR: \$(\$_.Exception.Message)"
}
''';
      
      final result = await Process.run('powershell', ['-Command', command]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.contains('SUCCESS:')) {
          final data = output.split('SUCCESS:')[1].trim();
          print('📨 Datos de balanza: "$data"');
          
          // Verificar si es respuesta válida de Aclas OS2X
          if (_isValidAclasResponse(data)) {
            print('✅ Comunicación exitosa con balanza Aclas OS2X');
            return true;
          } else {
            print('❌ Respuesta no válida de balanza');
            return false;
          }
        } else {
          print('❌ Error en comunicación: ${result.stderr}');
          return false;
        }
      } else {
        print('❌ Error ejecutando PowerShell: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ Error en prueba de conexión: $e');
      return false;
    }
  }
  
  /// ✅ NUEVO: Verificar si es respuesta válida de Aclas OS2X
  bool _isValidAclasResponse(String response) {
    // Patrones comunes de respuestas Aclas OS2X
    final patterns = [
      RegExp(r'ST,GS,\s*[0-9]+\.[0-9]+kg'),  // Peso estable
      RegExp(r'ST,NET,\s*[0-9]+\.[0-9]+kg'), // Peso neto
      RegExp(r'US,GS,\s*[0-9]+\.[0-9]+kg'),  // Peso inestable
      RegExp(r'[0-9]+\.[0-9]+kg'),           // Cualquier peso con kg
      RegExp(r'S\s+[0-9]+\.[0-9]+kg[a-z]'),  // Patrón específico de tu balanza
    ];
    
    for (final pattern in patterns) {
      if (pattern.hasMatch(response)) {
        print('✅ Patrón válido encontrado: ${pattern.pattern}');
        return true;
      }
    }
    
    print('❌ No se encontró patrón válido en: "$response"');
    return false;
  }
  
  /// Iniciar lectura continua de peso
  void _startContinuousReading() {
    print('🔄 Iniciando lectura continua de peso...');
    
    _weightTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (_isConnected) {
        print('📊 Leyendo peso de balanza...');
        final weight = await _readWeightWithPowerShell();
        if (weight != null) {
          _currentWeight = weight;
          _weightController.add(weight);
          print('⚖️ Peso leído: ${weight.toStringAsFixed(3)} kg');
        } else {
          print('❌ No se pudo leer peso de la balanza');
        }
      } else {
        print('⚠️ Balanza no conectada');
        timer.cancel();
      }
    });
  }
  
  /// ✅ NUEVO: Leer peso usando PowerShell
  Future<double?> _readWeightWithPowerShell() async {
    try {
      final command = '''
try {
  \$port = New-Object System.IO.Ports.SerialPort "$_targetPort", $_baudRate, "None", $_dataBits, "One"
  \$port.ReadTimeout = 500
  \$port.WriteTimeout = 500
  \$port.Open()
  
  # Enviar comando de peso
  \$port.WriteLine("$_weightCommand")
  Start-Sleep -Milliseconds 100
  
  # Leer respuesta
  \$data = \$port.ReadExisting()
  \$port.Close()
  
  Write-Host "WEIGHT_DATA: \$data"
} catch {
  Write-Host "ERROR: \$(\$_.Exception.Message)"
}
''';
      
      final result = await Process.run('powershell', ['-Command', command]);
      
      if (result.exitCode == 0) {
        final output = result.stdout.toString();
        if (output.contains('WEIGHT_DATA:')) {
          final data = output.split('WEIGHT_DATA:')[1].trim();
          print('📥 Datos recibidos: "$data"');
          return _parseWeight(data);
        } else {
          print('❌ No hay datos de peso disponibles');
        }
      } else {
        print('❌ Error leyendo peso: ${result.stderr}');
      }
    } catch (e) {
      print('❌ Error leyendo peso: $e');
    }
    
    return null;
  }
  
  /// Parsear respuesta de peso de la balanza Aclas OS2X
  double? _parseWeight(String response) {
    try {
      print('🔍 Parseando respuesta: "$response"');
      
      // Patrones específicos para Aclas OS2X
      final patterns = [
        RegExp(r'ST,GS,\s*([0-9]+\.[0-9]+)kg'),  // Peso estable
        RegExp(r'ST,NET,\s*([0-9]+\.[0-9]+)kg'), // Peso neto
        RegExp(r'US,GS,\s*([0-9]+\.[0-9]+)kg'),  // Peso inestable
        RegExp(r'S\s+([0-9]+\.[0-9]+)kg[a-z]'),  // Patrón específico de tu balanza
        RegExp(r'([0-9]+\.[0-9]+)kg'),           // Cualquier peso con kg
        RegExp(r'([0-9]+,[0-9]+)'),              // Número con coma
        RegExp(r'([0-9]+\.[0-9]+)'),             // Cualquier número decimal
      ];
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(response);
        if (match != null) {
          final weightStr = match.group(1)!;
          print('📊 Peso encontrado: $weightStr');
          
          // Convertir coma a punto si es necesario
          final normalizedWeightStr = weightStr.replaceAll(',', '.');
          final weight = double.tryParse(normalizedWeightStr);
          
          if (weight != null && weight >= 0) {
            print('✅ Peso parseado correctamente: $weight kg');
            return weight;
          } else {
            print('❌ Peso inválido: $weightStr');
          }
        }
      }
      
      print('❌ No se pudo parsear peso de: "$response"');
      return null;
    } catch (e) {
      print('❌ Error parseando peso: $e');
      return null;
    }
  }
  
  /// Desconectar de la balanza
  Future<void> disconnect() async {
    try {
      print('🔌 Desconectando balanza...');
      
      _weightTimer?.cancel();
      _weightTimer = null;
      
      _isConnected = false;
      _currentWeight = 0.0;
      _connectionController.add(false);
      
      print('✅ Balanza desconectada');
    } catch (e) {
      print('❌ Error desconectando: $e');
    }
  }
  
  /// Tarar la balanza (poner en cero)
  Future<bool> tare() async {
    try {
      print('⚖️ Tarando balanza...');
      
      final command = '''
try {
  \$port = New-Object System.IO.Ports.SerialPort "$_targetPort", $_baudRate, "None", $_dataBits, "One"
  \$port.WriteTimeout = 1000
  \$port.Open()
  
  # Enviar comando de tare
  \$port.WriteLine("T\\r\\n")
  Start-Sleep -Milliseconds 500
  
  \$port.Close()
  Write-Host "TARE_SUCCESS"
} catch {
  Write-Host "ERROR: \$(\$_.Exception.Message)"
}
''';
      
      final result = await Process.run('powershell', ['-Command', command]);
      
      if (result.exitCode == 0 && result.stdout.toString().contains('TARE_SUCCESS')) {
        _currentWeight = 0.0;
        _weightController.add(0.0);
        print('✅ Balanza tarada correctamente');
        return true;
      } else {
        print('❌ Error tarando balanza: ${result.stderr}');
        return false;
      }
    } catch (e) {
      print('❌ Error en tare: $e');
      return false;
    }
  }
  
  /// Obtener peso actual
  double get currentWeightValue => _currentWeight;
  
  /// Verificar si está conectado
  bool get isConnectedValue => _isConnected;
  
  /// Dispose del servicio
  void dispose() {
    _weightTimer?.cancel();
    _weightController.close();
    _connectionController.close();
  }
} 