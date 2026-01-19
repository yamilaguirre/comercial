import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/banner_service.dart';

class PromotionalOverlay extends StatefulWidget {
  const PromotionalOverlay({super.key});

  @override
  State<PromotionalOverlay> createState() => _PromotionalOverlayState();
}

class _PromotionalOverlayState extends State<PromotionalOverlay> {
  final BannerService _bannerService = BannerService();
  bool _isVisible = false;
  Timer? _hideTimer;
  Timer? _rotationTimer;
  int _currentBannerIndex = 0;
  List<Map<String, dynamic>> _currentBanners = [];

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _rotationTimer?.cancel();
    super.dispose();
  }

  Future<void> _startSession() async {
    final authService = context.read<AuthService>();
    final user = authService.currentUser;
    bool isPremium = false;

    if (user != null) {
      try {
        final premiumDoc = await FirebaseFirestore.instance
            .collection('premium_users')
            .doc(user.uid)
            .get();
        isPremium =
            premiumDoc.exists && premiumDoc.data()?['status'] == 'active';
      } catch (e) {
        debugPrint('Error checking premium status in overlay: $e');
        isPremium = authService.isPremium; // fallback
      }
    }

    setState(() {
      _isVisible = true;
    });

    final duration = isPremium ? 15 : 20;

    _hideTimer = Timer(Duration(seconds: duration), () {
      if (mounted) {
        setState(() {
          _isVisible = false;
        });
        _rotationTimer?.cancel();
      }
    });

    // Rotation timer every 3 seconds if multiple banners exist
    _rotationTimer = Timer.periodic(const Duration(milliseconds: 3000), (
      timer,
    ) {
      if (_currentBanners.length > 1 && mounted) {
        setState(() {
          _currentBannerIndex =
              (_currentBannerIndex + 1) % _currentBanners.length;
        });
      }
    });
  }

  void _onBannerTap(Map<String, dynamic> bannerData) async {
    final link =
        bannerData['externalLink'] as String? ??
        'https://play.google.com/store/apps/details?id=com.aplicaciones.taxia1';
    final url = Uri.parse(link);

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el enlace')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching banner URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _bannerService.getActiveBannersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        _currentBanners = snapshot.data!;

        // Safety check for index out of bounds if list shrinks
        if (_currentBannerIndex >= _currentBanners.length) {
          _currentBannerIndex = 0;
        }

        final bannerData = _currentBanners[_currentBannerIndex];
        final imageUrl = bannerData['url'] as String?;

        if (imageUrl == null) return const SizedBox.shrink();

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: InkWell(
                onTap: () => _onBannerTap(bannerData),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: Container(
                    key: ValueKey(imageUrl),
                    width: double.infinity,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.fitWidth,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.error_outline,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
