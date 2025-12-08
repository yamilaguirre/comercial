import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'dart:io';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../theme/theme.dart';
import 'widgets/profession_selector.dart';
import '../../providers/auth_provider.dart';
import '../../services/image_service.dart';
import '../../services/notification_service.dart';
import '../../models/notification_model.dart';

class FreelanceWorkScreen extends StatefulWidget {
  const FreelanceWorkScreen({super.key});

  @override
  State<FreelanceWorkScreen> createState() => _FreelanceWorkScreenState();
}

class _FreelanceWorkScreenState extends State<FreelanceWorkScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _selectedAvailability = 'Inmediato';
  final List<String> _availabilityOptions = [
    'Inmediato',
    'En 1 semana',
    'No disponible',
  ];

  String _selectedCurrency = 'Bs';
  final List<String> _currencyOptions = ['Bs', '\$'];

  String _selectedLevel = 'Intermedio';
  final List<String> _levelOptions = [
    'Básico',
    'Intermedio',
    'Avanzado',
  ];

  // Almacena las selecciones: Map<categoria, List<subcategorias>>
  final Map<String, List<String>> _selectedProfessions = {};

  // Foto de perfil
  File? _profileImage;
  String? _profileImageUrl;
  bool _isFaceDetected = false;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );

  // Imágenes del portafolio
  final List<File> _portfolioImages = [];
  final List<String> _portfolioUrls = [];

  bool _isLoading = false;
  bool _isNewProfile = true; // Flag para detectar si es la primera vez
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    if (user != null) {
      _nameController.text = user.displayName ?? '';

      // Cargar datos existentes si los hay
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          final profile = data?['profile'] as Map<String, dynamic>?;

          if (profile != null) {
            // Si ya existe perfil, no es nuevo
            _isNewProfile = false;

            setState(() {
              _descriptionController.text = profile['description'] ?? '';
              // Prefer profile specific price, otherwise check root-level price
              _priceController.text =
                  profile['price']?.toString() ??
                  data?['price']?.toString() ??
                  '';

              // Asegurar que availability tenga un valor válido
              final availability = profile['availability'] as String?;
              if (availability != null &&
                  _availabilityOptions.contains(availability)) {
                _selectedAvailability = availability;
              } else {
                _selectedAvailability = 'Inmediato'; // valor por defecto
              }

              // Cargar moneda
              final currency = profile['currency'] as String?;
              if (currency != null && _currencyOptions.contains(currency)) {
                _selectedCurrency = currency;
              }

              // Cargar nivel de experiencia
              final level = profile['experienceLevel'] as String?;
              if (level != null && _levelOptions.contains(level)) {
                _selectedLevel = level;
              }

              _profileImageUrl = profile['photoUrl'];

              // Cargar profesiones seleccionadas
              final professions = profile['professions'] as List<dynamic>?;
              if (professions != null) {
                for (var prof in professions) {
                  final category = prof['category'] as String;
                  final subcategories = (prof['subcategories'] as List<dynamic>)
                      .map((e) => e.toString())
                      .toList();
                  _selectedProfessions[category] = subcategories;
                }
              }

              // Cargar URLs de portafolio
              final portfolio = profile['portfolioImages'] as List<dynamic>?;
              if (portfolio != null) {
                _portfolioUrls.addAll(portfolio.map((e) => e.toString()));
              }
            });
          }
        }
      } catch (e) {
        print('Error cargando datos: $e');
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera, // OBLIGATORIO CÁMARA
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
        });
        await _processProfileImage(InputImage.fromFilePath(image.path), File(image.path));
      }
    } catch (e) {
      _showError('Error al tomar foto: $e');
    }
  }

  Future<void> _processProfileImage(InputImage inputImage, File imageFile) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      setState(() {
        _isLoading = false;
        if (faces.isNotEmpty) {
          _isFaceDetected = true;
          _profileImage = imageFile;
          _showError('Rostro detectado correctamente', isError: false);
        } else {
          _isFaceDetected = false;
          _profileImage = null;
          _showError('No se detectó un rostro claro. Intenta de nuevo');
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFaceDetected = false;
        _profileImage = null;
      });
      _showError('Error al procesar imagen: $e');
    }
  }

  Future<void> _pickPortfolioImage() async {
    if (_portfolioImages.length + _portfolioUrls.length >= 6) {
      _showError('Máximo 6 imágenes de portafolio');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _portfolioImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Error al seleccionar imagen: $e');
    }
  }

  Future<void> _takePhoto() async {
    if (_portfolioImages.length + _portfolioUrls.length >= 6) {
      _showError('Máximo 6 imágenes de portafolio');
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _portfolioImages.add(File(image.path));
        });
      }
    } catch (e) {
      _showError('Error al tomar foto: $e');
    }
  }

  Future<String> _uploadImage(XFile image, String folderPath) async {
    try {
      final url = await ImageService.uploadImageToApi(
        image,
        folderPath: folderPath,
      );
      return url;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProfessions.isEmpty) {
      _showError('Debes seleccionar al menos una profesión');
      return;
    }

    // Validar que tenga foto de perfil con rostro detectado
    if (_profileImage == null && _profileImageUrl == null) {
      _showError('Debes tomar una foto de perfil');
      return;
    }

    if (_profileImage != null && !_isFaceDetected) {
      _showError('La foto de perfil debe mostrar tu rostro claramente');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Subir foto de perfil si hay una nueva
      String? profilePhotoUrl = _profileImageUrl;
      if (_profileImage != null) {
        // Convertir File a XFile para el servicio
        final xFile = XFile(_profileImage!.path);
        profilePhotoUrl = await ImageService.uploadAvatarToApi(
          xFile,
          userId: user.uid,
        );
      }

      // Subir imágenes del portafolio
      final List<String> portfolioUrls = List.from(_portfolioUrls);
      for (int i = 0; i < _portfolioImages.length; i++) {
        // Convertir File a XFile para el servicio
        final xFile = XFile(_portfolioImages[i].path);
        final url = await _uploadImage(xFile, 'worker_portfolio/${user.uid}');
        portfolioUrls.add(url);
      }

      // Preparar estructura de profesiones
      final List<Map<String, dynamic>> professions = [];
      _selectedProfessions.forEach((category, subcategories) {
        if (subcategories.isNotEmpty) {
          professions.add({
            'category': category,
            'subcategories': subcategories,
          });
        }
      });

      // Preparar string representativo de profesion (top-level) para compatibilidad
      String professionTopLevel = '';
      if (professions.isNotEmpty) {
        final List<String> allSubcategories = [];
        for (var p in professions) {
          final subs = p['subcategories'] as List<dynamic>?;
          if (subs != null && subs.isNotEmpty) {
            allSubcategories.addAll(subs.map((e) => e.toString()));
          }
        }
        if (allSubcategories.isNotEmpty) {
          professionTopLevel = allSubcategories.take(2).join(' • ');
        } else {
          professionTopLevel = professions[0]['category'] ?? '';
        }
      }

      final String priceValue = _priceController.text.trim();
      // Guardar en Firestore (asegurar que es string)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'professions': professions,
          'price': priceValue, // String
          'profile': {
            'fullName': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'availability': _selectedAvailability,
            'currency': _selectedCurrency,
            'experienceLevel': _selectedLevel,
            'professions': professions,
            'portfolioImages': portfolioUrls,
            'price': priceValue, // String
            'photoUrl': profilePhotoUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'name': _nameController.text.trim(),
          'photoUrl': profilePhotoUrl,
          'photoURL':
              profilePhotoUrl, // También guardar en photoURL (mayúscula)
          'profession': professionTopLevel,
        },
      );

      // Actualizar también el perfil de Firebase Auth
      if (profilePhotoUrl != null) {
        await user.updatePhotoURL(profilePhotoUrl);
      }
      await user.updateDisplayName(_nameController.text.trim());
      await user.reload();

      // Crear notificación de actualización de perfil
      final notificationService = NotificationService();

      if (_isNewProfile) {
        // Notificación GLOBAL para todos los usuarios (solo la primera vez)
        await notificationService.createSystemMessage(
          title: '¡Nuevo Profesional!',
          message:
              'Un nuevo trabajador llamado ${_nameController.text.trim()} está ofreciendo sus servicios de $professionTopLevel',
          metadata: {'userId': user.uid, 'profession': professionTopLevel},
        );
      } else {
        // Notificación personal de actualización
        await notificationService.createProfileChangeNotification(
          userId: user.uid,
          type:
              NotificationType.profileNameChanged, // Usamos este como genérico
          title: 'Perfil Actualizado',
          message: 'Tu perfil de trabajador ha sido actualizado exitosamente.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil guardado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Navegar después de que termine el frame actual para evitar errores
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Modular.to.navigate('/freelance/home');
          }
        });
      }
    } catch (e) {
      _showError('Error al guardar perfil: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _toggleSubcategory(String category, String subcategory) {
    setState(() {
      if (!_selectedProfessions.containsKey(category)) {
        _selectedProfessions[category] = [];
      }

      final list = _selectedProfessions[category]!;
      if (list.contains(subcategory)) {
        list.remove(subcategory);
      } else {
        list.add(subcategory);
      }

      // Limpiar si está vacía
      if (list.isEmpty) {
        _selectedProfessions.remove(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Crear Perfil Trabajo',
              style: TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Información Personal',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Nombre completo
                  const Text(
                    'Nombre Completo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'Ej: Pedro Perez Gonzales',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es requerido';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Foto de perfil
                  const Text(
                    'Foto de Perfil',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey[200],
                                  border: Border.all(
                                    color: _isFaceDetected
                                        ? Colors.green
                                        : Colors.grey[300]!,
                                    width: 3,
                                  ),
                                  image: _profileImage != null
                                      ? DecorationImage(
                                          image: FileImage(_profileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : _profileImageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_profileImageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                ),
                                child: _profileImage == null &&
                                        _profileImageUrl == null
                                    ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              // Botón de cámara
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Styles.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              // Badge de verificación si el rostro fue detectado
                              if (_isFaceDetected)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_profileImage != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _isFaceDetected
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _isFaceDetected
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isFaceDetected
                                      ? Icons.verified_user
                                      : Icons.warning_amber,
                                  size: 16,
                                  color: _isFaceDetected
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isFaceDetected
                                      ? 'Rostro verificado'
                                      : 'Rostro no detectado',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _isFaceDetected
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_profileImage == null && _profileImageUrl == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Toca para tomar una foto',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Descripción personal
                  const Text(
                    'Descripción Personal',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText:
                          'Ej: Profesional comprometido, especializado en [tu especialidad], con enfoque en calidad y puntualidad en cada proyecto.',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La descripción es requerida';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Disponibilidad
                  const Text(
                    'Disponibilidad',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Styles.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAvailability,
                        isExpanded: true,
                        dropdownColor: Styles.primaryColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        items: _availabilityOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedAvailability = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Profesión
                  const Text(
                    'Profesión',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selector de Profesiones (refactorizado a widget)
                  ProfessionSelector(
                    selectedProfessions: _selectedProfessions,
                    onToggleSubcategory: _toggleSubcategory,
                  ),

                  const SizedBox(height: 24),

                  // Precio (Desde) con selector de moneda
                  const Text(
                    'Precio (Desde)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de moneda
                      Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: Styles.primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            isExpanded: true,
                            dropdownColor: Styles.primaryColor,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.white,
                              size: 20,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _currencyOptions.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedCurrency = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Campo de precio
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          maxLength: 7,
                          decoration: InputDecoration(
                            hintText: 'Ej: 150',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            counterText: '',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El precio es requerido';
                            }
                            final num? parsed = num.tryParse(
                              value.replaceAll(',', '.'),
                            );
                            if (parsed == null || parsed <= 0) {
                              return 'Ingresa un precio válido mayor que 0';
                            }
                            if (parsed > 9999999) {
                              return 'El precio máximo es 9,999,999';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Nivel de Experiencia
                  const Text(
                    'Nivel de Experiencia',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Styles.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedLevel,
                        isExpanded: true,
                        dropdownColor: Styles.primaryColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        items: _levelOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedLevel = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Subir fotos portafolio (Opcional)
                  Row(
                    children: [
                      const Text(
                        'Subir Fotos Portafolio',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Opcional',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Botones para agregar imágenes - Diseño tipo card
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _pickPortfolioImage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_outlined,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Subir imágenes',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _takePhoto,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_outlined,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Tomar foto',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Mostrar imágenes del portafolio subidas
                  if (_portfolioImages.isNotEmpty ||
                      _portfolioUrls.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Imágenes existentes (URLs)
                        ..._portfolioUrls.asMap().entries.map((entry) {
                          final index = entry.key;
                          final url = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(url),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _portfolioUrls.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                        // Imágenes nuevas (archivos locales)
                        ..._portfolioImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: FileImage(file),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _portfolioImages.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Botones inferiores fijos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Modular.to.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Atrás'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Styles.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('Continuar'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
