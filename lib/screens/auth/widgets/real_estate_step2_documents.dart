// filepath: lib/screens/auth/widgets/real_estate_step2_documents.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../../theme/theme.dart';

class RealEstateStep2Documents extends StatefulWidget {
  final bool isAgent;
  final Function(bool) onTypeChanged;
  final TextEditingController documentNumberController;
  final File? profilePhotoAgent;
  final bool isFaceDetected;
  final Function(File?, bool) onProfilePhotoChanged;
  final File? ciAnverso;
  final Function(File?) onCiAnversoChanged;
  final File? ciReverso;
  final Function(File?) onCiReversoChanged;
  final List<File> nitImages;
  final Function(List<File>) onNitImagesChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const RealEstateStep2Documents({
    super.key,
    required this.isAgent,
    required this.onTypeChanged,
    required this.documentNumberController,
    required this.profilePhotoAgent,
    required this.isFaceDetected,
    required this.onProfilePhotoChanged,
    required this.ciAnverso,
    required this.onCiAnversoChanged,
    required this.ciReverso,
    required this.onCiReversoChanged,
    required this.nitImages,
    required this.onNitImagesChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<RealEstateStep2Documents> createState() =>
      _RealEstateStep2DocumentsState();
}

class _RealEstateStep2DocumentsState extends State<RealEstateStep2Documents> {
  final ImagePicker _picker = ImagePicker();
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
    ),
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _takeCameraPhoto() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() => _isProcessing = true);
        final file = File(pickedFile.path);
        await _processImageForFace(file);
      }
    } catch (e) {
      _showSnackBar('Error al tomar foto: $e', isError: true);
    }
  }

  Future<void> _processImageForFace(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final List<Face> faces = await _faceDetector.processImage(inputImage);

      setState(() => _isProcessing = false);

      if (faces.isNotEmpty) {
        widget.onProfilePhotoChanged(imageFile, true);
        _showSnackBar('Rostro detectado correctamente', isError: false);
      } else {
        widget.onProfilePhotoChanged(null, false);
        _showSnackBar(
          'No se detectó un rostro claro. Intenta de nuevo.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      widget.onProfilePhotoChanged(null, false);
      _showSnackBar('Error al procesar imagen: $e', isError: true);
    }
  }

  Future<void> _pickDocument(Function(File?) onChanged) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        onChanged(File(pickedFile.path));
      }
    } catch (e) {
      _showSnackBar('Error al seleccionar documento: $e', isError: true);
    }
  }

  Future<void> _addNitImage() async {
    if (widget.nitImages.length >= 5) {
      _showSnackBar('Máximo 5 imágenes del NIT', isError: true);
      return;
    }

    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        final newList = List<File>.from(widget.nitImages)
          ..add(File(pickedFile.path));
        widget.onNitImagesChanged(newList);
      }
    } catch (e) {
      _showSnackBar('Error al agregar imagen: $e', isError: true);
    }
  }

  void _removeNitImage(int index) {
    final newList = List<File>.from(widget.nitImages)..removeAt(index);
    widget.onNitImagesChanged(newList);
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  bool _canProceed() {
    final hasDocumentNumber = widget.documentNumberController.text
        .trim()
        .isNotEmpty;
    if (widget.isAgent) {
      return hasDocumentNumber &&
          widget.isFaceDetected &&
          widget.profilePhotoAgent != null &&
          widget.ciAnverso != null &&
          widget.ciReverso != null;
    } else {
      return hasDocumentNumber && widget.nitImages.isNotEmpty;
    }
  }

  void _handleNext() {
    if (!_canProceed()) {
      String message = widget.isAgent
          ? 'Debes completar: número de CI, foto con rostro, CI anverso y reverso'
          : 'Debes ingresar el número de NIT y subir al menos una imagen';
      _showSnackBar(message, isError: true);
      return;
    }
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(Styles.spacingLarge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Documentación',
            style: TextStyles.title.copyWith(
              color: Styles.primaryColor,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sube los documentos requeridos',
            style: TextStyles.body.copyWith(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: Styles.spacingLarge),

          // Agent/Company Switch
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.isAgent
                        ? 'Agente Inmobiliario'
                        : 'Empresa Inmobiliaria',
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Styles.textPrimary,
                    ),
                  ),
                ),
                Switch(
                  value: !widget.isAgent,
                  onChanged: (value) => widget.onTypeChanged(!value),
                  activeColor: Styles.primaryColor,
                ),
              ],
            ),
          ),
          SizedBox(height: Styles.spacingLarge * 1.5),

          // Document Number Field
          Text(
            widget.isAgent ? 'Número de CI' : 'Número de NIT',
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              color: Styles.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: widget.documentNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: widget.isAgent
                  ? 'Ingresa tu número de CI'
                  : 'Ingresa el número de NIT',
              prefixIcon: const Icon(Icons.badge),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Styles.primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
          SizedBox(height: Styles.spacingLarge * 1.5),

          // Conditional content based on type
          if (widget.isAgent)
            ..._buildAgentFields()
          else
            ..._buildCompanyFields(),

          SizedBox(height: Styles.spacingLarge * 2),

          // Navigation buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: Styles.primaryColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Atrás',
                        style: TextStyles.button.copyWith(
                          color: Styles.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _handleNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Styles.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Siguiente',
                        style: TextStyles.button.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildAgentFields() {
    return [
      // Profile photo with face detection
      Text(
        'Foto de Perfil (con detección de rostro)',
        style: TextStyles.subtitle.copyWith(
          fontWeight: FontWeight.bold,
          color: Styles.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: GestureDetector(
          onTap: _isProcessing ? null : _takeCameraPhoto,
          child: Stack(
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.isFaceDetected
                        ? Colors.green
                        : widget.profilePhotoAgent != null
                        ? Colors.orange
                        : Colors.grey[400]!,
                    width: 3,
                  ),
                ),
                child: _isProcessing
                    ? const Center(child: CircularProgressIndicator())
                    : widget.profilePhotoAgent != null
                    ? ClipOval(
                        child: Image.file(
                          widget.profilePhotoAgent!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size: 50,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tomar Foto',
                            style: TextStyles.caption.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
              ),
              if (widget.isFaceDetected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (widget.profilePhotoAgent != null && !widget.isFaceDetected)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'No se detectó rostro en la imagen',
            style: TextStyles.caption.copyWith(color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        ),
      SizedBox(height: Styles.spacingLarge),

      // CI documents
      Text(
        'Cédula de Identidad',
        style: TextStyles.subtitle.copyWith(
          fontWeight: FontWeight.bold,
          color: Styles.textPrimary,
        ),
      ),
      const SizedBox(height: 12),
      _buildDocumentCard(
        label: 'CI Anverso (Frontal)',
        icon: Icons.badge,
        image: widget.ciAnverso,
        onTap: () => _pickDocument(widget.onCiAnversoChanged),
      ),
      const SizedBox(height: 12),
      _buildDocumentCard(
        label: 'CI Reverso (Posterior)',
        icon: Icons.badge,
        image: widget.ciReverso,
        onTap: () => _pickDocument(widget.onCiReversoChanged),
      ),
    ];
  }

  List<Widget> _buildCompanyFields() {
    return [
      // NIT documents
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Documentos NIT',
            style: TextStyles.subtitle.copyWith(
              fontWeight: FontWeight.bold,
              color: Styles.textPrimary,
            ),
          ),
          Text(
            '${widget.nitImages.length}/5',
            style: TextStyles.caption.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      const SizedBox(height: 12),

      // NIT images grid
      if (widget.nitImages.isEmpty)
        _buildAddNitButton()
      else
        Column(
          children: [
            ...widget.nitImages.asMap().entries.map((entry) {
              final index = entry.key;
              final file = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildNitImageCard(file, index),
              );
            }),
            if (widget.nitImages.length < 5) _buildAddNitButton(),
          ],
        ),
    ];
  }

  Widget _buildDocumentCard({
    required String label,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: image != null ? Styles.primaryColor : Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: image != null
                    ? Styles.primaryColor.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: image != null ? Styles.primaryColor : Colors.grey[600],
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Styles.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    image != null ? 'Documento cargado' : 'Toca para subir',
                    style: TextStyles.caption.copyWith(
                      color: image != null ? Colors.green : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (image != null)
              const Icon(Icons.check_circle, color: Colors.green, size: 24)
            else
              Icon(Icons.cloud_upload, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNitImageCard(File image, int index) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Styles.primaryColor),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: Image.file(
              image,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIT - Imagen ${index + 1}',
                    style: TextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Documento cargado',
                    style: TextStyles.caption.copyWith(color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _removeNitImage(index),
            icon: const Icon(Icons.delete, color: Colors.red),
          ),
        ],
      ),
    );
  }

  Widget _buildAddNitButton() {
    return InkWell(
      onTap: _addNitImage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey[300]!,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, color: Colors.grey[600], size: 28),
            const SizedBox(width: 12),
            Text(
              'Agregar Imagen del NIT',
              style: TextStyles.body.copyWith(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
