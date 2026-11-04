import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api.dart';
import '../charger_form.dart';
import '../config.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/snack.dart';

/// A host lists a charger or 15A socket. On success it shows the code drivers type to start.
/// Pops `true` when a charger was added.
class AddChargerScreen extends StatefulWidget {
  const AddChargerScreen({super.key, required this.user});

  final AppUser user;

  @override
  State<AddChargerScreen> createState() => _AddChargerScreenState();
}

class _AddChargerScreenState extends State<AddChargerScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _power = TextEditingController(text: '3.3');
  final _price = TextEditingController(text: '12');

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

  Future<void> _save() async {
    final hoursError = validateHours(_fromText, _toText);
    if (!_form.currentState!.validate() || hoursError != null) {
      if (hoursError != null) showSnack(context, hoursError);
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
      if (mounted) setState(() => _created = charger);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_created == null ? 'Add a charger' : 'Charger added')),
      body: _created == null ? _buildForm() : _AddedView(charger: _created!),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Manoj’s Garage Socket'),
            textCapitalization: TextCapitalization.words,
            validator: validateChargerName,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Address',
              helperText: 'Shown to drivers only after you confirm their booking',
            ),
            validator: validateAddress,
          ),
          const SizedBox(height: 16),
          const Text('Location', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text(
            'Tap the map to place the pin on your charger. Drivers see an approximate spot until booking.',
            style: TextStyle(color: VoltraColors.muted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: demoLocation,
                  initialZoom: 15,
                  onTap: (_, point) => setState(() => _pin = point),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.voltra.voltra_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _pin,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(Icons.location_on, size: 40, color: VoltraColors.darkGreen),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Connector', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '15A', label: Text('15A socket')),
              ButtonSegment(value: 'TYPE2', label: Text('Type 2')),
              ButtonSegment(value: 'CCS2', label: Text('CCS2')),
            ],
            selected: {_connector},
            onSelectionChanged: (s) => setState(() => _connector = s.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _power,
                  decoration: const InputDecoration(labelText: 'Max power', suffixText: 'kW'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: validatePowerKw,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _price,
                  decoration: const InputDecoration(labelText: 'Price', prefixText: '₹ ', suffixText: '/kWh'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: validatePriceRupees,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Open hours', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: Text('From ${_from.format(context)}'),
                  onPressed: () => _pickTime(opening: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.nightlight_outlined),
                  label: Text('To ${_to.format(context)}'),
                  onPressed: () => _pickTime(opening: false),
                ),
              ),
            ],
          ),
          if (validateHours(_fromText, _toText) case final error?)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Instant booking'),
            subtitle: Text(_autoApprove ? 'Bookings are confirmed automatically' : 'You approve each booking'),
            value: _autoApprove,
            onChanged: (v) => setState(() => _autoApprove = v),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add_location_alt_outlined),
            label: const Text('Add charger'),
            onPressed: _saving ? null : _save,
          ),
        ],
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
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.task_alt, color: VoltraColors.darkGreen, size: 56),
        const SizedBox(height: 12),
        Text(
          '${charger.name} is live',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text('Charger code', style: TextStyle(color: VoltraColors.muted)),
                const SizedBox(height: 4),
                SelectableText(
                  charger.deviceId,
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, letterSpacing: 4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Write this code next to your socket. Drivers type it with “Enter code” to start charging.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${charger.connectorLabel} · ${charger.powerKw} kW · ${pricePerKwh(charger.basePricePaise)} · '
          'open ${charger.availableFrom}–${charger.availableTo}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VoltraColors.muted),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
      ],
    );
  }
}
