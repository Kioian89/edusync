import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/class_group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../theme/app_theme.dart';

class JoinClassQrScreen extends StatefulWidget {
  const JoinClassQrScreen({super.key});

  @override
  State<JoinClassQrScreen> createState() => _JoinClassQrScreenState();
}

class _JoinClassQrScreenState extends State<JoinClassQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue ?? barcodes.first.displayValue;
    if (raw == null || raw.trim().isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await _processJoinPayload(raw);
    } finally {
      await Future.delayed(const Duration(milliseconds: 1800));
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _extractClassId(String raw) {
    final trimmed = raw.trim();

    // 1. JSON payload check
    if (trimmed.contains('{') && trimmed.contains('}')) {
      try {
        final start = trimmed.indexOf('{');
        final end = trimmed.lastIndexOf('}');
        final jsonStr = trimmed.substring(start, end + 1);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          if (decoded['classId'] != null) {
            return decoded['classId'].toString().trim();
          }
          if (decoded['id'] != null) {
            return decoded['id'].toString().trim();
          }
        }
      } catch (_) {}
    }

    // 2. URI scheme or query check (e.g. edusync://class?id=...)
    if (trimmed.startsWith('edusync://') || trimmed.contains('?')) {
      try {
        final uri = Uri.parse(trimmed);
        final id = uri.queryParameters['id'] ??
            uri.queryParameters['classId'] ??
            uri.pathSegments.lastOrNull;
        if (id != null && id.isNotEmpty) return id.trim();
      } catch (_) {}
    } else if (trimmed.contains('=')) {
      final parts = trimmed.split('&');
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 2) {
          final k = kv[0].trim().toLowerCase();
          final v = kv[1].trim();
          if (k == 'classid' || k == 'id') {
            return v;
          }
        }
      }
    }

    // 3. Plain ID fallback
    return trimmed;
  }

  Future<void> _processJoinPayload(String raw) async {
    final auth = context.read<AuthProvider>();
    final activity = context.read<ActivityProvider>();
    final user = auth.currentUser;

    if (user == null) {
      _showError('You must be signed in to join a class.');
      return;
    }

    // Auto-discover class if QR code has full class metadata (supports cross-device & offline enrollment)
    final trimmed = raw.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        final cid = (decoded['classId'] ?? decoded['id'])?.toString().trim();
        if (cid != null && cid.isNotEmpty) {
          final cls = ClassGroup(
            id: cid,
            name: decoded['name']?.toString() ?? decoded['subject']?.toString() ?? 'Subject',
            subject: decoded['subject']?.toString() ?? decoded['name']?.toString() ?? 'Subject',
            section: decoded['section']?.toString() ?? '',
            teacherId: decoded['teacherId']?.toString() ?? '',
            studentIds: [],
          );
          auth.registerLocalClass(cls);
        }
      } catch (_) {}
    }

    final classId = _extractClassId(raw);
    if (classId.isEmpty) {
      _showError('Invalid QR Code. Please scan a valid EduSync class QR code.');
      return;
    }

    final err = await auth.joinClassByStudent(
      classId: classId,
      studentId: user.id,
    );

    if (!mounted) return;

    if (err != null) {
      _showError(err);
      return;
    }

    // Successfully joined!
    final cls = await auth.fetchClassById(classId);
    final className = cls != null ? cls.displayName : 'the class';

    // Sync activities for the enrolled class
    await activity.onStudentEnrolled(
      classId: classId,
      studentId: user.id,
      studentName: user.name,
    );
    activity.syncWithFirestore(
      userId: user.id,
      isTeacher: false,
      classIds: [classId],
    );

    if (!mounted) return;

    // Show celebration dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.statusGraded.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.statusGraded,
                size: 46,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Enrolled Successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have joined $className. Your activities and announcements are now synced!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context, true); // Close scanner & return
                },
                child: const Text(
                  'Go to My Class',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.statusPending,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Enter Class Join Code',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Paste or type the Join Code provided by your teacher:',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: textController,
                    decoration: InputDecoration(
                      hintText: 'e.g. 8f4e2c81-81d7-463e...',
                      labelText: 'Class ID / Join Code',
                      prefixIcon: const Icon(Icons.vpn_key_rounded,
                          color: AppTheme.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Please enter a code' : null,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final code = textController.text.trim();
                        Navigator.pop(ctx); // Close sheet
                        await _processJoinPayload(code);
                      },
                      child: const Text(
                        'Join Class',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.videocam_off_rounded,
                            color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Unavailable',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Camera is unavailable or permission is needed.\nYou can enter your class Join Code manually below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showManualEntryDialog,
                        icon: const Icon(Icons.keyboard_rounded, size: 18),
                        label: const Text('Enter Join Code'),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Dark vignette overlay with square cutout
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: ShapeDecoration(
                  shape: QrScannerOverlayShape(
                    borderColor: AppTheme.primary,
                    borderRadius: 24,
                    borderLength: 36,
                    borderWidth: 6,
                    cutOutSize: 260,
                  ),
                ),
              ),
            ),
          ),

          // Processing Indicator
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // Top Header & Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black45,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Scan Class QR Code',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                        ),
                        icon: ValueListenableBuilder<MobileScannerState>(
                          valueListenable: _scannerController,
                          builder: (context, state, child) {
                            final isTorchOn = state.torchState == TorchState.on;
                            return Icon(
                              isTorchOn
                                  ? Icons.flash_on_rounded
                                  : Icons.flash_off_rounded,
                              color: isTorchOn ? Colors.amber : Colors.white,
                              size: 20,
                            );
                          },
                        ),
                        onPressed: () => _scannerController.toggleTorch(),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.flip_camera_ios_rounded,
                            size: 20),
                        onPressed: () => _scannerController.switchCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction card & manual button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87, Colors.black],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Point camera at the QR code displayed on your teacher\'s screen',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54, width: 1.5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _showManualEntryDialog,
                      icon: const Icon(Icons.keyboard_rounded, size: 18),
                      label: const Text(
                        'Enter Join Code Manually',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper shape for rounded square cutout overlay
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.blue,
    this.borderWidth = 4.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 16,
    this.borderLength = 32,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path();

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final path = Path()..addRect(rect);
    final center = rect.center;
    final cutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );
    final cutRRect = RRect.fromRectAndRadius(cutRect, Radius.circular(borderRadius));
    return Path.combine(PathOperation.difference, path, Path()..addRRect(cutRRect));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = cutOutSize;
    final height = cutOutSize;
    final center = rect.center;
    final left = center.dx - width / 2;
    final top = center.dy - height / 2;
    final right = left + width;
    final bottom = top + height;

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Corner lines
    // Top-left
    canvas.drawLine(Offset(left, top + borderLength), Offset(left, top + borderRadius), paint);
    canvas.drawArc(Rect.fromLTWH(left, top, borderRadius * 2, borderRadius * 2), 3.14159, 1.57079, false, paint);
    canvas.drawLine(Offset(left + borderRadius, top), Offset(left + borderLength, top), paint);

    // Top-right
    canvas.drawLine(Offset(right - borderLength, top), Offset(right - borderRadius, top), paint);
    canvas.drawArc(Rect.fromLTWH(right - borderRadius * 2, top, borderRadius * 2, borderRadius * 2), -1.57079, 1.57079, false, paint);
    canvas.drawLine(Offset(right, top + borderRadius), Offset(right, top + borderLength), paint);

    // Bottom-left
    canvas.drawLine(Offset(left, bottom - borderLength), Offset(left, bottom - borderRadius), paint);
    canvas.drawArc(Rect.fromLTWH(left, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2), 1.57079, 1.57079, false, paint);
    canvas.drawLine(Offset(left + borderRadius, bottom), Offset(left + borderLength, bottom), paint);

    // Bottom-right
    canvas.drawLine(Offset(right - borderLength, bottom), Offset(right - borderRadius, bottom), paint);
    canvas.drawArc(Rect.fromLTWH(right - borderRadius * 2, bottom - borderRadius * 2, borderRadius * 2, borderRadius * 2), 0, 1.57079, false, paint);
    canvas.drawLine(Offset(right, bottom - borderRadius), Offset(right, bottom - borderLength), paint);
  }

  @override
  ShapeBorder scale(double t) => this;
}
