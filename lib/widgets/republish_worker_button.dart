import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/worker_republish_service.dart';
import 'package:chaski_comercial/services/ad_service.dart';

class RepublishWorkerButton extends StatefulWidget {
  final String userId;
  final bool isPremium;

  const RepublishWorkerButton({
    super.key,
    required this.userId,
    this.isPremium = false,
  });

  @override
  State<RepublishWorkerButton> createState() => _RepublishWorkerButtonState();
}

class _RepublishWorkerButtonState extends State<RepublishWorkerButton> {
  final WorkerRepublishService _republishService = WorkerRepublishService();
  bool _isLoading = false;
  Duration? _timeRemaining;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadTimeRemaining();
    _startCountdownTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemaining != null && _timeRemaining!.inSeconds > 0) {
        if (mounted) {
          setState(() {
            _timeRemaining = Duration(seconds: _timeRemaining!.inSeconds - 1);
          });
        }
      } else {
        // Si llegó a 0, recargar desde Firestore para confirmar
        if (_timeRemaining != null && _timeRemaining!.inSeconds == 0) {
          _loadTimeRemaining();
        }
      }
    });
  }

  Future<void> _loadTimeRemaining() async {
    final time = await _republishService.getTimeUntilNextRepublish(widget.userId);
    if (mounted) {
      setState(() {
        _timeRemaining = time;
      });
    }
  }

  Future<void> _handleRepublish() async {
    setState(() => _isLoading = true);
    bool success = false;
    // Si no es premium, mostrar interstitial antes de re-publicar
    if (widget.isPremium) {
      success = await _republishService.republishWorker(widget.userId);
    } else {
      await AdService.instance.showInterstitialThen(() async {
        success = await _republishService.republishWorker(widget.userId);
      });
    }

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Tu perfil ha sido re-publicado! Ahora apareces al inicio de la lista.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        await _loadTimeRemaining();
      } else {
        final timeRemaining = await _republishService.getTimeUntilNextRepublish(widget.userId);
        if (timeRemaining != null && timeRemaining.inSeconds > 0) {
          final hours = timeRemaining.inHours;
          final minutes = timeRemaining.inMinutes % 60;
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Debes esperar ${hours}h ${minutes}m para volver a re-publicarte',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  String _formatTimeRemaining(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_timeRemaining == null) {
      return const SizedBox.shrink();
    }

    final canRepublish = _timeRemaining!.inSeconds <= 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canRepublish
              ? widget.isPremium
                  ? [const Color(0xFFFF6F00), const Color(0xFFFFC107)]
                  : [const Color(0xFF0033CC), const Color(0xFF1565C0)]
              : [Colors.grey[400]!, Colors.grey[500]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                canRepublish ? Icons.rocket_launch : Icons.schedule,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canRepublish
                          ? '¡Destaca tu perfil!'
                          : 'Próxima re-publicación',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      canRepublish
                          ? 'Re-publica tu perfil para aparecer primero en la lista'
                          : 'Podrás re-publicarte en ${_formatTimeRemaining(_timeRemaining!)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canRepublish) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRepublish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: widget.isPremium
                      ? const Color(0xFFFF6F00)
                      : const Color(0xFF0033CC),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.isPremium
                                ? Color(0xFFFF6F00)
                                : Color(0xFF0033CC),
                          ),
                        ),
                      )
                    : const Text(
                        'Re-publicar ahora',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
