import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  /// Extensiones permitidas para imágenes (se muestran en el selector en Windows).
  static const List<String> _imageExtensions = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp'
  ];

  /// Selecciona una imagen desde la galería, cámara o archivo (en escritorio).
  static Future<String?> pickProductImage(BuildContext context) async {
    try {
      final source = await _showImageSourceDialog(context);
      if (source == null) return null;

      // En Windows/escritorio, "Galería" usa file_picker para que aparezcan las extensiones
      if (source == ImageSource.gallery &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
        final filePath = await _pickImageFileDesktop();
        if (filePath == null) return null;
        final savedPath = await _saveProductImageFromPath(filePath);
        return savedPath;
      }

      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return null;

      final savedPath = await _saveProductImage(image);
      return savedPath;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// En escritorio: abre el selector de archivos con filtro de imágenes (extensiones visibles).
  static Future<String?> _pickImageFileDesktop() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _imageExtensions,
      dialogTitle: 'Seleccionar imagen del producto',
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  /// Guarda una imagen desde una ruta de archivo (usado tras file_picker en escritorio).
  static Future<String> _saveProductImageFromPath(String sourcePath) async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory productImagesDir =
        Directory(path.join(appDir.path, 'product_images'));
    if (!await productImagesDir.exists()) {
      await productImagesDir.create(recursive: true);
    }
    final ext = path.extension(sourcePath).toLowerCase();
    if (ext.isEmpty) return sourcePath;
    final String fileName =
        'product_${DateTime.now().millisecondsSinceEpoch}$ext';
    final String filePath = path.join(productImagesDir.path, fileName);
    await File(sourcePath).copy(filePath);
    print('✅ Imagen guardada: $filePath');
    return filePath;
  }

  /// Muestra el diálogo para seleccionar fuente de imagen
  static Future<ImageSource?> _showImageSourceDialog(
      BuildContext context) async {
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return await showDialog<ImageSource>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Imagen'),
        content: Text(
          isDesktop
              ? 'Elige "Seleccionar archivo" para buscar una imagen (JPG, PNG, etc.) en tu PC.'
              : '¿De dónde deseas seleccionar la imagen?',
        ),
        actions: [
          if (!isDesktop)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Cámara'),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
            icon: const Icon(Icons.photo_library),
            label: Text(isDesktop ? 'Seleccionar archivo' : 'Galería'),
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
      final Directory productImagesDir =
          Directory(path.join(appDir.path, 'product_images'));

      // Crear directorio si no existe
      if (!await productImagesDir.exists()) {
        await productImagesDir.create(recursive: true);
      }

      // Generar nombre único para la imagen
      final String fileName =
          'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String filePath = path.join(productImagesDir.path, fileName);

      // Copiar imagen al directorio de productos
      await File(image.path).copy(filePath);

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
      final Directory productImagesDir =
          Directory(path.join(appDir.path, 'product_images'));

      if (!await productImagesDir.exists()) return;

      final List<FileSystemEntity> files =
          await productImagesDir.list().toList();

      for (final file in files) {
        if (file is File) {
          final String filePath = file.path;
          final bool isUsed =
              usedImagePaths.any((usedPath) => usedPath == filePath);

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
