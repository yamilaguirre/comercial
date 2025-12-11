import 'package:cloud_functions/cloud_functions.dart';

class FirebaseSmsService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Envía un código de verificación SMS al número de teléfono
  /// [phoneNumber] debe estar en formato +591XXXXXXXX
  Future<Map<String, dynamic>> sendVerificationCode(String phoneNumber) async {
    try {
      print('📱 [SMS] Enviando código a: $phoneNumber');

      final HttpsCallable callable = _functions.httpsCallable('sendVerificationSMS');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
      });

      print('✅ [SMS] Respuesta: ${result.data}');
      return {
        'success': true,
        'message': result.data['message'] ?? 'Código enviado',
      };
    } on FirebaseFunctionsException catch (e) {
      print('❌ [SMS] Error FirebaseFunctions: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': e.message ?? 'Error al enviar código',
        'code': e.code,
      };
    } catch (e) {
      print('❌ [SMS] Error: $e');
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }

  /// Verifica el código SMS ingresado por el usuario
  Future<Map<String, dynamic>> verifyCode(String phoneNumber, String code) async {
    try {
      print('🔍 [SMS] Verificando código para: $phoneNumber');

      final HttpsCallable callable = _functions.httpsCallable('verifyPhoneCode');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
        'code': code,
      });

      print('✅ [SMS] Verificación exitosa: ${result.data}');
      return {
        'success': true,
        'message': result.data['message'] ?? 'Código verificado',
      };
    } on FirebaseFunctionsException catch (e) {
      print('❌ [SMS] Error verificación: ${e.code} - ${e.message}');
      return {
        'success': false,
        'message': e.message ?? 'Error al verificar código',
        'code': e.code,
      };
    } catch (e) {
      print('❌ [SMS] Error: $e');
      return {
        'success': false,
        'message': 'Error inesperado: $e',
      };
    }
  }
}
