/// Constantes de la aplicación
class AppConstants {
  AppConstants._();

  // API
  static const String baseUrl = 'https://api.comercial.com';
  static const String apiVersion = 'v1';
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Cache
  static const String userTokenKey = 'user_token';
  static const String userDataKey = 'user_data';
  static const String onboardingKey = 'onboarding_completed';

  // Rutas
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String onboardingRoute = '/onboarding';

  // Validaciones
  static const int minPasswordLength = 6;
  static const int maxPasswordLength = 50;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;

  // Paginación
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Timeouts
  static const Duration splashDuration = Duration(seconds: 3);
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration debounceDelay = Duration(milliseconds: 500);
}

/// Constantes de cadenas de texto
class AppStrings {
  AppStrings._();

  // App
  static const String appName = 'Comercial';

  // Errores generales
  static const String networkError = 'Error de conexión a internet';
  static const String serverError = 'Error del servidor';
  static const String cacheError = 'Error de almacenamiento local';
  static const String unknownError = 'Error desconocido';

  // Validaciones
  static const String emailRequired = 'El correo es requerido';
  static const String emailInvalid = 'El correo no es válido';
  static const String passwordRequired = 'La contraseña es requerida';
  static const String passwordTooShort =
      'La contraseña debe tener al menos 6 caracteres';
  static const String nameRequired = 'El nombre es requerido';
  static const String phoneRequired = 'El teléfono es requerido';
  static const String termsRequired =
      'Debes aceptar los términos y condiciones';

  // Auth
  static const String loginTitle = 'Iniciar Sesión';
  static const String registerTitle = 'Crear Cuenta';
  static const String forgotPassword = '¿Olvidaste tu contraseña?';
  static const String dontHaveAccount = '¿No tienes una cuenta?';
  static const String alreadyHaveAccount = '¿Ya tienes una cuenta?';
  static const String registerHere = 'Regístrate';
  static const String loginHere = 'Inicia sesión';
}
