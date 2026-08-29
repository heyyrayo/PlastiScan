import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/storage_service.dart';
import '../../core/navigation/app_navigation.dart';
import '../../theme/plastiscan_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scan Screen
// ─────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  // ───────────────────────────────────────────────────────────────────────────
  // Camera
  // ───────────────────────────────────────────────────────────────────────────

  CameraController? _cameraController;

  List<CameraDescription> _cameras = [];

  bool _cameraReady = false;
  bool _cameraError = false;
  bool _torchOn = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Scan / upload state
  // ───────────────────────────────────────────────────────────────────────────

  bool _capturing = false;

  bool _uploading = false;

  // ───────────────────────────────────────────────────────────────────────────
  // Image picker
  // ───────────────────────────────────────────────────────────────────────────

  final ImagePicker _imagePicker = ImagePicker();

  // ───────────────────────────────────────────────────────────────────────────
  // Animations
  // ───────────────────────────────────────────────────────────────────────────

  late final AnimationController _scanLineCtrl;

  late final AnimationController _bracketPulseCtrl;

  // ───────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1600,
      ),
    )..repeat();

    _bracketPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1200,
      ),
    )..repeat(
        reverse: true,
      );

    _initCamera();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Initialize camera
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _cameraError = true;
        });

        return;
      }

      final backCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();

        return;
      }

      setState(() {
        _cameraController = controller;

        _cameraReady = true;

        _cameraError = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _cameraError = true;

        _cameraReady = false;
      });
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Toggle flashlight
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _toggleTorch() async {
    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      final newTorchState = !_torchOn;

      await controller.setFlashMode(
        newTorchState ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _torchOn = newTorchState;
      });
    } catch (_) {
      _showMessage(
        'Flashlight is not available on this device.',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Capture image
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _triggerCapture() async {
    if (_capturing || _uploading) {
      return;
    }

    final controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      _showMessage(
        'Camera is not ready yet.',
      );

      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final XFile image = await controller.takePicture();

      if (!mounted) return;

      setState(() {
        _capturing = false;
      });

      await _showImagePreview(
        image,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _capturing = false;
      });

      _showMessage(
        'Could not capture the image. Please try again.',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pick from gallery
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _pickFromGallery() async {
    if (_capturing || _uploading) {
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      await _showImagePreview(
        image,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Could not select the image. Please try again.',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Image preview
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _showImagePreview(
    XFile image,
  ) async {
    final shouldContinue = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ImagePreviewSheet(
          image: image,
        );
      },
    );

    if (!mounted) return;

    if (shouldContinue == true) {
      await _uploadImage(
        image,
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Upload image to Supabase
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _uploadImage(
    XFile image,
  ) async {
    if (_uploading) return;

    setState(() {
      _uploading = true;
    });

    try {
      final result = await StorageService.instance.uploadScanImage(
        imagePath: image.path,
      );

      if (!mounted) return;

      setState(() {
        _uploading = false;
      });

      // ───────────────────────────────────────────────────────────────────────
      // Successful upload
      // ───────────────────────────────────────────────────────────────────────

      await _showUploadSuccess(
        result,
      );
    } on StorageUploadException catch (error) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
      });

      _showUploadError(
        error.message,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _uploading = false;
      });

      _showUploadError(
        'Something went wrong while uploading the image.',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Upload success dialog
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _showUploadSuccess(
    StorageUploadResult result,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
              ),
              SizedBox(width: 10),
              Text(
                'Image Uploaded',
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your product image was successfully uploaded to your private scan storage.',
              ),
              const SizedBox(height: 16),
              Text(
                'Original: '
                '${result.originalSizeKb.toStringAsFixed(0)} KB',
              ),
              const SizedBox(height: 4),
              Text(
                'Compressed: '
                '${result.compressedSizeKb.toStringAsFixed(0)} KB',
              ),
              const SizedBox(height: 4),
              Text(
                'Saved: '
                '${result.compressionPercentage.toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 16),
              const Text(
                'AI analysis will be connected in the next step.',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(),
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Upload error
  // ───────────────────────────────────────────────────────────────────────────

  void _showUploadError(
    String message,
  ) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
              ),
              SizedBox(width: 10),
              Text(
                'Upload Failed',
              ),
            ],
          ),
          content: Text(
            message,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(),
              child: const Text(
                'Close',
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Generic snackbar
  // ───────────────────────────────────────────────────────────────────────────

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dispose
  // ───────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _scanLineCtrl.dispose();

    _bracketPulseCtrl.dispose();

    _cameraController?.dispose();

    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors = Theme.of(context).extension<PlastiScanColors>()!;

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(
        0xFF0A100E,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─────────────────────────────────────────────────────────────────────
          // Camera preview
          // ─────────────────────────────────────────────────────────────────────

          _cameraReady && _cameraController != null
              ? SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _cameraController!.value.previewSize!.height,
                      height: _cameraController!.value.previewSize!.width,
                      child: CameraPreview(
                        _cameraController!,
                      ),
                    ),
                  ),
                )
              : _CameraPlaceholder(
                  hasError: _cameraError,
                ),

          // ─────────────────────────────────────────────────────────────────────
          // Dark gradient
          // ─────────────────────────────────────────────────────────────────────

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [
                  0,
                  0.28,
                  0.65,
                  1,
                ],
                colors: [
                  Colors.black.withValues(
                    alpha: 0.72,
                  ),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withValues(
                    alpha: 0.82,
                  ),
                ],
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────────────────
          // Viewfinder
          // ─────────────────────────────────────────────────────────────────────

          Align(
            alignment: const Alignment(
              0,
              -0.12,
            ),
            child: SizedBox(
              width: size.width * 0.78,
              height: size.width * 0.78,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _bracketPulseCtrl,
                    builder: (_, __) {
                      return CustomPaint(
                        size: Size.square(
                          size.width * 0.78,
                        ),
                        painter: _ViewfinderPainter(
                          bracketColor: colors.mintAccent,
                          pulse: _bracketPulseCtrl.value,
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _scanLineCtrl,
                    builder: (_, __) {
                      return CustomPaint(
                        size: Size.square(
                          size.width * 0.78,
                        ),
                        painter: _ScanLinePainter(
                          progress: _scanLineCtrl.value,
                          color: colors.gradientEnd,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────────────────
          // Top bar
          // ─────────────────────────────────────────────────────────────────────

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    _TopBarButton(
                      icon: Icons.close_rounded,
                      onTap: () => goBackOrHome(context),
                    ),

                    const Spacer(),

                    // AI Active
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(
                          alpha: 0.45,
                        ),
                        borderRadius: BorderRadius.circular(
                          20,
                        ),
                        border: Border.all(
                          color: colors.mintAccent.withValues(
                            alpha: 0.5,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: colors.mintAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                            width: 6,
                          ),
                          Text(
                            'AI Active',
                            style: Theme.of(
                              context,
                            ).textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    _TopBarButton(
                      icon: _torchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      onTap: _toggleTorch,
                      active: _torchOn,
                      activeColor: Colors.amber,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─────────────────────────────────────────────────────────────────────
          // Hint
          // ─────────────────────────────────────────────────────────────────────

          Align(
            alignment: const Alignment(
              0,
              0.46,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Position the barcode or label\nwithin the frame',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(
                          alpha: 0.85,
                        ),
                      ),
                ),
                const SizedBox(
                  height: 6,
                ),
                Text(
                  _uploading ? 'UPLOADING IMAGE' : 'AUTO-DETECTING',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(
                        color: colors.mintAccent,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),

          // ─────────────────────────────────────────────────────────────────────
          // Upload overlay
          // ─────────────────────────────────────────────────────────────────────

          if (_uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(
                  alpha: 0.55,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(
                        height: 16,
                      ),
                      Text(
                        'Uploading scan…',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ─────────────────────────────────────────────────────────────────────
          // Bottom actions
          // ─────────────────────────────────────────────────────────────────────

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  12,
                  24,
                  28,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.photo_library_outlined,
                        label: 'Gallery',
                        onTap: _pickFromGallery,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: _CaptureButton(
                        capturing: _capturing || _uploading,
                        onTap: _triggerCapture,
                        accentColor: colors.mintAccent,
                        gradientStart: colors.gradientStart,
                        gradientEnd: colors.gradientEnd,
                      ),
                    ),
                    Expanded(
                      child: _BottomAction(
                        icon: Icons.edit_outlined,
                        label: 'Manual',
                        onTap: () => goToManualEntry(context),
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

// ─────────────────────────────────────────────────────────────────────────────
// Image Preview Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ImagePreviewSheet extends StatelessWidget {
  const _ImagePreviewSheet({
    required this.image,
  });

  final XFile image;

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(
                    alpha: 0.2,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                'Review Image',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        color: Colors.black12,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(false),
                      icon: const Icon(
                        Icons.refresh_rounded,
                      ),
                      label: const Text(
                        'Retake',
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(true),
                      icon: const Icon(
                        Icons.cloud_upload_outlined,
                      ),
                      label: const Text(
                        'Upload',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Camera Placeholder
// ─────────────────────────────────────────────────────────────────────────────

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({
    required this.hasError,
  });

  final bool hasError;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color: const Color(
        0xFF0A100E,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasError ? Icons.no_photography_outlined : Icons.camera_outlined,
              color: Colors.white24,
              size: 48,
            ),
            const SizedBox(
              height: 12,
            ),
            Text(
              hasError ? 'Camera unavailable' : 'Starting camera…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white38,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar Button
// ─────────────────────────────────────────────────────────────────────────────

class _TopBarButton extends StatelessWidget {
  const _TopBarButton({
    required this.icon,
    required this.onTap,
    this.active = false,
    this.activeColor,
  });

  final IconData icon;

  final VoidCallback onTap;

  final bool active;

  final Color? activeColor;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(
            alpha: 0.45,
          ),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: active ? (activeColor ?? Colors.white) : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Action
// ─────────────────────────────────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;

  final String label;

  final VoidCallback onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: 0.25,
                ),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(
            height: 6,
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(
                    alpha: 0.8,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Capture Button
// ─────────────────────────────────────────────────────────────────────────────

class _CaptureButton extends StatefulWidget {
  const _CaptureButton({
    required this.capturing,
    required this.onTap,
    required this.accentColor,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final bool capturing;

  final VoidCallback onTap;

  final Color accentColor;

  final Color gradientStart;

  final Color gradientEnd;

  @override
  State<_CaptureButton> createState() => _CaptureButtonState();
}

class _CaptureButtonState extends State<_CaptureButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 900,
      ),
    )..repeat(
        reverse: true,
      );
  }

  @override
  void dispose() {
    _pulse.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: widget.capturing ? null : widget.onTap,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, child) {
          return Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.gradientEnd.withValues(
                    alpha: 0.25 + _pulse.value * 0.25,
                  ),
                  blurRadius: 16 + _pulse.value * 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.gradientStart,
                widget.gradientEnd,
              ],
            ),
          ),
          child: widget.capturing
              ? const Padding(
                  padding: EdgeInsets.all(
                    22,
                  ),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(
                  Icons.camera_rounded,
                  color: Colors.white,
                  size: 34,
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Viewfinder Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({
    required this.bracketColor,
    required this.pulse,
  });

  final Color bracketColor;

  final double pulse;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final opacity = 0.55 + pulse * 0.45;

    final paint = Paint()
      ..color = bracketColor.withValues(
        alpha: opacity,
      )
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const r = 12.0;

    const len = 28.0;

    final w = size.width;

    final h = size.height;

    void drawCorner(
      Offset origin,
      double dx,
      double dy,
    ) {
      final cx = origin.dx + (dx > 0 ? r : -r);

      final cy = origin.dy + (dy > 0 ? r : -r);

      canvas.drawLine(
        Offset(
          cx,
          origin.dy,
        ),
        Offset(
          cx + dx * len,
          origin.dy,
        ),
        paint,
      );

      canvas.drawLine(
        Offset(
          origin.dx,
          cy,
        ),
        Offset(
          origin.dx,
          cy + dy * len,
        ),
        paint,
      );
    }

    drawCorner(
      Offset.zero,
      1,
      1,
    );

    drawCorner(
      Offset(w, 0),
      -1,
      1,
    );

    drawCorner(
      Offset(0, h),
      1,
      -1,
    );

    drawCorner(
      Offset(w, h),
      -1,
      -1,
    );
  }

  @override
  bool shouldRepaint(
    _ViewfinderPainter old,
  ) {
    return old.pulse != pulse;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Scan Line Painter
// ─────────────────────────────────────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  const _ScanLinePainter({
    required this.progress,
    required this.color,
  });

  final double progress;

  final Color color;

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final y = size.height * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(
            alpha: 0,
          ),
          color.withValues(
            alpha: 0.9,
          ),
          color.withValues(
            alpha: 0,
          ),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          y - 1,
          size.width,
          2,
        ),
      )
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      paint,
    );

    // Glow
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(
            alpha: 0,
          ),
          color.withValues(
            alpha: 0.2,
          ),
          color.withValues(
            alpha: 0,
          ),
        ],
      ).createShader(
        Rect.fromLTWH(
          0,
          y - 6,
          size.width,
          12,
        ),
      )
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(
    _ScanLinePainter old,
  ) {
    return old.progress != progress;
  }
}
