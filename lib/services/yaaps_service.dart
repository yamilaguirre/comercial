import 'package:url_launcher/url_launcher.dart';

class YaApsService {
  static const String androidPackageName = 'com.aplicaciones.taxia1';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageName';

  /// Abre YaAps para pedir un taxi o una mudanza.
  ///
  /// [esMudanza] true para mudanza, false para viaje (taxi).
  /// [lat] Latitud del destino.
  /// [lng] Longitud del destino.
  /// [address] Dirección textual del destino.
  static Future<void> abrirYaAps({
    required bool esMudanza,
    required double lat,
    required double lng,
    required String address,
  }) async {
    final scheme = esMudanza ? 'mudanza' : 'viaje';
    final url =
        'yaaps://$scheme?lat=$lat&lng=$lng&address=${Uri.encodeComponent(address)}';
    final uri = Uri.parse(url);

    try {
      // Intentar abrir el deep link directamente
      // En Android, a veces canLaunchUrl retorna falso por configuraciones internas
      // pero launchUrl puede funcionar en modo externalApplication.
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        // Si no se pudo lanzar, intentamos el fallback a la Play Store
        await _abrirPlayStore();
      }
    } catch (e) {
      await _abrirPlayStore();
    }
  }

  static Future<void> _abrirPlayStore() async {
    await launchUrl(
      Uri.parse(playStoreUrl),
      mode: LaunchMode.externalApplication,
    );
  }
}
