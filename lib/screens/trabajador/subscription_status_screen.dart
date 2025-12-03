import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../services/subscription_service.dart';
import '../../models/subscription_request_model.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() =>
      _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen> {
  final _subscriptionService = SubscriptionService();
  bool _isLoading = true;
  SubscriptionRequest? _request;
  Map<String, dynamic>? _premiumStatus;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionData();
  }

  Future<void> _loadSubscriptionData() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      try {
        // 1. Check premium_users collection first (Source of Truth for active subscriptions)
        final premiumStatus = await _subscriptionService.getUserPremiumStatus(
          user.uid,
        );

        // 2. Check subscription_requests collection
        final request = await _subscriptionService.getUserSubscriptionRequest(
          user.uid,
        );

        if (mounted) {
          setState(() {
            _premiumStatus = premiumStatus;
            _request = request;
            _isLoading = false;
          });
        }
      } catch (e) {
        print('Error loading subscription data: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '-';
    if (timestamp is Timestamp) {
      return _formatDate(timestamp.toDate());
    } else if (timestamp is DateTime) {
      return _formatDate(timestamp);
    } else if (timestamp is String) {
      return timestamp; // Assume it's already formatted or a string date
    }
    return '-';
  }

  void _navigateToPaymentScreen() {
    Modular.to.pushNamed('/worker/subscription-payment');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estado de Suscripción'),
        backgroundColor: Styles.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // First check if user has active premium in premium_users
    if (_premiumStatus != null && _premiumStatus!['status'] == 'active') {
      return _buildApprovedStatus();
    }

    // Then check subscription_requests status
    if (_request != null) {
      final status = _request!.status;

      if (status == 'approved') {
        return _buildApprovedStatus();
      } else if (status == 'pending') {
        return _buildPendingStatus();
      } else if (status == 'rejected') {
        return _buildRejectedStatus();
      }
    }

    // No subscription found
    return _buildNoSubscription();
  }

  Widget _buildNoSubscription() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.workspace_premium_outlined,
              size: 100,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'No tienes ninguna suscripción activa',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Suscríbete para desbloquear funciones Premium',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _navigateToPaymentScreen,
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Suscribirme Ahora'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedStatus() {
    // Use premium_users data if available, otherwise fall back to request data
    final planName =
        _premiumStatus?['planName'] ?? _request?.planName ?? 'Premium';
    final amount = _premiumStatus?['amount'] ?? _request?.amount;
    final startDate = _premiumStatus?['startedAt'];
    final expiresAt = _premiumStatus?['expiresAt'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Success Card with vibrant gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E88E5), // Vibrant Blue
                  Color(0xFFFF6F00), // Vibrant Orange
                  Color(0xFFFFC107), // Vibrant Yellow
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                const Text(
                  '¡Eres Premium!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan $planName',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Details Section
          _buildDetailCard('Detalles de tu Suscripción', [
            _buildDetailRow(Icons.shopping_bag, 'Plan', planName),
            if (amount != null)
              _buildDetailRow(Icons.attach_money, 'Monto', '$amount BOB'),
            if (startDate != null)
              _buildDetailRow(
                Icons.calendar_today,
                'Fecha de inicio',
                _formatTimestamp(startDate),
              ),
            if (expiresAt != null)
              _buildDetailRow(
                Icons.event,
                'Válido hasta',
                _formatTimestamp(expiresAt),
              ),
          ]),

          const SizedBox(height: 16),

          // Benefits Card
          _buildDetailCard('Beneficios Premium', const [
            _BenefitItem(
              icon: Icons.star,
              text: 'Recomendaciones personalizadas',
            ),
            _BenefitItem(
              icon: Icons.location_on,
              text: 'Mayor radio de búsqueda',
            ),
            _BenefitItem(
              icon: Icons.search,
              text: 'Búsqueda ilimitada en el mapa',
            ),
            _BenefitItem(icon: Icons.flash_on, text: 'Resultados prioritarios'),
            _BenefitItem(icon: Icons.notifications, text: 'Alertas avanzadas'),
          ]),
        ],
      ),
    );
  }

  Widget _buildPendingStatus() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending Card with blue-orange gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF2196F3), // Blue
                  Color(0xFFFF9800), // Orange
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.schedule, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Solicitud en Revisión',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Estamos verificando tu pago',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildDetailCard('Información de tu Solicitud', [
            _buildDetailRow(Icons.shopping_bag, 'Plan', _request!.planName),
            _buildDetailRow(
              Icons.attach_money,
              'Monto',
              '${_request!.amount} BOB',
            ),
            if (_request!.createdAt != null)
              _buildDetailRow(
                Icons.calendar_today,
                'Fecha de envío',
                _formatDate(_request!.createdAt!),
              ),
          ]),

          const SizedBox(height: 16),

          // Receipt preview
          if (_request!.receiptUrl.isNotEmpty) ...[
            const Text(
              'Comprobante de Pago',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _request!.receiptUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.error_outline, size: 50),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRejectedStatus() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rejected Card with orange-red gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF6F00), // Dark Orange
                  Color(0xFFE53935), // Red
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.cancel, color: Colors.white, size: 80),
                const SizedBox(height: 16),
                const Text(
                  'Solicitud Rechazada',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu solicitud no pudo ser aprobada',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Rejection reason
          if (_request!.rejectionReason != null &&
              _request!.rejectionReason!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Motivo del Rechazo',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _request!.rejectionReason!,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Try again button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToPaymentScreen,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de Nuevo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Styles.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Styles.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: Styles.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
