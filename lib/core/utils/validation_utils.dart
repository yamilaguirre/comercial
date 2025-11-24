/// Utilidades de validación
class ValidationUtils {
  ValidationUtils._();

  /// Valida formato de email
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  /// Valida longitud de contraseña
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  /// Valida que el nombre no esté vacío y tenga longitud mínima
  static bool isValidName(String name) {
    return name.trim().isNotEmpty && name.trim().length >= 2;
  }

  /// Valida formato de teléfono boliviano
  static bool isValidPhone(String phone) {
    // Formatos válidos: 70123456, +59170123456, 59170123456
    return RegExp(r'^(\+?591)?[67]\d{7}$').hasMatch(phone);
  }

  /// Valida que sea solo letras y espacios
  static bool isValidFullName(String name) {
    return RegExp(r'^[a-zA-ZÀ-ÿ\s]+$').hasMatch(name);
  }
}

/// Utilidades de formato
class FormatUtils {
  FormatUtils._();

  /// Formatea un número de teléfono
  static String formatPhone(String phone) {
    if (phone.startsWith('+591')) return phone;
    if (phone.startsWith('591')) return '+$phone';
    if (phone.length == 8) return '+591$phone';
    return phone;
  }

  /// Capitaliza la primera letra de cada palabra
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  /// Formatea un precio en bolivianos
  static String formatPrice(double price) {
    return 'Bs. ${price.toStringAsFixed(2)}';
  }
}

/// Utilidades de fecha y tiempo
class DateUtils {
  DateUtils._();

  /// Formatea una fecha a string legible
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Formatea hora a string
  static String formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Calcula la edad basada en fecha de nacimiento
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
