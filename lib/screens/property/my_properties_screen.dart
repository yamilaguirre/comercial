import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/mobiliaria_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/property.dart';
import '../../theme/theme.dart';
// Corregido: Importación unificada a core/utils/
import '../../core/utils/property_constants.dart';

// La clase principal se llama MyPropertiesScreen y se encarga de listar.
class MyPropertiesScreen extends StatefulWidget {
  const MyPropertiesScreen({super.key});

  @override
  State<MyPropertiesScreen> createState() => _MyPropertiesScreenState();
}

class _MyPropertiesScreenState extends State<MyPropertiesScreen> {
  // ALMACENA EL FUTURE: Se crea una sola vez para evitar recargas constantes.
  late Future<List<Property>> _propertiesFuture;

  @override
  void initState() {
    super.initState();
    // Inicializar el Future la primera vez
    _propertiesFuture = _fetchData();
  }

  // Función para obtener los datos desde el Provider
  Future<List<Property>> _fetchData() {
    // Usamos read para que este método no fuerce un rebuild innecesario de la pantalla
    return context.read<MobiliariaProvider>().fetchUserProperties();
  }

  // Navega a la pantalla de edición, pasando el objeto Property.
  void _editProperty(Property property) {
    context.push('/property/edit/${property.id}', extra: property);
  }

  // Llama al provider para eliminar una propiedad y actualiza la UI.
  void _deleteProperty(String propertyId) async {
    final success = await Provider.of<MobiliariaProvider>(
      context,
      listen: false,
    ).deleteProperty(propertyId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Propiedad eliminada con éxito.'),
            backgroundColor: Styles.successColor,
          ),
        );
        // FORZAMOS LA RECARGA: Reemplazamos el Future para que el FutureBuilder se actualice
        setState(() {
          _propertiesFuture = _fetchData();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<MobiliariaProvider>(
                    context,
                    listen: false,
                  ).errorMessage ??
                  'Error al eliminar.',
            ),
            backgroundColor: Styles.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // El provider se usa solo para el estado de carga y mensajes de error
    final mobiliariaProvider = context.watch<MobiliariaProvider>();

    return Scaffold(
      // Fondo de la app consistente
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          'Mis Publicaciones',
          style: TextStyles.subtitle.copyWith(
            color: Styles.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Styles.textPrimary),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.go('/account'), // Volver a la cuenta
        ),
      ),
      body: FutureBuilder<List<Property>>(
        future: _propertiesFuture, // Usamos el Future guardado
        builder: (context, snapshot) {
          // El FutureBuilder maneja la espera y los errores
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Styles.primaryColor),
            );
          }

          // Manejo de error directo del Future
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Styles.errorColor,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Error al cargar: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyles.body.copyWith(color: Styles.errorColor),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Verifica si necesitas un índice compuesto en Firestore para la combinación de "owner_id" y "created_at".',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () =>
                          setState(() => _propertiesFuture = _fetchData()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.infoColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Intentar de nuevo'),
                    ),
                  ],
                ),
              ),
            );
          }

          final userProperties = snapshot.data ?? [];

          if (userProperties.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.house_siding, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 20),
                  Text(
                    'Aún no tienes propiedades publicadas.',
                    style: TextStyles.body.copyWith(color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/property/new'),
                    icon: const Icon(Icons.add_home_work),
                    label: const Text('Publicar Ahora'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Styles.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(Styles.spacingMedium),
            itemCount: userProperties.length,
            itemBuilder: (context, index) {
              final property = userProperties[index];
              return _buildPropertyItem(property, context);
            },
          );
        },
      ),
      // Botón flotante para añadir propiedad
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/property/new'),
        backgroundColor: Styles.primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  // Construye cada ítem de la lista de propiedades
  Widget _buildPropertyItem(Property property, BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: Styles.spacingMedium),
      elevation: 4,
      // Borde redondeado de la tarjeta consistente
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () =>
            context.push('/property-detail/${property.id}', extra: property),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  property.imageUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              SizedBox(width: Styles.spacingMedium),

              // Detalles
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      property.name,
                      style: TextStyles.body.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Styles.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${property.price} (${PropertyConstants.getTransactionTitle(property.type)})',
                      style: TextStyles.body.copyWith(
                        color: Styles.primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.location,
                      style: TextStyles.caption.copyWith(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // Acciones (Editar/Eliminar)
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    // Contenedor para el botón de edición
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.blue,
                        size: 20,
                      ),
                      onPressed: () => _editProperty(property),
                    ),
                  ),
                  Container(
                    // Contenedor para el botón de eliminar
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                        size: 20,
                      ),
                      onPressed: () => _showDeleteConfirmation(
                        context,
                        property.id,
                        property.name,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Muestra un diálogo de confirmación antes de eliminar
  void _showDeleteConfirmation(
    BuildContext context,
    String propertyId,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Publicación'),
        content: Text(
          '¿Estás seguro de que quieres eliminar la propiedad "$name"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Styles.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProperty(propertyId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
