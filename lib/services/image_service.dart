import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  // --- CARPETAS CONSTANTES Y PÚBLICAS ---
  static const String IMAGE_PROFILE_FOLDER = 'user_avatars';
  static const String IMAGE_PROPERTY_FOLDER = 'property_images';
  // ----------------------------------------

  /// Sube la imagen a la API personalizada y devuelve la URL.
  ///
  /// @param file Imagen seleccionada (XFile).
  /// @param folderPath Carpeta completa donde se guardará (ej: 'user_avatars/{uid}').
  /// @param webBytes (Opcional) Bytes para entorno web.
  static Future<String> uploadImageToApi(
    XFile file, {
    required String folderPath, // Usamos folderPath en lugar de userId
    Uint8List? webBytes,
    Map<String, String>? headers,
  }) async {
    // La URI de tu API de subida
    final uri = Uri.parse(
      'https://apiplazacomida.chaskydev.com/api/v1/images/save',
    );

    // Creamos la solicitud Multipart
    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] =
          folderPath; // Carpeta dinámica: 'property_images/{pid}', etc.

    // Añadir headers si son necesarios (ej: Token de autenticación)
    if (headers != null && headers.isNotEmpty) {
      request.headers.addAll(headers);
    }

    // Añadir el archivo al cuerpo de la solicitud
    if (kIsWeb) {
      final bytes = webBytes ?? await file.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: file.name),
      );
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
    }

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
      // Usamos la constante estática
      folderPath: '$IMAGE_PROFILE_FOLDER/$userId',
      webBytes: webBytes,
      headers: headers,
    );
  }
}
