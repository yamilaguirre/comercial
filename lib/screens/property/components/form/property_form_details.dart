import 'package:flutter/material.dart';
import '../../../../theme/theme.dart';

class PropertyFormDetails extends StatelessWidget {
  final TextEditingController roomsController;
  final TextEditingController bathroomsController;
  final TextEditingController areaController;
  final bool isRequired;

  const PropertyFormDetails({
    super.key,
    required this.roomsController,
    required this.bathroomsController,
    required this.areaController,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Características principales',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  if (isRequired) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Obligatorio',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (isRequired)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Las inmobiliarias deben completar todas estas características',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildCharField(
                  controller: roomsController,
                  icon: Icons.bed_outlined,
                  label: 'Habitaciones',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCharField(
                  controller: bathroomsController,
                  icon: Icons.bathtub_outlined,
                  label: 'Baños',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCharField(
                  controller: areaController,
                  icon: Icons.square_foot,
                  label: 'Área (m²)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharField({
    required TextEditingController controller,
    required IconData icon,
    required String label,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Styles.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Styles.primaryColor, size: 28),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '0',
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
