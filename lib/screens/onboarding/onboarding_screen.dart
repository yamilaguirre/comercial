// filepath: lib/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // Usamos Flutter Modular para la navegación
import '../../theme/theme.dart'; // Importa el archivo barril que exporta Styles y TextStyles

/// Pantalla de Onboarding - Bienvenida a la aplicación
///
/// Muestra 4 pantallas con transición suave:
/// 1. Splash con logo
/// 2. Encuentra tu próximo hogar
/// 3. Trabajo honesto, cerca de ti
/// 4. Todo en una sola app
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Datos de las páginas de onboarding
  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Bienvenido a',
      description:
          'Tu plataforma de confianza para encontrar inmuebles y servicios',
      imagePath: 'assets/images/logo.png', // Logo blanco sobre fondo azul
      backgroundColor: Styles.primaryColor,
      showSkip: false,
      isSplash: true,
    ),
    OnboardingPageData(
      title: 'Encuentra tu próximo hogar',
      description:
          'Explora inmuebles en venta, anticrético y alquiler con información clara y actualizada, todo en un solo lugar.',
      imagePath: 'assets/images/onboardin1.png',
      backgroundColor: Colors.white,
      showSkip: true,
      isSplash: false,
    ),
    OnboardingPageData(
      title: 'Trabajo honesto, cerca de ti',
      description:
          'Encuentra a personas que ofrecen sus oficios de forma independiente y apóyalas contratando sus servicios cuando los necesites.',
      imagePath: 'assets/images/onboardin2.png',
      backgroundColor: Colors.white,
      showSkip: true,
      isSplash: false,
    ),
    OnboardingPageData(
      title: 'Todo en una sola app',
      description:
          'Una plataforma que une oportunidades de vivienda y servicios laborales para hacer tu vida más simple.',
      imagePath: 'assets/images/onboardin3.png',
      backgroundColor: Colors.white,
      showSkip: true,
      isSplash: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // Auto-avanzar después del splash (página 0 a página 1)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _currentPage == 0) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _goToLogin();
    }
  }

  void _goToLogin() {
    // Navegación Modular a la ruta '/login', definida en AuthModule.
    Modular.to.navigate('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pages[_currentPage].backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // PageView con las páginas
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Indicadores y botón moved into each page overlay to avoid duplication
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPageData page) {
    // Splash screen especial (Página 0) con degradé azul
    if (page.isSplash) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0033CC), // Azul oscuro izquierda
              Color.fromARGB(255, 71, 140, 244), // Azul medio
              Color.fromARGB(255, 88, 191, 243), // Azul claro / cyan derecha
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Hero(
              tag: 'app_logo',
              child: Image.asset(
                page.imagePath, // 'assets/images/logo.png' (blanco)
                height: 150,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }

    // Páginas normales de onboarding con imagen full-screen y degradé azul
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fondo: imagen a pantalla completa
        Image.asset(
          page.imagePath,
          fit: BoxFit.cover,
        ),
        // Overlay: degradé azul desde transparente/gris a azul sólido
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x3FBFBFBF), // ~23% gris sobre la parte superior
                Color(0x9F1B54C8), // ~62% azul medio
                Color(0xFF001BB7), // 100% azul en el fondo
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),

        // Contenido distribuido: logo arriba, texto centrado, botón abajo - RESPONSIVE
        LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                // Logo arriba
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Styles.spacingLarge,
                      vertical: Styles.spacingMedium,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/logo.png',
                          height: 44,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),

                // Espaciador flexible para empujar todo el contenido al fondo
                const Spacer(),

                // Todo el contenido pegado al fondo (título, descripción, indicadores y botón)
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(Styles.spacingLarge),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Título
                        Text(
                          page.title,
                          style: TextStyles.title.copyWith(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: Styles.spacingMedium),
                        
                        // Descripción
                        Text(
                          page.description,
                          style: TextStyles.body.copyWith(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: Styles.spacingLarge),

                        // Indicadores
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _pages.length - 1,
                            (index) => _buildPageIndicator(index + 1),
                          ),
                        ),

                        SizedBox(height: Styles.spacingLarge),

                        // Botón Siguiente/Comenzar
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Styles.primaryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  Styles.radiusMedium,
                                ),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _currentPage == _pages.length - 1
                                    ? 'Comenzar'
                                    : 'Siguiente',
                                style: TextStyles.button.copyWith(
                                  fontSize: 16,
                                  color: Styles.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPageIndicator(int index) {
    // Ajustamos el índice para comparar correctamente (skip splash)
    bool isActive = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: Styles.spacingXSmall),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Styles.primaryColor : Styles.borderColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

/// Modelo de datos para cada página de onboarding
class OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;
  final Color backgroundColor;
  final bool showSkip;
  final bool isSplash;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.backgroundColor,
    required this.showSkip,
    this.isSplash = false,
  });
}
