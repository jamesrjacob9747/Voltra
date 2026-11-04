import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';

/// The receipt: what the meter measured, what the driver pays, and how it splits.
class BillScreen extends StatefulWidget {
  const BillScreen({super.key, required this.bookingId, required this.sessionId, required this.user});

  final int bookingId;
  final int sessionId;
  final AppUser user;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  late Future<(Bill, LiveSession)> _data = _load();

  Future<(Bill, LiveSession)> _load() async =>
      (await api.bill(widget.bookingId), await api.liveSession(widget.sessionId));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your bill'), automaticallyImplyLeading: false),
      body: FutureBuilder<(Bill, LiveSession)>(
        future: _data,
        builder: (context, snap) {
          if (snap.hasError) {
            return ErrorView(message: '${snap.error}', onRetry: () => setState(() => _data = _load()));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final (bill, session) = snap.data!;
          return _buildBody(bill, session);
        },
      ),
    );
  }

  Widget _buildBody(Bill b, LiveSession s) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(Icons.task_alt, color: VoltraColors.darkGreen, size: 48),
              const SizedBox(height: 8),
              Text(
                rupees(b.payablePaise),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: VoltraColors.ink),
              ),
              Text(
                'for ${b.energyKwh.toStringAsFixed(3)} kWh at ${s.chargerName}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoltraColors.muted),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Three decimals, as billed: kWh × rate must visibly equal the total.
                      _Line('Energy (smart meter)', '${b.energyKwh.toStringAsFixed(3)} kWh'),
                      _Line('Rate', pricePerKwh(s.pricePerKwhPaise)),
                      _Line('Charging time', elapsed(s.durationS)),
                      const Divider(height: 24),
                      _Line('Charging total', rupees(b.totalPaise), bold: true),
                      if (b.creditPaise > 0) _Line('ChargeSure credit', '− ${rupees(b.creditPaise)}'),
                      _Line('You pay', rupees(b.payablePaise), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Where your money goes', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _Line('Host receives (85%)', rupees(b.hostSharePaise)),
                      _Line('Voltra fee (15%)', rupees(b.platformFeePaise)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.payments_outlined),
                  label: Text(b.status == 'PAID' ? 'Paid' : 'Pay ${rupees(b.payablePaise)} with UPI'),
                  onPressed: null, // UPI payment lands in the next build
                ),
                const SizedBox(height: 4),
                if (b.status != 'PAID')
                  const Text('UPI payment arrives in the next build.', style: TextStyle(color: VoltraColors.muted)),
                TextButton(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Back to map'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 17 : 15);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
