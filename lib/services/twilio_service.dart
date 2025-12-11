// filepath: lib/services/twilio_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/twilio_config.dart';

class TwilioService {
  static Future<bool> sendWhatsAppVerification(String phoneNumber) async {
    print('🔵 [TWILIO DEBUG] === INICIANDO VERIFICACIÓN ===');
    print('🔵 [TWILIO DEBUG] Número: $phoneNumber');
    print('🔵 [TWILIO DEBUG] Account SID: ${TwilioConfig.accountSid}');
    print('🔵 [TWILIO DEBUG] Account SID Length: ${TwilioConfig.accountSid.length}');
    print('🔵 [TWILIO DEBUG] Auth Token: ${TwilioConfig.authToken.substring(0, 8)}...');
    print('🔵 [TWILIO DEBUG] Auth Token Length: ${TwilioConfig.authToken.length}');
    print('🔵 [TWILIO DEBUG] Service SID: ${TwilioConfig.verifyServiceSid}');
    
    // Validar formato del número
    if (!_isValidPhoneNumber(phoneNumber)) {
      print('❌ [TWILIO DEBUG] Número inválido: $phoneNumber');
      return false;
    }

    // Verificar credenciales básicas
    if (TwilioConfig.accountSid.isEmpty || TwilioConfig.authToken.isEmpty || TwilioConfig.verifyServiceSid.isEmpty) {
      print('❌ [TWILIO DEBUG] Credenciales vacías');
      return false;
    }

    final url = Uri.parse(
      'https://verify.twilio.com/v2/Services/${TwilioConfig.verifyServiceSid}/Verifications',
    );

    final credentials = base64Encode(
      utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'),
    );

    print('🔵 [TWILIO DEBUG] URL: $url');
    print('🔵 [TWILIO DEBUG] Credentials (base64): ${credentials.substring(0, 20)}...');
    print('🔵 [TWILIO DEBUG] Full Auth String: ${TwilioConfig.accountSid}:${TwilioConfig.authToken.substring(0, 10)}...');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': phoneNumber,
          'Channel': 'sms',
        },
      ).timeout(const Duration(seconds: 30));

      print('🔵 [TWILIO DEBUG] Status Code: ${response.statusCode}');
      print('🔵 [TWILIO DEBUG] Response Headers: ${response.headers}');
      print('🔵 [TWILIO DEBUG] Response Body: ${response.body}');

      if (response.statusCode == 201) {
        print('✅ [TWILIO DEBUG] Código enviado exitosamente');
        return true;
      } else {
        print('❌ [TWILIO DEBUG] Error HTTP: ${response.statusCode}');
        try {
          final errorData = json.decode(response.body);
          print('❌ [TWILIO DEBUG] Error Message: ${errorData['message'] ?? 'Sin mensaje'}');
          print('❌ [TWILIO DEBUG] Error Code: ${errorData['code'] ?? 'Sin código'}');
          print('❌ [TWILIO DEBUG] More Info: ${errorData['more_info'] ?? 'Sin info adicional'}');
        } catch (e) {
          print('❌ [TWILIO DEBUG] Error al parsear JSON: $e');
          print('❌ [TWILIO DEBUG] Raw response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      print('❌ [TWILIO DEBUG] Excepción completa: $e');
      print('❌ [TWILIO DEBUG] Tipo de excepción: ${e.runtimeType}');
      return false;
    }
  }

  static bool _isValidPhoneNumber(String phoneNumber) {
    // Validar que el número tenga el formato correcto
    final regex = RegExp(r'^\+591[67]\d{7}$');
    return regex.hasMatch(phoneNumber);
  }

  static Future<bool> verifyCode(String phoneNumber, String code) async {
    final url = Uri.parse(
      'https://verify.twilio.com/v2/Services/${TwilioConfig.verifyServiceSid}/VerificationCheck',
    );

    final credentials = base64Encode(
      utf8.encode('${TwilioConfig.accountSid}:${TwilioConfig.authToken}'),
    );

    print('🔵 [TWILIO DEBUG] Verificando código para: $phoneNumber');
    print('🔵 [TWILIO DEBUG] Código ingresado: $code');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'To': phoneNumber,
          'Code': code,
        },
      );

      print('🔵 [TWILIO DEBUG] Status Code: ${response.statusCode}');
      print('🔵 [TWILIO DEBUG] Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final status = data['status'];
        print('🔵 [TWILIO DEBUG] Status: $status');
        
        if (status == 'approved') {
          print('✅ [TWILIO DEBUG] Código verificado correctamente');
          return true;
        } else {
          print('❌ [TWILIO DEBUG] Código no aprobado: $status');
          return false;
        }
      }
      
      print('❌ [TWILIO DEBUG] Error en verificación: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ [TWILIO DEBUG] Excepción al verificar: $e');
      return false;
    }
  }
}
