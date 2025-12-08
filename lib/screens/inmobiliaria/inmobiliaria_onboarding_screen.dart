import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/theme.dart';
import '../../providers/auth_provider.dart';

class InmobiliariaOnboardingScreen extends StatefulWidget {
  const InmobiliariaOnboardingScreen({super.key});

  @override
  State<InmobiliariaOnboardingScreen> createState() =>
      _InmobiliariaOnboardingScreenState();
}

class _InmobiliariaOnboardingScreenState
    extends State<InmobiliariaOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingRequest();
    });
  }

  Future<void> _checkExistingRequest() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        print('Checking subscription request for user: ${user.uid}');
        final requestsQuery = await FirebaseFirestore.instance
            .collection('subscription_requests')
            .where('userId', isEqualTo: user.uid)
            .get();

        print('Found ${requestsQuery.docs.length} requests');

        if (requestsQuery.docs.isNotEmpty && mounted) {
          print('Redirecting to subscription status');
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            Modular.to.navigate('/inmobiliaria/subscription-status');
          }
        }
      } catch (e) {
        print('Error checking existing request: $e');
      }
    }
  }

  void _handleSubscribe() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        print(
          'Button clicked - Checking subscription request for user: ${user.uid}',
        );
        final requestsQuery = await FirebaseFirestore.instance
            .collection('subscription_requests')
            .where('userId', isEqualTo: user.uid)
            .get();

        print('Button - Found ${requestsQuery.docs.length} requests');

        if (requestsQuery.docs.isNotEmpty) {
          print('Button - Redirecting to status');
          Modular.to.pushNamed('/inmobiliaria/subscription-status');
        } else {
          print('Button - Redirecting to payment');
          Modular.to.pushNamed('/inmobiliaria/subscription-payment');
        }
      } catch (e) {
        print('Button - Error: $e');
        Modular.to.pushNamed('/inmobiliaria/subscription-payment');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Styles.primaryColor, Styles.primaryColor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business, size: 100, color: Colors.white),
                const SizedBox(height: 32),
                const Text(
                  '¡Bienvenido a tu plataforma de agente inmobiliario!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Obtén todos los beneficios como inmobiliaria',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                _buildBenefit(Icons.add_business, 'Crea tus propios anuncios'),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.visibility,
                  'Los usuarios verán tus anuncios con tu logo',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.chat_bubble_outline,
                  'Habla directamente con tus clientes',
                ),
                const SizedBox(height: 16),
                _buildBenefit(
                  Icons.analytics,
                  'Accede a estadísticas de tus propiedades',
                ),
                const SizedBox(height: 16),
                _buildBenefit(Icons.star, 'Destaca tus mejores propiedades'),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSubscribe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Styles.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 8,
                    ),
                    child: const Text(
                      'Suscribirme Ahora',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefit(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
