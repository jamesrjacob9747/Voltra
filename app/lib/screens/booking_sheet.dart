import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import 'booking_screen.dart';

/// Book a specific charger directly (ChargeMatch picks the slot for you instead).
Future<void> showBookingSheet(BuildContext context, {required Charger charger, required AppUser user}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookingSheet(charger: charger, user: user, parent: context),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.charger, required this.user, required this.parent});

  final Charger charger;
  final AppUser user;
  final BuildContext parent;

  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  static const _startsIn = {0: 'Now', 30: 'In 30 min', 60: 'In 1 hour'};
  static const _lengths = {60: '1 h', 120: '2 h', 180: '3 h'};

  int _startInMin = 0;
  int _lengthMin = 120;
  bool _busy = false;
  String? _error;
  Vehicle? _vehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  /// The vehicle only sharpens the estimate; booking works without it.
  Future<void> _loadVehicle() async {
    try {
      final vehicles = await api.vehicles(widget.user.id);
      if (mounted && vehicles.isNotEmpty) setState(() => _vehicle = vehicles.first);
    } on ApiException {
      // No estimate line, nothing else changes.
    }
  }

  /// Most energy this slot can deliver: the slower of socket and vehicle, for the slot's
  /// length, and never more than the battery holds. Null until the vehicle is known.
  double? get _maxKwh {
    final v = _vehicle;
    if (v == null) return null;
    final kw = math.min(widget.charger.powerKw, v.chargerKw);
    return math.min(kw * _lengthMin / 60, v.batteryKwh);
  }

  Future<void> _book() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(widget.parent);
    try {
      final now = await api.serverNow();
      // Round up to the next 5 minutes so the slot starts on a clean time.
      final base = now.add(Duration(minutes: 5 - now.minute % 5 + _startInMin));
      final start = DateTime(base.year, base.month, base.day, base.hour, base.minute);
      final booking = await api.createBooking(
        driverId: widget.user.id,
        chargerId: widget.charger.id,
        vehicleId: _vehicle?.id,
        start: start,
        end: start.add(Duration(minutes: _lengthMin)),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BookingScreen(bookingId: booking.id, user: widget.user),
        ),
      );
    } on ApiException catch (e) {
      // Shown inside the sheet: a snack bar would sit behind it, out of sight.
      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  /// Picking a different slot clears the last error: it was about the old choice.
  void _pick(VoidCallback change) => setState(() {
    change();
    _error = null;
  });

  Widget _choices(String title, Map<int, String> options, int selected, ValueChanged<int> onPick) {
    final vc = context.vc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w700, color: vc.ink),
        ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            for (final (i, e) in options.entries.indexed) ...[
              if (i > 0) const SizedBox(width: Gap.sm),
              Expanded(
                child: _Choice(
                  label: e.value,
                  selected: selected == e.key,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPick(e.key);
                  },
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final c = widget.charger;
    final kwh = _maxKwh;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Book ${c.name}',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: vc.ink),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              '${pricePerKwh(c.priceNowPaise)} · ${c.autoApprove ? 'confirmed instantly' : '${c.hostName} approves each booking'}',
              style: TextStyle(color: vc.muted),
            ),
            const SizedBox(height: Gap.xl),
            _choices('Start', _startsIn, _startInMin, (v) => _pick(() => _startInMin = v)),
            const SizedBox(height: Gap.lg),
            _choices('For', _lengths, _lengthMin, (v) => _pick(() => _lengthMin = v)),
            const SizedBox(height: Gap.lg),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: kwh == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      padding: const EdgeInsets.all(Gap.md),
                      margin: const EdgeInsets.only(bottom: Gap.lg),
                      decoration: BoxDecoration(color: vc.brandTint, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Row(
                        children: [
                          Icon(Icons.bolt, color: vc.brand),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(
                              'Up to ${kwh.toStringAsFixed(1)} kWh for your ${_vehicle!.model}, '
                              'about ${rupees((kwh * c.priceNowPaise).round())} at most. '
                              'You pay only for the energy you use.',
                              style: TextStyle(color: vc.ink, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: _error == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      padding: const EdgeInsets.all(Gap.md),
                      margin: const EdgeInsets.only(bottom: Gap.lg),
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
                                style: TextStyle(color: vc.danger, fontWeight: FontWeight.w600, height: 1.35),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            FilledButton(
              onPressed: _busy ? null : _book,
              child: _busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: vc.brand))
                  : const Text('Confirm booking'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One option of a row of equal-width choices; the selected one fills with the brand colour.
class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? vc.brand : vc.card,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: selected ? vc.brand : vc.border),
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: selected ? vc.onBrand : vc.ink),
          ),
        ),
      ),
    );
  }
}
