import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageService {
  // --- CARPETAS CONSTANTES Y PÚBLICAS ---
  static const String IMAGE_PROFILE_FOLDER = 'user_avatars';
  static const String IMAGE_PROPERTY_FOLDER = 'property_images';
  // ----------------------------------------

  /// Comprime una imagen antes de subirla
  static Future<Uint8List> _compressImage(XFile file) async {
    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      return bytes;
    }

    final result = await FlutterImageCompress.compressWithFile(
      file.path,
      quality: 70,
      minWidth: 1920,
      minHeight: 1080,
    );

    return result ?? await file.readAsBytes();
  }

  /// Sube la imagen a la API personalizada y devuelve la URL.
  ///
  /// @param file Imagen seleccionada (XFile).
  /// @param folderPath Carpeta completa donde se guardará (ej: 'user_avatars/{uid}').
  /// @param webBytes (Opcional) Bytes para entorno web.
  static Future<String> uploadImageToApi(
    XFile file, {
    required String folderPath,
    Uint8List? webBytes,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      'https://apiplazacomida.chaskydev.com/api/v1/images/save',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] = folderPath;

    if (headers != null && headers.isNotEmpty) {
      request.headers.addAll(headers);
    }

    // Comprimir imagen antes de subir
    final compressedBytes = await _compressImage(file);
    request.files.add(
      http.MultipartFile.fromBytes('file', compressedBytes, filename: file.name),
    );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('Error al subir imagen: ${resp.statusCode} ${resp.body}');
    }

    final body = json.decode(resp.body);
    final url = (body is Map) ? body['url']?.toString() : null;

    if (url == null || url.isEmpty) {
      throw Exception('Respuesta JSON sin URL válida: ${resp.body}');
    }

    return url;
  }

  // Mantener el helper de avatar por compatibilidad
  static Future<String> uploadAvatarToApi(
    XFile file, {
    required String userId,
    Uint8List? webBytes,
    Map<String, String>? headers,
  }) async {
    return uploadImageToApi(
      file,
      folderPath: '$IMAGE_PROFILE_FOLDER/$userId',
      webBytes: webBytes,
      headers: headers,
    );
  }

  /// Sube múltiples imágenes comprimidas y devuelve una lista de URLs
  static Future<List<String>> uploadImages(
    List<XFile> files,
    String folderPath,
  ) async {
    final List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      try {
        final url = await uploadImageToApi(
          files[i],
          folderPath: '$folderPath/image_$i',
        );
        urls.add(url);
      } catch (e) {
        print('Error uploading image $i: $e');
        rethrow;
      }
    }
    return urls;
  }
}
