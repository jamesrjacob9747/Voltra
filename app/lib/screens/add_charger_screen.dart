import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../charger_form.dart';
import '../config.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/charger_map.dart';
import '../widgets/motion.dart';
import '../widgets/primary_bar.dart';
import '../widgets/snack.dart';

const _steps = ['Details', 'Location', 'Price and hours'];

/// A host lists a charger or 15A socket, in three short steps. On success it shows the code
/// drivers type to start. Pops `true` when a charger was added.
class AddChargerScreen extends StatefulWidget {
  const AddChargerScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends State<AddChargerScreen> {
  // One form per step, so "Continue" validates only what is on screen.
  final _forms = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _power = TextEditingController(text: '3.3');
  final _price = TextEditingController(text: '12');

  int _step = 0;
  bool _forward = true;
  LatLng _pin = demoLocation;
  String _connector = '15A';
  TimeOfDay _from = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 22, minute: 0);
  bool _autoApprove = true;
  bool _saving = false;
  Charger? _created;

  String get _fromText => hhmm(_from.hour, _from.minute);
  String get _toText => hhmm(_to.hour, _to.minute);

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _power.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickTime({required bool opening}) async {
    final picked = await showTimePicker(context: context, initialTime: opening ? _from : _to);
    if (picked != null) setState(() => opening ? _from = picked : _to = picked);
  }

