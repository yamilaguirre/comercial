import 'package:flutter/material.dart';
import '../../theme/theme.dart';
import 'package:url_launcher/url_launcher.dart';

class WorkerSavedScreen extends StatefulWidget {
  const WorkerSavedScreen({super.key});

  @override
  State<WorkerSavedScreen> createState() => _WorkerSavedScreenState();
}

class _WorkerSavedScreenState extends State<WorkerSavedScreen> {
  String selectedTab = 'Todo Guardado';
  int selectedFilter = 0;

  // Datos simulados de trabajadores guardados
  final List<Map<String, dynamic>> savedWorkers = [
    {
      'name': 'Carlos Mendoza',
      'profession': 'Electricista',
      'photoUrl': null,
      'rating': 4.9,
      'reviewCount': 234,
      'price': 150,
      'distance': 1.2,
      'phone': '+59170000000',
      'services': ['Instalaciones', 'Reparaciones', 'Emergencias'],
      'isProfessional': true,
    },
    {
      'name': 'María López',
      'profession': 'Arquitecta',
      'photoUrl': null,
      'rating': 4.8,
      'reviewCount': 128,
      'price': 500,
      'distance': 2.5,
      'phone': '+59171111111',
      'services': ['Diseño', 'Planos', 'Remodelación'],
      'isProfessional': true,
    },
    {
      'name': 'Jorge Vargas',
      'profession': 'Plomero',
      'photoUrl': null,
      'rating': 4.7,
      'reviewCount': 95,
      'price': 200,
      'distance': 0.8,
      'phone': '+59172222222',
      'services': ['Instalaciones', 'Reparaciones'],
      'isProfessional': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Guardados',
          style: TextStyles.title.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Styles.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs: Todo Guardado / Mis Colecciones
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: Styles.spacingMedium,
              vertical: Styles.spacingSmall,
            ),
            child: Row(
              children: [
                Expanded(child: _buildTabButton('Todo Guardado')),
                SizedBox(width: Styles.spacingSmall),
                Expanded(child: _buildTabButton('Mis Colecciones')),
              ],
            ),
          ),

          // Filtros: Guardados, Contactados, Por contactar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
            child: Row(
              children: [
                _buildFilterChip(Icons.favorite, 'Guardados', 0, 0),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(
                  Icons.check_circle_outline,
                  'Contactados',
                  1,
                  0,
                ),
                SizedBox(width: Styles.spacingSmall),
                _buildFilterChip(Icons.phone_outlined, 'P...', 2, 0),
              ],
            ),
          ),

          SizedBox(height: Styles.spacingMedium),

          // Lista de trabajadores guardados
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: Styles.spacingMedium),
              itemCount: savedWorkers.length,
              itemBuilder: (context, index) {
                return _buildWorkerCard(savedWorkers[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title) {
    final isSelected = selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = title),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: Styles.spacingSmall),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyles.body.copyWith(
            color: isSelected ? Styles.textPrimary : Styles.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(IconData icon, String label, int index, int count) {
    final isSelected = selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? Styles.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? Styles.primaryColor : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF6B7280),
                size: 18,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF374151),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.25)
                        : Styles.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.white : Styles.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker) {
    return Container(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
      padding: EdgeInsets.all(Styles.spacingMedium),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con foto, nombre y favorito
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                ),
                child: worker['photoUrl'] != null
                    ? ClipOval(
                        child: Image.network(
                          worker['photoUrl'],
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.person, size: 35, color: Colors.grey[600]),
              ),

              const SizedBox(width: 12),

              // Nombre y profesión
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      worker['profession'],
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              // Icono de favorito
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red, size: 24),
                onPressed: () {},
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Rating y badge profesional
          Row(
            children: [
              ...List.generate(
                5,
                (index) => Icon(
                  index < worker['rating'].floor()
                      ? Icons.star
                      : Icons.star_border,
                  color: const Color(0xFFFFC107),
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              if (worker['isProfessional'])
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Styles.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Profesional',
                    style: TextStyle(
                      fontSize: 11,
                      color: Styles.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Precio, distancia y rating
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Desde',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    'Bs ${worker['price']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Styles.primaryColor,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.black54,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'A ${worker['distance']} km',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Color(0xFFFFC107)),
                  const SizedBox(width: 4),
                  Text(
                    '${worker['rating']} (${worker['reviewCount']})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tags de servicios
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (worker['services'] as List<String>).map((service) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  service,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF374151),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Botones de acción
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _makePhoneCall(worker['phone']),
                  icon: const Icon(Icons.phone, size: 18),
                  label: const Text('Llamar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navegar a mensajes
                  },
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('Mensaje'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }
}
