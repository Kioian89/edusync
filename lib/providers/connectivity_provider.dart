import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _isChecking = false;
  bool _wasOffline = false;
  bool _showBackOnlineBanner = false;
  Timer? _pollingTimer;
  Timer? _backOnlineDismissTimer;

  bool get isOnline => _isOnline;
  bool get isChecking => _isChecking;
  bool get showBackOnlineBanner => _showBackOnlineBanner;

  void init() {
    checkConnectivity();
    // Periodically verify internet connectivity every 10 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnectivity();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _backOnlineDismissTimer?.cancel();
    super.dispose();
  }

  Future<bool> checkConnectivity() async {
    if (_isChecking) return _isOnline;
    _isChecking = true;

    bool online = false;

    if (kIsWeb) {
      try {
        final res = await http.get(Uri.parse('https://www.google.com/generate_204'))
            .timeout(const Duration(seconds: 4));
        online = res.statusCode == 204 || res.statusCode == 200;
      } catch (_) {
        online = false;
      }
    } else {
      try {
        // Fast DNS lookup for real internet access
        final result = await InternetAddress.lookup('google.com')
            .timeout(const Duration(seconds: 4));
        online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } on SocketException catch (_) {
        online = false;
      } catch (_) {
        // Secondary fallback check via HTTP ping
        try {
          final res = await http.get(Uri.parse('https://www.google.com/generate_204'))
              .timeout(const Duration(seconds: 3));
          online = res.statusCode == 204 || res.statusCode == 200;
        } catch (_) {
          online = false;
        }
      }
    }

    _isChecking = false;

    if (!online && _isOnline) {
      // Just went offline
      _isOnline = false;
      _wasOffline = true;
      _showBackOnlineBanner = false;
      notifyListeners();
    } else if (online && !_isOnline) {
      // Just came back online
      _isOnline = true;
      if (_wasOffline) {
        _showBackOnlineBanner = true;
        _backOnlineDismissTimer?.cancel();
        _backOnlineDismissTimer = Timer(const Duration(milliseconds: 3200), () {
          _showBackOnlineBanner = false;
          _wasOffline = false;
          notifyListeners();
        });
      }
      notifyListeners();
    }

    return online;
  }
}
