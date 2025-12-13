import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';

class InmobiliariaDashboardScreen extends StatefulWidget {
  const InmobiliariaDashboardScreen({super.key});

  @override
  State<InmobiliariaDashboardScreen> createState() =>
      _InmobiliariaDashboardScreenState();
}

class _InmobiliariaDashboardScreenState
    extends State<InmobiliariaDashboardScreen> {
  final AuthService _authService = Modular.get<AuthService>();
  Map<String, dynamic>? _companyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  Future<void> _loadCompanyData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        setState(() {
          _companyData = doc.data();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    if (mounted) {
      Modular.to.navigate('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Styles.primaryColor),
        ),
      );
    }

    final companyName = _companyData?['companyName'] ?? 'Empresa';
    final ruc = _companyData?['ruc'] ?? 'N/A';
    final address = _companyData?['address'] ?? 'N/A';
    final phone = _companyData?['phoneNumber'] ?? 'N/A';
    final representative = _companyData?['representativeName'] ?? 'N/A';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleLogout();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Styles.primaryColor,
          elevation: 0,
          title: Text(
            'Panel Inmobiliaria',
            style: TextStyles.subtitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _handleLogout,
            ),
          ],
        ),
        body: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(Styles.spacingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(Styles.spacingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Styles.primaryColor,
                      Styles.primaryColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.business, size: 60, color: Colors.white),
                    SizedBox(height: Styles.spacingMedium),
                    Text(
                      companyName,
                      style: TextStyles.title.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: Styles.spacingSmall),
                    Text(
                      'RUC: $ruc',
                      style: TextStyles.body.copyWith(
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: Styles.spacingLarge),
              Text(
                'Información de la Empresa',
                style: TextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: Styles.spacingMedium),
              _buildInfoCard('Dirección', address, Icons.location_on),
              _buildInfoCard('Teléfono', phone, Icons.phone),
              _buildInfoCard(
                'Representante Legal',
                representative,
                Icons.person,
              ),
              SizedBox(height: Styles.spacingLarge),
              Text(
                'Acciones Rápidas',
                style: TextStyles.subtitle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: Styles.spacingMedium),
              _buildActionButton('Gestionar Agentes', Icons.people, () {}),
              SizedBox(height: Styles.spacingSmall),
              _buildActionButton('Ver Propiedades', Icons.home_work, () {}),
              SizedBox(height: Styles.spacingSmall),
              _buildActionButton('Estadísticas', Icons.analytics, () {}),
              SizedBox(height: Styles.spacingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: EdgeInsets.only(bottom: Styles.spacingSmall),
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Styles.primaryColor, size: 24),
          SizedBox(width: Styles.spacingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyles.caption.copyWith(
                    color: Styles.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyles.body.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Styles.spacingMedium),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Styles.primaryColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: Styles.primaryColor),
            SizedBox(width: Styles.spacingMedium),
            Expanded(
              child: Text(
                label,
                style: TextStyles.body.copyWith(
                  color: Styles.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Styles.primaryColor,
            ),
          ],
        ),
      ),
    );
  }
}
