import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdIds {
  static const String androidAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  static String get interstitialUnitId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';
}

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _premiumChecked = false;
  bool _isPremiumUser = false;
  
  // Permite forzar/establecer el estado premium desde la UI (por ejemplo tras un Stream)
  void setPremiumOverride(bool isPremium) {
    _isPremiumUser = isPremium;
    _premiumChecked = true;
  }
  
  // Vuelve a consultar premium en Firestore en caso de cambios sin reiniciar
  Future<void> refreshPremiumStatus() async {
    _premiumChecked = false;
    await _ensurePremiumStatus();
  }

  Future<void> _ensurePremiumStatus() async {
    if (_premiumChecked) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isPremiumUser = false;
        _premiumChecked = true;
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('premium_users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        _isPremiumUser = (data != null && data['status'] == 'active');
      } else {
        _isPremiumUser = false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking premium status: $e');
      }
      _isPremiumUser = false;
    } finally {
      _premiumChecked = true;
    }
  }

  Future<void> preloadInterstitial() async {
    if (_interstitialAd != null || _isLoading) return;
    _isLoading = true;
    await InterstitialAd.load(
      adUnitId: AdIds.interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isLoading = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAd = null;
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('Interstitial failed to load: $error');
          }
        },
      ),
    );
  }

  Future<void> showInterstitialThen(Future<void> Function() action) async {
    await _ensurePremiumStatus();
    if (_isPremiumUser) {
      await action();
      return;
    }
    // If ad is available, show it and run action after dismissal.
    final ad = _interstitialAd;
    if (ad != null) {
      _interstitialAd = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          // Preload the next one
          preloadInterstitial();
          action();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          preloadInterstitial();
          action();
        },
      );
      ad.show();
    } else {
      // No ad ready; run action immediately and try to preload.
      await action();
      preloadInterstitial();
    }
  }
}
