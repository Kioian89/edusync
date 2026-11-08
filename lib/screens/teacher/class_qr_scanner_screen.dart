import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../models/class_group.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/activity_provider.dart';
import '../../theme/app_theme.dart';

class ClassQrScannerScreen extends StatefulWidget {
  final ClassGroup classGroup;
  const ClassQrScannerScreen({super.key, required this.classGroup});

  @override
  State<ClassQrScannerScreen> createState() => _ClassQrScannerScreenState();
}

class _ClassQrScannerScreenState extends State<ClassQrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
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

    await _processPayload(raw);

    // Debounce scanning duplicate quickly
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _processPayload(String raw) async {
    String studentId = raw.trim();
    String? studentName;
    String? studentEmail;

    // Support JSON format payload if present
    if (studentId.contains('{') && studentId.contains('}')) {
      try {
        final start = studentId.indexOf('{');
        final end = studentId.lastIndexOf('}');
        final jsonStr = studentId.substring(start, end + 1);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map) {
          if (decoded['studentId'] != null) {
            studentId = decoded['studentId'].toString().trim();
          } else if (decoded['id'] != null) {
            studentId = decoded['id'].toString().trim();
          }
          if (decoded['name'] != null) {
            studentName = decoded['name'].toString().trim();
          }
          if (decoded['email'] != null) {
            studentEmail = decoded['email'].toString().trim();
          }
        }
      } catch (_) {}
    } else if (studentId.contains('=')) {
      final parts = studentId.split('&');
      for (final part in parts) {
        final kv = part.split('=');
        if (kv.length == 2) {
          final k = kv[0].trim().toLowerCase();
          final v = kv[1].trim();
          if (k == 'studentid' || k == 'id') {
            studentId = v;
          }
        }
      }
    }

    final auth = context.read<AuthProvider>();
    final activity = context.read<ActivityProvider>();

    if (studentName != null) {
      auth.registerLocalStudent(
        User(
          id: studentId,
          name: studentName,
          email: studentEmail ?? '$studentId@edusync.internal',
          role: UserRole.student,
        ),
      );
    }

    final err = await auth.addStudentToClass(
      classId: widget.classGroup.id,
      studentId: studentId,
    );

    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(err, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
          backgroundColor: AppTheme.statusPending,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } else {
      final student = auth.users.where((u) => u.id == studentId).firstOrNull ??
          User(
            id: studentId,
            name: studentName ?? 'Student ($studentId)',
            email: studentEmail ?? '$studentId@edusync.internal',
            role: UserRole.student,
          );

      // Auto-populate submissions for any existing activities
      await activity.onStudentEnrolled(
        classId: widget.classGroup.id,
        studentId: student.id,
        studentName: student.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enrolled "${student.name}" into ${widget.classGroup.displayName}!',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.statusGraded,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  void _showManualEnrollDialog() {
    final auth = context.read<AuthProvider>();
    final students = auth.users.where((u) => u.role.name == 'student').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
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
                'Manual Student Select',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a student to simulate or manually scan them into this class:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 250,
                child: ListView.separated(
                  itemCount: students.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, idx) {
                    final s = students[idx];
                    final isEnrolled = widget.classGroup.studentIds.contains(s.id);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppTheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        s.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      subtitle: Text(
                        s.email,
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                      trailing: isEnrolled
                          ? const Text(
                              'Enrolled',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.statusGraded,
                              ),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _processPayload(s.id);
                              },
                              child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                            ),
                    );
                  },
                ),
              ),
            ],
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
          // Camera / Scanner View
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
                        child: const Icon(Icons.videocam_off_rounded, color: Colors.white, size: 40),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Camera Simulation / Unavailable',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Desktop or non-camera environment detected.\nTap below to manually select or auto-add students.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showManualEnrollDialog,
                        icon: const Icon(Icons.touch_app_rounded, size: 18),
                        label: const Text('Select Student'),
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Scanning Target Overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryLight, width: 3),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 3),
                          left: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.white, width: 3),
                          right: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 3),
                          left: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.white, width: 3),
                          right: BorderSide(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ),
                  if (_isProcessing)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                ],
              ),
            ),
          ),

          // Top Header Bar
          Positioned(
            top: 48,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: Text(
                    'Scan for ${widget.classGroup.subject}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _scannerController.toggleTorch(),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Bottom instruction capsule & manual fallback
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Align Student QR Code inside frame',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _showManualEnrollDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Can\'t scan? Tap to Pick Student Manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
