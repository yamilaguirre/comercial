import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/theme.dart';
import '../../services/image_service.dart';

class PropertyVerificationScreen extends StatefulWidget {
  const PropertyVerificationScreen({super.key});

  @override
  State<PropertyVerificationScreen> createState() =>
      _PropertyVerificationScreenState();
}

class _PropertyVerificationScreenState
    extends State<PropertyVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  File? _ciFront;
  File? _ciBack;

  String? _ciFrontUrl;
  String? _ciBackUrl;

  String _status = 'unverified';
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final requestDoc = await FirebaseFirestore.instance
            .collection('verified_request')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _status = userData['verificationStatus'] ?? 'unverified';

            if (requestDoc.exists) {
              final requestData = requestDoc.data() as Map<String, dynamic>;
              _rejectionReason = requestData['rejectionReason'];
              _ciFrontUrl = requestData['ciFrontUrl'];
              _ciBackUrl = requestData['ciBackUrl'];
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading verification status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        setState(() {
          switch (type) {
            case 'ciFront':
              _ciFront = File(image.path);
              break;
            case 'ciBack':
              _ciBack = File(image.path);
              break;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<String?> _uploadFile(File file, String folderPath) async {
    try {
      final xFile = XFile(file.path);
      return await ImageService.uploadImageToApi(xFile, folderPath: folderPath);
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _submitVerification() async {
    if ((_ciFront == null && _ciFrontUrl == null) ||
        (_ciBack == null && _ciBackUrl == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor sube el CI anverso y reverso'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      if (user == null) return;

      final ciFrontUrl = _ciFront != null
          ? await _uploadFile(_ciFront!, 'verification/${user.uid}')
          : _ciFrontUrl;
      final ciBackUrl = _ciBack != null
          ? await _uploadFile(_ciBack!, 'verification/${user.uid}')
          : _ciBackUrl;

      if (ciFrontUrl == null || ciBackUrl == null) {
        throw Exception('Error al subir las imágenes del CI');
      }

      await FirebaseFirestore.instance
          .collection('verified_request')
          .doc(user.uid)
          .set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName,
            'status': 'pending',
            'submittedAt': FieldValue.serverTimestamp(),
            'ciFrontUrl': ciFrontUrl,
            'ciBackUrl': ciBackUrl,
          });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'verificationStatus': 'pending',
            'verificationSubmittedAt': FieldValue.serverTimestamp(),
          });

      setState(() {
        _status = 'pending';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud enviada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar solicitud: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          onPressed: () => Modular.to.pop(),
        ),
        title: const Text(
          'Verificación de Cuenta',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_status == 'verified') ...[ _buildStatusCard(
                      icon: Icons.check_circle,
                      color: Colors.green,
                      title: '¡Ya estás verificado!',
                      message:
                          'Tu cuenta ha sido verificada exitosamente. Ahora tienes la insignia de verificado en tu perfil.',
                    ),
                  ] else if (_status == 'pending') ...[
                    _buildStatusCard(
                      icon: Icons.access_time_filled,
                      color: Colors.orange,
                      title: 'Verificación en proceso',
                      message:
                          'Hemos recibido tus documentos y los estamos revisando. Te notificaremos cuando haya una actualización.',
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Documentos enviados:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildImagePreview('CI Anverso', _ciFrontUrl, null),
                    _buildImagePreview('CI Reverso', _ciBackUrl, null),
                  ] else ...[
                    if (_status == 'rejected')
                      _buildStatusCard(
                        icon: Icons.error,
                        color: Colors.red,
                        title: 'Solicitud rechazada',
                        message:
                            _rejectionReason ??
                            'Tus documentos no cumplen con los requisitos. Por favor intenta nuevamente.',
                      ),

                    const Text(
                      'Sube tu documento de identidad (CI) para verificar tu cuenta y obtener la insignia de verificado.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Documento de Identidad (CI)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildImageUpload(
                            'Anverso',
                            'ciFront',
                            _ciFront,
                            _ciFrontUrl,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildImageUpload(
                            'Reverso',
                            'ciBack',
                            _ciBack,
                            _ciBackUrl,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitVerification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Styles.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Enviar Solicitud',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageUpload(String label, String type, File? file, String? url) {
    return GestureDetector(
      onTap: () => _pickImage(type),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          image: file != null
              ? DecorationImage(image: FileImage(file), fit: BoxFit.cover)
              : (url != null
                    ? DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      )
                    : null),
        ),
        child: file == null && url == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildImagePreview(String label, String? url, File? file) {
    if (url == null && file == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: file != null
                    ? FileImage(file)
                    : NetworkImage(url!) as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
