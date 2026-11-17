import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../models.dart';
import '../theme.dart';
import 'live_session_screen.dart';

/// Scan the QR sticker on the charger to start the booked session.
/// "Enter code" is the fallback when the camera can't read the sticker (and on the emulator).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.booking, required this.user});

  final Booking booking;
  final AppUser user;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );
  bool _starting = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || _starting) return;
    if (!raw.startsWith(qrPrefix)) {
      setState(() => _error = 'That isn’t a Voltra charger code.');
      return;
    }
    HapticFeedback.mediumImpact();
    _start(raw);
  }

  Future<void> _start(String qr) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    await _scanner.stop();
    try {
      final session = await api.startSession(widget.booking.id, qr);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LiveSessionScreen(sessionId: session.sessionId, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'CHARGER_OFFLINE') {
        // Back to the booking, which reloads and shows ChargeSure's nearby options.
        Navigator.of(context).pop();
        return;
      }
      HapticFeedback.heavyImpact();
      setState(() {
        _starting = false;
        _error = e.message;
      });
      await _scanner.start();
    }
  }

  Future<void> _enterCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CodeSheet(),
    );
    final cleaned = code?.trim().toUpperCase();
    if (cleaned != null && cleaned.isNotEmpty) await _start('$qrPrefix$cleaned');
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: darkAppBar('Scan to start', background: Colors.black),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.xl),
                      child: Text(
                        'Camera unavailable. Use “Enter code” below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                Center(child: _ScanFrame(active: !_starting)),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, Gap.lg + MediaQuery.paddingOf(context).bottom),
            decoration: BoxDecoration(color: vc.card, borderRadius: Radii.sheet),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan the QR on ${widget.booking.chargerName}',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: vc.ink),
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'Plug in your vehicle first. Power switches on as soon as the code is verified.',
                  style: TextStyle(color: vc.muted, height: 1.35),
                ),
                AnimatedSize(
                  duration: Motion.medium,
                  curve: Motion.enter,
                  alignment: Alignment.topLeft,
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Container(
                          margin: const EdgeInsets.only(top: Gap.md),
                          padding: const EdgeInsets.all(Gap.md),
                          decoration: BoxDecoration(
                            color: vc.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(Radii.md),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline, color: vc.danger),
                              const SizedBox(width: Gap.sm),
                              Expanded(
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _error!,
                                    style: TextStyle(color: vc.danger, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: Gap.lg),
                AnimatedSwitcher(
                  duration: Motion.medium,
                  child: _starting
                      ? SizedBox(
                          key: const ValueKey('starting'),
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand),
                              ),
                              const SizedBox(width: Gap.md),
                              Text(
                                'Switching the power on…',
                                style: TextStyle(color: vc.ink, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('enter'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          icon: const Icon(Icons.keyboard),
                          label: const Text('Enter code'),
                          onPressed: _enterCode,
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

/// Four corner brackets with a line sweeping between them while the camera is looking.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    const size = 240.0;
    final line = Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: VoltraColors.green,
        borderRadius: BorderRadius.circular(2),
        boxShadow: const [BoxShadow(color: VoltraColors.green, blurRadius: 12)],
      ),
    );
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _CornersPainter())),
          if (active && !Motion.reduced(context))
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: line
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(
                    begin: 20,
                    end: size - 24,
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeInOut,
                  ),
            ),
        ],
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const r = 24.0;
    const arm = 34.0;
    final paint = Paint()
      ..color = VoltraColors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    Path corner(double x, double y, double dx, double dy) => Path()
      ..moveTo(x, y + dy * (r + arm))
      ..lineTo(x, y + dy * r)
      ..quadraticBezierTo(x, y, x + dx * r, y)
      ..lineTo(x + dx * (r + arm), y);
    canvas
      ..drawPath(corner(0, 0, 1, 1), paint)
      ..drawPath(corner(w, 0, -1, 1), paint)
      ..drawPath(corner(0, h, 1, -1), paint)
      ..drawPath(corner(w, h, -1, -1), paint);
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}

/// Typed fallback for the QR, as a sheet that rides above the keyboard. Owns its controller
/// so it is disposed only after the sheet's closing animation has finished.
class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter charger code',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: vc.ink),
            ),
            const SizedBox(height: Gap.xs),
            Text('It’s printed under the QR code on the charger.', style: TextStyle(color: vc.muted)),
            const SizedBox(height: Gap.lg),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              autocorrect: false,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2, color: vc.ink),
              decoration: const InputDecoration(hintText: 'CHG001'),
              onSubmitted: (v) => Navigator.pop(context, v),
            ),
            const SizedBox(height: Gap.lg),
            FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}
