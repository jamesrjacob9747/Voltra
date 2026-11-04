import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api.dart';
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
      setState(() {
        _starting = false;
        _error = e.message;
      });
      await _scanner.start();
    }
  }

  Future<void> _enterCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter charger code'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. CHG001', helperText: 'Printed under the QR code'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(88, 40)),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    final cleaned = code?.trim().toUpperCase();
    if (cleaned != null && cleaned.isNotEmpty) await _start('$qrPrefix$cleaned');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Scan to start')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scanner,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Camera unavailable. Use “Enter code” below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: VoltraColors.green, width: 4),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              decoration: const BoxDecoration(
                color: VoltraColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan the QR on ${widget.booking.chargerName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Plug in your vehicle first. Power switches on as soon as the code is verified.',
                    style: TextStyle(color: VoltraColors.muted),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_starting)
                    const Center(child: CircularProgressIndicator())
                  else
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      icon: const Icon(Icons.keyboard),
                      label: const Text('Enter code'),
                      onPressed: _enterCode,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
