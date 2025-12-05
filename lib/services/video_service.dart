import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';

class VideoService {
  static Future<String> uploadVideo(XFile file, String folderPath) async {
    // Comprimir video
    final compressedVideo = await VideoCompress.compressVideo(
      file.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );

    if (compressedVideo == null) {
      throw Exception('Error al comprimir video');
    }

    // Subir video comprimido
    final uri = Uri.parse(
      'https://apiplazacomida.chaskydev.com/api/v1/images/save',
    );

    final request = http.MultipartRequest('POST', uri)
      ..fields['folder'] = folderPath;

    request.files.add(
      await http.MultipartFile.fromPath('file', compressedVideo.path!),
    );

    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);

    if (resp.statusCode != 200) {
      throw Exception('Error al subir video: ${resp.statusCode}');
    }

    final body = json.decode(resp.body);
    final url = (body is Map) ? body['url']?.toString() : null;

    if (url == null || url.isEmpty) {
      throw Exception('Respuesta sin URL válida');
    }

    return url;
  }

  static Future<List<String>> uploadVideos(
    List<XFile> files,
    String folderPath,
  ) async {
    final List<String> urls = [];
    for (int i = 0; i < files.length; i++) {
      try {
        final url = await uploadVideo(files[i], '$folderPath/video_$i');
        urls.add(url);
      } catch (e) {
        print('Error uploading video $i: $e');
        rethrow;
      }
    }
    return urls;
  }
}
