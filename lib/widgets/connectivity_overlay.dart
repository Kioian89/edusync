import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/connectivity_provider.dart';

class ConnectivityOverlay extends StatelessWidget {
  final Widget? child;
  const ConnectivityOverlay({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityProvider>();

    final isOffline = !connectivity.isOnline;
    final showBackOnline = connectivity.showBackOnlineBanner;
    final showBanner = isOffline || showBackOnline;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          ?child,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: AnimatedSlide(
                offset: showBanner ? Offset.zero : const Offset(0, -1.2),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: showBanner ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Material(
                      color: Colors.transparent,
                      child: isOffline
                          ? _buildOfflineBanner(context, connectivity)
                          : _buildOnlineBanner(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner(BuildContext context, ConnectivityProvider connectivity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Dark slate
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFEF4444),
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No Internet Connection',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Please connect to Wi-Fi or mobile data to sync.',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: connectivity.isChecking
                ? null
                : () => connectivity.checkConnectivity(),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: connectivity.isChecking
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF064E3B), // Deep emerald
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: const BoxDecoration(
              color: Color(0x3310B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.wifi_rounded,
              color: Color(0xFF34D399),
              size: 17,
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Back Online',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Synchronizing classroom data with Cloud Firestore...',
                  style: TextStyle(
                    color: Color(0xFFA7F3D0),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
