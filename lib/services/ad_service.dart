import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdIds {
  // App IDs Reales
  static const String androidAppId = 'ca-app-pub-3664941551435801~6639103457';
  static const String iosAppId = 'ca-app-pub-3940256099942544~1458002511';

  // Unit IDs Reales (Android)
  static const String whatsappInterstitial =
      'ca-app-pub-3664941551435801/1310717165';
  static const String mapInterstitial =
      'ca-app-pub-3664941551435801/9624127935';

  static String get defaultInterstitialId => Platform.isAndroid
      ? whatsappInterstitial
      : 'ca-app-pub-3940256099942544/4411468910';

  static String get mapInterstitialId => Platform.isAndroid
      ? mapInterstitial
      : 'ca-app-pub-3940256099942544/4411468910';
}

class AdService {
  AdService._();
  static final AdService instance = AdService._();

  final Map<String, InterstitialAd?> _interstitialAds = {};
  final Map<String, bool> _isLoading = {};

  bool _isPremiumUser = false;

  void setPremiumOverride(bool isPremium) {
    _isPremiumUser = isPremium;
  }

  Future<void> refreshPremiumStatus() async {
    await _ensurePremiumStatus();
  }

  Future<void> _ensurePremiumStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _isPremiumUser = false;
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      bool isPremiumInUserDoc = false;
      if (userDoc.exists) {
        final data = userDoc.data();
        final sub = data?['subscriptionStatus'] as Map<String, dynamic>?;
        isPremiumInUserDoc = (sub != null && sub['status'] == 'active');
      }

      final premiumDoc = await FirebaseFirestore.instance
          .collection('premium_users')
          .doc(user.uid)
          .get();

      bool isPremiumInPremiumColl = false;
      if (premiumDoc.exists) {
        final data = premiumDoc.data();
        isPremiumInPremiumColl = (data != null && data['status'] == 'active');
      }

      _isPremiumUser = isPremiumInUserDoc || isPremiumInPremiumColl;
    } catch (e) {
      _isPremiumUser = false;
    }
  }

  Future<void> preloadInterstitial({String? adUnitId}) async {
    final unitId = adUnitId ?? AdIds.defaultInterstitialId;

    if (_interstitialAds[unitId] != null || (_isLoading[unitId] ?? false))
      return;

    _isLoading[unitId] = true;
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAds[unitId] = ad;
          _isLoading[unitId] = false;
        },
        onAdFailedToLoad: (error) {
          _interstitialAds[unitId] = null;
          _isLoading[unitId] = false;
          if (kDebugMode) {
            debugPrint('Interstitial failed to load ($unitId): $error');
          }
        },
      ),
    );
  }

  Future<void> showInterstitialThen(
    Future<void> Function() action, {
    String? adUnitId,
  }) async {
    await _ensurePremiumStatus();
    if (_isPremiumUser) {
      await action();
      return;
    }

    final unitId = adUnitId ?? AdIds.defaultInterstitialId;
    final ad = _interstitialAds[unitId];

    if (ad != null) {
      _interstitialAds[unitId] = null;
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          preloadInterstitial(adUnitId: unitId);
          action();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          preloadInterstitial(adUnitId: unitId);
          action();
        },
      );
      ad.show();
    } else {
      await action();
      preloadInterstitial(adUnitId: unitId);
    }
  }
}
