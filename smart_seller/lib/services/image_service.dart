import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Selecciona una imagen desde la galería o cámara
  static Future<String?> pickProductImage(BuildContext context) async {
    try {
      // Mostrar opciones de selección
      final source = await _showImageSourceDialog(context);
      if (source == null) return null;

      // Seleccionar imagen
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return null;

      // Guardar imagen en directorio de productos
      final savedPath = await _saveProductImage(image);
      return savedPath;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Muestra el diálogo para seleccionar fuente de imagen
  static Future<ImageSource?> _showImageSourceDialog(BuildContext context) async {
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Imagen'),
        content: const Text('¿De dónde deseas seleccionar la imagen?'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.camera),
            icon: const Icon(Icons.camera_alt),
            label: const Text('Cámara'),
          ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: const Text('Galería'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Guarda la imagen en el directorio de productos
  static Future<String> _saveProductImage(XFile image) async {
    try {
      // Obtener directorio de documentos
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory productImagesDir = Directory(path.join(appDir.path, 'product_images'));
      
      // Crear directorio si no existe
      if (!await productImagesDir.exists()) {
        await productImagesDir.create(recursive: true);
      }

      // Generar nombre único para la imagen
      final String fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(productImagesDir.path, fileName);

      // Copiar imagen al directorio de productos
      final File savedFile = await File(image.path).copy(filePath);
      
      print('✅ Imagen guardada: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Error guardando imagen: $e');
      rethrow;
    }
  }

  /// Elimina una imagen de producto
  static Future<bool> deleteProductImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return true;
    
    try {
      final File imageFile = File(imagePath);
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('✅ Imagen eliminada: $imagePath');
      }
      return true;
    } catch (e) {
      print('❌ Error eliminando imagen: $e');
      return false;
    }
  }

  /// Verifica si una imagen existe
  static Future<bool> imageExists(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    
    try {
      if (imagePath.startsWith('http')) {
        // Para URLs de red, asumimos que existe
        return true;
      } else if (imagePath.startsWith('assets/')) {
        // Para assets, asumimos que existe
        return true;
      } else {
        // Para archivos locales, verificar existencia
        return await File(imagePath).exists();
      }
    } catch (e) {
      print('❌ Error verificando imagen: $e');
      return false;
    }
  }

  /// Obtiene el tamaño de una imagen
  static Future<Size?> getImageSize(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    try {
      if (imagePath.startsWith('http') || imagePath.startsWith('assets/')) {
        // Para URLs y assets, no podemos obtener el tamaño fácilmente
        return null;
      } else {
        final File imageFile = File(imagePath);
        if (await imageFile.exists()) {
          // Aquí podrías usar un paquete como image para obtener las dimensiones
          // Por ahora retornamos null
          return null;
        }
      }
      return null;
    } catch (e) {
      print('❌ Error obteniendo tamaño de imagen: $e');
      return null;
    }
  }

  /// Limpia imágenes huérfanas (no referenciadas por productos)
  static Future<void> cleanupOrphanImages(List<String> usedImagePaths) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final Directory productImagesDir = Directory(path.join(appDir.path, 'product_images'));
      
      if (!await productImagesDir.exists()) return;

      final List<FileSystemEntity> files = await productImagesDir.list().toList();
      
      for (final file in files) {
        if (file is File) {
          final String filePath = file.path;
          final bool isUsed = usedImagePaths.any((usedPath) => usedPath == filePath);
          
          if (!isUsed) {
            await file.delete();
            print('🗑️ Imagen huérfana eliminada: ${path.basename(filePath)}');
          }
        }
      }
    } catch (e) {
      print('❌ Error limpiando imágenes huérfanas: $e');
    }
  }
}