  void _go(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _forward = step > _step;
      _step = step;
    });
  }

  void _next() {
    if (!_forms[_step].currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_step < _steps.length - 1) {
      HapticFeedback.selectionClick();
      _go(_step + 1);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final hoursError = validateHours(_fromText, _toText);
    if (hoursError != null) {
      HapticFeedback.heavyImpact();
      showSnack(context, hoursError);
      return;
    }
    setState(() => _saving = true);
    try {
      final charger = await api.createCharger(
        hostId: widget.user.id,
        name: _name.text.trim(),
        address: _address.text.trim(),
        lat: _pin.latitude,
        lng: _pin.longitude,
        connectorType: _connector,
        powerKw: double.parse(_power.text.trim()),
        pricePerKwhPaise: rupeesToPaise(_price.text),
        availableFrom: _fromText,
        availableTo: _toText,
        autoApprove: _autoApprove,
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _created = charger);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    if (created != null) {
      return PopScope(
        // Leaving the success page by any route still reports the new charger.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(true);
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('Charger added'), automaticallyImplyLeading: false),
          body: _AddedView(charger: created),
          bottomNavigationBar: PrimaryBar(label: 'Done', onPressed: () => Navigator.of(context).pop(true)),
        ),
      );
    }

    final still = Motion.reduced(context);
    final last = _step == _steps.length - 1;
    return PopScope(
      // Back steps back through the form before it leaves the screen.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Add a charger')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.xs, Gap.lg, Gap.md),
              child: _Progress(step: _step),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: still ? Duration.zero : Motion.slow,
                switchInCurve: Motion.enter,
                switchOutCurve: Motion.exit,
                // The new step slides in from the side you are heading towards.
                transitionBuilder: (child, animation) {
                  final incoming = child.key == _forms[_step];
                  final from = Offset((incoming == _forward) ? 0.15 : -0.15, 0);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: from, end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: Form(
                  key: _forms[_step],
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _buildDetails(),
                      1 => _buildLocation(),
                      _ => _buildPrice(),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: PrimaryBar(
          icon: last ? Icons.add_location_alt_outlined : null,
          label: last ? 'Add charger' : 'Continue',
          busy: _saving,
          onPressed: _next,
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(
      text,
      style: TextStyle(fontWeight: FontWeight.w700, color: context.vc.ink),
    ),
  );

  Widget _buildDetails() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      children: [
        TextFormField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Manoj’s Garage Socket'),
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: validateChargerName,
        ),
        const SizedBox(height: Gap.xl),
        _label('Connector'),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: '15A', label: Text('15A socket')),
            ButtonSegment(value: 'TYPE2', label: Text('Type 2')),
            ButtonSegment(value: 'CCS2', label: Text('CCS2')),
          ],
          selected: {_connector},
          onSelectionChanged: (s) => setState(() => _connector = s.first),
        ),
        const SizedBox(height: Gap.xl),
        TextFormField(
          controller: _power,
          decoration: const InputDecoration(
            labelText: 'Max power',
            suffixText: 'kW',
            helperText: 'A household 15A socket gives about 3.3 kW',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validatePowerKw,
        ),
        const SizedBox(height: Gap.lg),
        Card(
          child: SwitchListTile(
            title: const Text('Instant booking', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(_autoApprove ? 'Bookings are confirmed automatically' : 'You approve each booking'),
            value: _autoApprove,
            onChanged: (v) => setState(() => _autoApprove = v),
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    final vc = context.vc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      children: [
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(
            labelText: 'Address',
            helperText: 'Shown to drivers only after you confirm their booking',
          ),
          textCapitalization: TextCapitalization.words,
          validator: validateAddress,
        ),
        const SizedBox(height: Gap.xl),
        _label('Pin on the map'),
        Text(
          'Tap the map to place the pin on your charger. Drivers see an approximate spot until booking.',
          style: TextStyle(color: vc.muted, height: 1.35),
        ),
        const SizedBox(height: Gap.md),
        ClipRRect(
          borderRadius: Radii.card,
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _pin,
                initialZoom: 15,
                onTap: (_, point) {
                  HapticFeedback.selectionClick();
                  setState(() => _pin = point);
                },
              ),
              children: [
                voltraTiles(context),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _pin,
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      // Light-theme green: the pin sits on light map tiles in both themes.
                      child: const Icon(Icons.location_on, size: 44, color: VoltraColors.darkGreen),
                    ),
                  ],
                ),
                const SimpleAttributionWidget(source: Text('OpenStreetMap contributors')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrice() {
    final vc = context.vc;
    final hoursError = validateHours(_fromText, _toText);
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
      children: [
        TextFormField(
          controller: _price,
          decoration: const InputDecoration(
            labelText: 'Price',
            prefixText: '₹ ',
            suffixText: '/kWh',
            helperText: 'You keep 85% of every charge',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: validatePriceRupees,
        ),
        const SizedBox(height: Gap.xl),
        _label('Open hours'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wb_sunny_outlined, size: 20),
                label: Text('From ${_from.format(context)}'),
                onPressed: () => _pickTime(opening: true),
              ),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.nightlight_outlined, size: 20),
                label: Text('To ${_to.format(context)}'),
                onPressed: () => _pickTime(opening: false),
              ),
            ),
          ],
        ),
        if (hoursError != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.sm),
            child: Text(
              hoursError,
              style: TextStyle(color: vc.danger, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: Gap.xl),
        // What is about to be listed, so the last tap is a confirmation, not a leap.
        Container(
          padding: const EdgeInsets.all(Gap.lg),
          decoration: BoxDecoration(color: vc.brandTint, borderRadius: Radii.card),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _name.text.trim().isEmpty ? 'Your charger' : _name.text.trim(),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: vc.ink),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                '${_connector == '15A' ? '15A socket' : _connector} · ${_power.text.trim()} kW · '
                '${_autoApprove ? 'instant booking' : 'you approve each booking'}',
                style: TextStyle(color: vc.muted),
              ),
              if (_address.text.trim().isNotEmpty) Text(_address.text.trim(), style: TextStyle(color: vc.muted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Step 2 of 3 · Location" over a three-part bar that fills as the host moves on.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final duration = Motion.reduced(context) ? Duration.zero : Motion.slow;
    return Semantics(
      label: 'Step ${step + 1} of ${_steps.length}: ${_steps[step]}',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step ${step + 1} of ${_steps.length} · ${_steps[step]}',
              style: TextStyle(color: vc.muted, fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                for (var i = 0; i < _steps.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: AnimatedContainer(
                      duration: duration,
                      curve: Motion.enter,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= step ? vc.brand : vc.raised,
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Success: the code the host writes next to the socket.
class _AddedView extends StatelessWidget {
  const _AddedView({required this.charger});

  final Charger charger;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    return ListView(
      padding: const EdgeInsets.all(Gap.xl),
      children: [
        const SizedBox(height: Gap.lg),
        const Center(child: AnimatedCheck(size: 84)),
        const SizedBox(height: Gap.lg),
        Entrance(
          index: 2,
          child: Text(
            '${charger.name} is live',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: vc.ink, letterSpacing: -0.3),
          ),
        ),
        const SizedBox(height: Gap.xl),
        Entrance(
          index: 4,
          child: Container(
            padding: const EdgeInsets.all(Gap.xl),
            decoration: const BoxDecoration(color: VoltraColors.navy, borderRadius: Radii.card),
            child: Column(
              children: [
                const Text('Charger code', style: TextStyle(color: VoltraColors.onNavySoft)),
                const SizedBox(height: Gap.xs),
                SelectableText(
                  charger.deviceId,
                  style: const TextStyle(
                    color: VoltraColors.green,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: Gap.sm),
                const Text(
                  'Write this code next to your socket. Drivers type it with “Enter code” to start charging.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: Gap.md),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: VoltraColors.green),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy code'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: charger.deviceId));
                    if (context.mounted) showSnack(context, 'Copied ${charger.deviceId}');
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),
        Entrance(
          index: 6,
          child: Text(
            '${charger.connectorLabel} · ${charger.powerKw} kW · ${pricePerKwh(charger.basePricePaise)} · '
            'open ${charger.availableFrom}–${charger.availableTo}',
            textAlign: TextAlign.center,
            style: TextStyle(color: vc.muted),
          ),
        ),
      ],
    );
  }
}
