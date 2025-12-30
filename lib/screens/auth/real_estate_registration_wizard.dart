// filepath: lib/screens/auth/real_estate_registration_wizard.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../theme/theme.dart';
import '../../services/image_service.dart';
import 'widgets/real_estate_step1_basic_info.dart';
import 'widgets/real_estate_step2_documents.dart';
import 'widgets/real_estate_step3_contact.dart';

/// Wizard coordinator for real estate registration
/// Manages shared state and navigation between 3 screens
class RealEstateRegistrationWizard extends StatefulWidget {
  const RealEstateRegistrationWizard({super.key});

  @override
  State<RealEstateRegistrationWizard> createState() =>
      _RealEstateRegistrationWizardState();
}

class _RealEstateRegistrationWizardState
    extends State<RealEstateRegistrationWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // ============ Step 1: Basic Info ============
  final TextEditingController nameController = TextEditingController();
  File? logoImage;

  // ============ Step 2: Documents ============
  bool isAgent = true; // true = Agente, false = Empresa
  final TextEditingController documentNumberController =
      TextEditingController(); // CI or NIT number
  File? profilePhotoAgent; // For agent with face detection
  bool isFaceDetected = false;
  File? ciAnverso;
  File? ciReverso;
  List<File> nitImages = []; // Up to 5 images for company NIT

  // ============ Step 3: Contact & Credentials ============
  final TextEditingController addressController = TextEditingController();
  final TextEditingController representativeController =
      TextEditingController(); // Only for companies
  List<TextEditingController> phoneControllers = [
    TextEditingController(),
  ]; // Min 1, max 5
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    _pageController.dispose();
    nameController.dispose();
    documentNumberController.dispose();
    addressController.dispose();
    representativeController.dispose();
    for (var controller in phoneControllers) {
      controller.dispose();
    }
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void goToStep(int step) {
    if (step >= 0 && step <= 2) {
      setState(() => _currentStep = step);
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void addPhone() {
    if (phoneControllers.length < 5) {
      setState(() {
        phoneControllers.add(TextEditingController());
      });
    }
  }

  void removePhone(int index) {
    if (phoneControllers.length > 1) {
      setState(() {
        phoneControllers[index].dispose();
        phoneControllers.removeAt(index);
      });
    }
  }

  Future<void> completeRegistration() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Validate email uniqueness
      final emailQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailController.text.trim())
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        setState(() {
          errorMessage = 'Este correo ya está registrado';
          isLoading = false;
        });
        return;
      }

      // Create user with Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final user = userCredential.user;
      if (user == null) throw Exception('No se pudo crear el usuario');

      // Upload logo if exists
      String? logoUrl;
      if (logoImage != null) {
        final xFile = XFile(logoImage!.path);
        logoUrl = await ImageService.uploadImageToApi(
          xFile,
          folderPath: 'real_estate_logos/${user.uid}',
        );
      }

      // Upload documents based on type
      String? profilePhotoUrl;
      String? ciAnversoUrl;
      String? ciReversoUrl;
      List<String> nitUrls = [];

      if (isAgent) {
        // Upload agent photo with face
        if (profilePhotoAgent != null) {
          final xFile = XFile(profilePhotoAgent!.path);
          profilePhotoUrl = await ImageService.uploadImageToApi(
            xFile,
            folderPath: 'real_estate_agents/${user.uid}',
          );
        }

        // Upload CI documents
        if (ciAnverso != null) {
          final xFile = XFile(ciAnverso!.path);
          ciAnversoUrl = await ImageService.uploadImageToApi(
            xFile,
            folderPath: 'real_estate_documents/${user.uid}',
          );
        }
        if (ciReverso != null) {
          final xFile = XFile(ciReverso!.path);
          ciReversoUrl = await ImageService.uploadImageToApi(
            xFile,
            folderPath: 'real_estate_documents/${user.uid}',
          );
        }
      } else {
        // Upload NIT images for company
        for (int i = 0; i < nitImages.length; i++) {
          final xFile = XFile(nitImages[i].path);
          final url = await ImageService.uploadImageToApi(
            xFile,
            folderPath: 'real_estate_documents/${user.uid}/nit',
          );
          if (url != null) nitUrls.add(url);
        }
      }

      // Collect phone numbers
      final phones = phoneControllers
          .map((c) => c.text.trim())
          .where((p) => p.isNotEmpty)
          .toList();

      // Create Firestore document
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': emailController.text.trim(),
        'displayName': nameController.text.trim(),
        'role': 'inmobiliaria_empresa',
        'status': 'inmobiliaria_empresa',
        'isAgent': isAgent,
        'companyName': nameController.text.trim(),
        'companyLogo': logoUrl,
        'photoURL': isAgent ? profilePhotoUrl : logoUrl,
        'documentNumber': documentNumberController.text.trim(),
        'address': addressController.text.trim(),
        'representativeName': isAgent
            ? null
            : representativeController.text.trim(),
        'phoneNumbers': phones,
        'ciAnverso': isAgent ? ciAnversoUrl : null,
        'ciReverso': isAgent ? ciReversoUrl : null,
        'nitDocuments': isAgent ? null : nitUrls,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
        'verificationStatus': 'pending',
      });

      // Sign out and redirect to login
      await FirebaseAuth.instance.signOut();

      if (mounted) {
        Modular.to.navigate('/inmobiliaria-login');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'email-already-in-use') {
          errorMessage = 'Este correo ya está registrado';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'El formato del correo no es válido';
        } else if (e.code == 'weak-password') {
          errorMessage =
              'La contraseña es muy débil. Usa al menos 6 caracteres';
        } else {
          errorMessage = 'Error al crear la cuenta: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Error inesperado: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          if (_currentStep > 0) {
            goToStep(_currentStep - 1);
          } else {
            Modular.to.navigate('/inmobiliaria-login');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Styles.textPrimary),
            onPressed: () {
              if (_currentStep > 0) {
                goToStep(_currentStep - 1);
              } else {
                Modular.to.navigate('/inmobiliaria-login');
              }
            },
          ),
          title: Text(
            'Registro Inmobiliario',
            style: TextStyles.subtitle.copyWith(
              color: Styles.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Column(
          children: [
            // Step indicator
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                children: [
                  _buildStep1BasicInfo(),
                  _buildStep2Documents(),
                  _buildStep3Contact(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepDot(0, 'Info'),
          _buildStepLine(0),
          _buildStepDot(1, 'Docs'),
          _buildStepLine(1),
          _buildStepDot(2, 'Contacto'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive || isCompleted
                ? Styles.primaryColor
                : Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '${step + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? Styles.primaryColor : Colors.grey[600],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      color: isCompleted ? Styles.primaryColor : Colors.grey[300],
    );
  }

  Widget _buildStep1BasicInfo() {
    return RealEstateStep1BasicInfo(
      nameController: nameController,
      logoImage: logoImage,
      onLogoChanged: (file) => setState(() => logoImage = file),
      onNext: () => goToStep(1),
    );
  }

  Widget _buildStep2Documents() {
    return RealEstateStep2Documents(
      isAgent: isAgent,
      onTypeChanged: (agent) => setState(() => isAgent = agent),
      documentNumberController: documentNumberController,
      profilePhotoAgent: profilePhotoAgent,
      isFaceDetected: isFaceDetected,
      onProfilePhotoChanged: (file, faceDetected) => setState(() {
        profilePhotoAgent = file;
        isFaceDetected = faceDetected;
      }),
      ciAnverso: ciAnverso,
      onCiAnversoChanged: (file) => setState(() => ciAnverso = file),
      ciReverso: ciReverso,
      onCiReversoChanged: (file) => setState(() => ciReverso = file),
      nitImages: nitImages,
      onNitImagesChanged: (files) => setState(() => nitImages = files),
      onNext: () => goToStep(2),
      onBack: () => goToStep(0),
    );
  }

  Widget _buildStep3Contact() {
    return RealEstateStep3Contact(
      isAgent: isAgent,
      addressController: addressController,
      representativeController: representativeController,
      phoneControllers: phoneControllers,
      onAddPhone: addPhone,
      onRemovePhone: removePhone,
      emailController: emailController,
      passwordController: passwordController,
      confirmPasswordController: confirmPasswordController,
      isLoading: isLoading,
      errorMessage: errorMessage,
      onSubmit: completeRegistration,
      onBack: () => goToStep(1),
    );
  }
}
