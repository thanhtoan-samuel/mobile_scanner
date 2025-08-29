// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mobile_scanner_example/widgets/scanner_error_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class MobileScannerAnimation extends StatefulWidget {
  const MobileScannerAnimation({super.key});

  @override
  State<MobileScannerAnimation> createState() => _MobileScannerAnimationState();
}

class _MobileScannerAnimationState extends State<MobileScannerAnimation>
    with SingleTickerProviderStateMixin {
  MobileScannerController? controller;
  late final AnimationController _popCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _popScale = CurvedAnimation(
    parent: _popCtrl,
    curve: Curves.easeOutBack,
  );

  bool useScanWindow = !kIsWeb;

  bool autoZoom = true;
  bool invertImage = false;
  bool returnImage = false;

  Size desiredCameraResolution = const Size(1920, 1080);
  DetectionSpeed detectionSpeed = DetectionSpeed.unrestricted;
  int detectionTimeoutMs = 1000;

  bool useBarcodeOverlay = true;
  BoxFit boxFit = BoxFit.cover;
  bool enableLifecycle = false;

  bool hideMobileScannerWidget = false;

  List<BarcodeFormat> selectedFormats = [];

  MobileScannerController initController() => MobileScannerController(
    autoStart: false,
    cameraResolution: desiredCameraResolution,
    detectionSpeed: detectionSpeed,
    detectionTimeoutMs: detectionTimeoutMs,
    formats: selectedFormats,
    returnImage: returnImage,
    invertImage: invertImage,
    autoZoom: autoZoom,
  );

  String? _poppedQrData;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    controller = initController();
    unawaited(controller!.start());
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await controller?.dispose();
    _popCtrl.dispose();
    controller = null;
  }

  Future<void> _handleDetection(String data) async {
    if (_handling) return;
    _handling = true;

    await controller?.pause();

    setState(() => _poppedQrData = data);
    await _popCtrl.forward(from: 0);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: MediaQuery.of(
            context,
          ).viewInsets.add(const EdgeInsets.fromLTRB(16, 16, 16, 24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      _poppedQrData!,
                      style: const TextStyle(color: Colors.white70),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: _poppedQrData!),
                        );
                        if (context.mounted) {
                          Navigator.pop(context, 'copied');
                        }
                      },
                      child: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context, 'ok');
                        await controller?.start();
                        await controller?.stop();
                        await controller?.start();
                        _handling = false;
                        if (mounted) setState(() => _poppedQrData = null);
                      },
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final Rect scanWindow = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: 150,
      height: 150,
    ).deflate(6);

    return Scaffold(
      backgroundColor: Colors.black,
      body:
          controller == null || hideMobileScannerWidget
              ? const Placeholder()
              : Stack(
                children: [
                  MobileScanner(
                    controller: controller,
                    overlayBuilder: (context, constraints) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedZoomCornersOverlay(
                            scanRect: scanWindow,
                            showScrim: false,
                          ),
                        ],
                      );
                    },
                    onDetect: (capture) {
                      for (final Barcode b in capture.barcodes) {
                        final String? s = b.rawValue;
                        if (s != null && s.isNotEmpty) {
                          _handleDetection(s);
                          break;
                        }
                      }
                    },
                    onDetectError: (error, stackTrace) {
                      debugPrint('Error $error\nStacktrace: $stackTrace');
                    },
                    errorBuilder: (context, error) {
                      return ScannerErrorWidget(error: error);
                    },
                    fit: boxFit,
                  ),

                  if (useBarcodeOverlay)
                    BarcodeOverlay(
                      controller: controller!,
                      boxFit: boxFit,
                      showTextInScanBox: false,
                    ),
                  if (_poppedQrData != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          alignment: Alignment.center,
                          child: ScaleTransition(
                            scale: _popScale,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: QrImageView(
                                data: _poppedQrData!,
                                size: 100,
                                backgroundColor: Colors.white,
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
}

class ScanOverlayPainter extends CustomPainter {
  final Rect holeRect;
  final Rect cornerRect;
  final double cornerRadius;
  final double cornerLength;
  final double cornerStrokeWidth;
  final double cornerArcRadius;
  final Color cornerColor;
  final Color scrimColor;
  final Color borderColor;
  final double borderStrokeWidth;
  final bool showScrim;
  ScanOverlayPainter({
    required this.holeRect,
    required this.cornerRect,
    this.cornerRadius = 12,
    this.cornerLength = 24,
    this.cornerStrokeWidth = 4,
    this.cornerArcRadius = 8,
    this.cornerColor = Colors.white,
    this.scrimColor = const Color(0x88000000),
    this.borderColor = Colors.transparent,
    this.borderStrokeWidth = 1,
    this.showScrim = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (showScrim && scrimColor.opacity > 0) {
      final outer = Path()..addRect(Offset.zero & size);
      final inner =
          Path()..addRRect(
            RRect.fromRectAndRadius(holeRect, Radius.circular(cornerRadius)),
          );
      final Path scrimPath = Path.combine(
        PathOperation.difference,
        outer,
        inner,
      );
      canvas.drawPath(scrimPath, Paint()..color = scrimColor);
    }

    if (borderColor.opacity > 0 && borderStrokeWidth > 0) {
      final borderPaint =
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = borderStrokeWidth
            ..color = borderColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(holeRect, Radius.circular(cornerRadius)),
        borderPaint,
      );
    }

    final cp =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cornerStrokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = cornerColor;

    final r = RRect.fromRectAndRadius(
      cornerRect,
      Radius.circular(cornerRadius),
    );
    final double left = r.left;
    final double right = r.right;
    final double top = r.top;
    final double bottom = r.bottom;

    final double rArc = math.min(cornerArcRadius, cornerLength);

    canvas
      ..drawLine(Offset(left, top + cornerLength), Offset(left, top + rArc), cp)
      ..drawLine(
        Offset(left + rArc, top),
        Offset(left + cornerLength, top),
        cp,
      );
    final tlArc = Rect.fromCircle(
      center: Offset(left + rArc, top + rArc),
      radius: rArc,
    );
    canvas
      ..drawArc(tlArc, math.pi, math.pi / 2, false, cp)
      ..drawLine(
        Offset(right, top + rArc),
        Offset(right, top + cornerLength),
        cp,
      )
      ..drawLine(
        Offset(right - cornerLength, top),
        Offset(right - rArc, top),
        cp,
      );
    final trArc = Rect.fromCircle(
      center: Offset(right - rArc, top + rArc),
      radius: rArc,
    );
    canvas
      ..drawArc(trArc, -math.pi / 2, math.pi / 2, false, cp)
      ..drawLine(
        Offset(left, bottom - cornerLength),
        Offset(left, bottom - rArc),
        cp,
      )
      ..drawLine(
        Offset(left + rArc, bottom),
        Offset(left + cornerLength, bottom),
        cp,
      );
    final blArc = Rect.fromCircle(
      center: Offset(left + rArc, bottom - rArc),
      radius: rArc,
    );
    canvas
      ..drawArc(blArc, math.pi, -math.pi / 2, false, cp)
      ..drawLine(
        Offset(right, bottom - rArc),
        Offset(right, bottom - cornerLength),
        cp,
      )
      ..drawLine(
        Offset(right - cornerLength, bottom),
        Offset(right - rArc, bottom),
        cp,
      );
    final brArc = Rect.fromCircle(
      center: Offset(right - rArc, bottom - rArc),
      radius: rArc,
    );
    canvas.drawArc(brArc, math.pi / 2, -math.pi / 2, false, cp);
  }

  @override
  bool shouldRepaint(covariant ScanOverlayPainter old) {
    return old.holeRect != holeRect ||
        old.cornerRect != cornerRect ||
        old.cornerRadius != cornerRadius ||
        old.cornerLength != cornerLength ||
        old.cornerStrokeWidth != cornerStrokeWidth ||
        old.cornerArcRadius != cornerArcRadius ||
        old.cornerColor != cornerColor ||
        old.scrimColor != scrimColor ||
        old.borderColor != borderColor ||
        old.borderStrokeWidth != borderStrokeWidth;
  }

  ScanOverlayPainter copyWith({
    Rect? holeRect,
    Rect? cornerRect,
    double? cornerRadius,
    double? cornerLength,
    double? cornerStrokeWidth,
    double? cornerArcRadius,
    Color? cornerColor,
    Color? scrimColor,
    Color? borderColor,
    double? borderStrokeWidth,
    bool? showScrim,
  }) {
    return ScanOverlayPainter(
      holeRect: holeRect ?? this.holeRect,
      cornerRect: cornerRect ?? this.cornerRect,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      cornerLength: cornerLength ?? this.cornerLength,
      cornerStrokeWidth: cornerStrokeWidth ?? this.cornerStrokeWidth,
      cornerArcRadius: cornerArcRadius ?? this.cornerArcRadius,
      cornerColor: cornerColor ?? this.cornerColor,
      scrimColor: scrimColor ?? this.scrimColor,
      borderColor: borderColor ?? this.borderColor,
      borderStrokeWidth: borderStrokeWidth ?? this.borderStrokeWidth,
      showScrim: showScrim ?? this.showScrim,
    );
  }
}

enum ScanShape { rectangle, square }

class AnimatedZoomCornersOverlay extends StatefulWidget {
  final Rect scanRect;
  final double cornerRadius;
  final double cornerLengthBase;
  final double cornerLengthDelta;
  final double strokeBase;
  final double strokeDelta;
  final double zoomAmplitude;
  final Duration duration;
  final Curve curve;
  final Color cornerColor;
  final Color scrimColor;
  final Color borderColor;
  final double borderStrokeWidth;
  final bool showScrim;
  final double cornerPadding;
  const AnimatedZoomCornersOverlay({
    required this.scanRect,
    super.key,
    this.cornerRadius = 16,
    this.cornerLengthBase = 24,
    this.cornerLengthDelta = 8,
    this.strokeBase = 4,
    this.strokeDelta = 1.5,
    this.zoomAmplitude = 2,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeInOut,
    this.cornerColor = Colors.white,
    this.scrimColor = const Color(0x88000000),
    this.borderColor = Colors.transparent,
    this.borderStrokeWidth = 1,
    this.showScrim = true,
    this.cornerPadding = 8,
  });

  @override
  State<AnimatedZoomCornersOverlay> createState() =>
      _AnimatedZoomCornersOverlayState();
}

class _AnimatedZoomCornersOverlayState extends State<AnimatedZoomCornersOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);
  late final Animation<double> _t = CurvedAnimation(
    parent: _ctrl,
    curve: widget.curve,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Rect hole = widget.scanRect;

    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final double zoom =
            lerpDouble(-widget.zoomAmplitude, widget.zoomAmplitude, _t.value)!;

        final double cornerLength =
            widget.cornerLengthBase +
            math.sin(_t.value * math.pi) * widget.cornerLengthDelta;
        final double stroke =
            widget.strokeBase +
            math.sin(_t.value * math.pi) * widget.strokeDelta;
        final double delta = widget.cornerPadding + zoom;
        final cornerRect = Rect.fromCenter(
          center: hole.center,
          width: hole.width + delta * 2,
          height: hole.height + delta * 2,
        );

        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: ScanOverlayPainter(
              holeRect: hole,
              cornerRect: cornerRect,
              cornerRadius: widget.cornerRadius,
              cornerLength: cornerLength,
              cornerStrokeWidth: stroke,
              cornerColor: widget.cornerColor,
              scrimColor: widget.scrimColor,
              borderColor: widget.borderColor,
              borderStrokeWidth: widget.borderStrokeWidth,
              showScrim: widget.showScrim,
            ),
          ),
        );
      },
    );
  }
}
