import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../services/agent_stats_service.dart';
import '../../theme/theme.dart';

class InmobiliariaHomeScreen extends StatefulWidget {
  const InmobiliariaHomeScreen({super.key});

  @override
  State<InmobiliariaHomeScreen> createState() => _InmobiliariaHomeScreenState();
}

class _InmobiliariaHomeScreenState extends State<InmobiliariaHomeScreen> {
  final AgentStatsService _statsService = AgentStatsService();
  final AuthService _authService = Modular.get<AuthService>();
  Map<String, dynamic> _stats = {};
  Map<String, dynamic>? _companyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final stats = await _statsService.getAgentStats(user.uid);
      
      if (mounted) {
        setState(() {
          _companyData = doc.data();
          _stats = stats;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Styles.primaryColor)),
      );
    }

    final companyName = _companyData?['companyName'] ?? 'Empresa';
    final companyLogo = _companyData?['companyLogo'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              backgroundColor: Styles.primaryColor,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  companyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Styles.primaryColor,
                        Styles.primaryColor.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        if (companyLogo != null)
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(companyLogo),
                          )
                        else
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.business, size: 40, color: Styles.primaryColor),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.all(Styles.spacingMedium),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildStatsGrid(),
                  SizedBox(height: Styles.spacingLarge),
                  _buildQuickActions(),
                  SizedBox(height: Styles.spacingLarge),
                  _buildRecentActivity(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: Styles.spacingMedium,
      crossAxisSpacing: Styles.spacingMedium,
      children: [
        _buildStatCard(
          'Propiedades',
          (_stats['totalProperties'] ?? 0).toString(),
          Icons.home_work,
          Styles.primaryColor,
        ),
        _buildStatCard(
          'Activas',
          (_stats['activeProperties'] ?? 0).toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Visitas',
          _formatNumber(_stats['totalViews'] ?? 0),
          Icons.visibility,
          Colors.purple,
        ),
        _buildStatCard(
          'Consultas',
          (_stats['totalInquiries'] ?? 0).toString(),
          Icons.chat_bubble,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 32),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyles.title.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyles.caption.copyWith(
                  color: Styles.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Acciones Rápidas',
          style: TextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: Styles.spacingMedium),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                'Nueva Propiedad',
                Icons.add_home,
                Styles.primaryColor,
                () => Modular.to.pushNamed('/inmobiliaria/new-property'),
              ),
            ),
            SizedBox(width: Styles.spacingSmall),
            Expanded(
              child: _buildActionButton(
                'Mis Propiedades',
                Icons.list,
                Colors.blue,
                () => Modular.to.navigate('/inmobiliaria/properties'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(Styles.spacingMedium),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            SizedBox(height: Styles.spacingSmall),
            Text(
              label,
              style: TextStyles.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Actividad Reciente',
          style: TextStyles.subtitle.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: Styles.spacingMedium),
        Container(
          padding: EdgeInsets.all(Styles.spacingMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              'No hay actividad reciente',
              style: TextStyles.body.copyWith(
                color: Styles.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
