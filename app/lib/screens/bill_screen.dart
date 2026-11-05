import 'dart:async';

import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../api.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/snack.dart';

/// The receipt: what the meter measured, what the driver pays and how it splits;
/// then UPI payment and a rating for the host.
class BillScreen extends StatefulWidget {
  const BillScreen({super.key, required this.bookingId, required this.sessionId, required this.user});

  final int bookingId;
  final int sessionId;
  final AppUser user;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  Bill? _bill;
  LiveSession? _session;
  String? _error;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Independent requests, fetched at once. Future.wait rethrows the original ApiException.
      final results = await Future.wait([api.bill(widget.bookingId), api.liveSession(widget.sessionId)]);
      final bill = results[0] as Bill;
      final session = results[1] as LiveSession;
      if (mounted) {
        setState(() {
          _bill = bill;
          _session = session;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    super.dispose();
  }

  Future<void> _pay(Bill b) async {
    setState(() => _paying = true);
    try {
      // The server creates the order; without Razorpay keys it answers "demo".
      final order = await api.createOrder(b.bookingId);
      if (!mounted) return;
      final Bill paid;
      if (order.isRazorpay) {
        final success = await _razorpayCheckout(order);
        if (success == null || !mounted) return;
        paid = await _verify(b.bookingId, success);
      } else {
        final approved = b.payablePaise == 0 || await _showUpiSheet(b);
        if (!approved) return;
        paid = await api.demoPay(b.bookingId);
      }
      if (mounted) setState(() => _bill = paid);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Razorpay? _razorpay;

  /// Opens Razorpay Checkout (UPI, cards, netbanking; test mode with test keys).
  /// Completes with the signed result, or null when the driver cancels or the payment fails.
  Future<PaymentSuccessResponse?> _razorpayCheckout(PaymentOrder order) {
    final done = Completer<PaymentSuccessResponse?>();
    final rp = _razorpay ??= Razorpay();
    rp.clear();
    rp.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) done.complete(r);
    });
    rp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (done.isCompleted) return;
      if (mounted) {
        showSnack(
          context,
          r.code == Razorpay.PAYMENT_CANCELLED
              ? 'Payment cancelled'
              : 'Payment failed: ${r.message ?? 'unknown error'}',
        );
      }
      done.complete(null);
    });
    rp.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {
      if (done.isCompleted) return;
      if (mounted) {
        showSnack(context, '${r.walletName ?? 'That wallet'} isn’t supported yet. Please pay with UPI or a card.');
      }
      done.complete(null);
    });
    rp.open({
      'key': order.keyId,
      'order_id': order.orderId,
      'amount': order.payablePaise,
      'currency': 'INR',
      'name': 'Voltra',
      'description': 'EV charging at ${_session?.chargerName ?? 'a Voltra charger'}',
      'prefill': {'name': widget.user.name, 'contact': ?widget.user.phone},
      'theme': {'color': '#0B7A45'},
    });
    return done.future;
  }

  /// The money has moved by now, so a dropped connection is retried once: verifying twice is harmless.
  Future<Bill> _verify(int bookingId, PaymentSuccessResponse r) async {
    Future<Bill> send() => api.verifyPayment(
      bookingId: bookingId,
      orderId: r.orderId ?? '',
      paymentId: r.paymentId ?? '',
      signature: r.signature ?? '',
    );
    try {
      return await send();
    } on ApiException catch (e) {
      if (e.message.startsWith('Lost the connection') || e.message.contains('took too long')) return await send();
      rethrow;
    }
  }

  /// Demo mode (no Razorpay keys on the server): stands in for the UPI app hand-off.
  Future<bool> _showUpiSheet(Bill b) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: VoltraColors.darkGreen),
                  SizedBox(width: 8),
                  Text('Pay with UPI', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Demo mode: no money moves. With Razorpay test keys on the server, this opens Razorpay Checkout.',
                style: TextStyle(color: VoltraColors.muted),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  rupees(b.payablePaise, exact: true),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                ),
              ),
              const Center(
                child: Text('to Voltra', style: TextStyle(color: VoltraColors.muted)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Approve ${rupees(b.payablePaise, exact: true)}'),
              ),
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ],
          ),
        ),
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your bill'), automaticallyImplyLeading: false),
      body: _bill == null || _session == null
          ? (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Center(child: CircularProgressIndicator()))
          : _buildBody(_bill!, _session!),
    );
  }

  Widget _buildBody(Bill b, LiveSession s) {
    final paid = b.status == 'PAID';
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Icon(paid ? Icons.verified : Icons.task_alt, color: VoltraColors.darkGreen, size: 48),
              const SizedBox(height: 8),
              Text(
                rupees(b.payablePaise, exact: true),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: VoltraColors.ink),
              ),
              Text(
                paid
                    ? 'Paid · ${b.energyKwh.toStringAsFixed(3)} kWh at ${s.chargerName}'
                    : 'for ${b.energyKwh.toStringAsFixed(3)} kWh at ${s.chargerName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: paid ? VoltraColors.darkGreen : VoltraColors.muted,
                  fontWeight: paid ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),
              if (paid) ...[_RatingCard(bookingId: b.bookingId, user: widget.user), const SizedBox(height: 12)],
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
                      _Line('Charging total', rupees(b.totalPaise, exact: true), bold: true),
                      if (b.creditPaise > 0)
                        _Line('ChargeSure credit', '− ${rupees(b.creditPaise, exact: true)}', accent: true),
                      _Line(paid ? 'You paid' : 'You pay', rupees(b.payablePaise, exact: true), bold: true),
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
                      _Line('Host receives (85%)', rupees(b.hostSharePaise, exact: true)),
                      _Line('Voltra fee (15%)', rupees(b.platformFeePaise, exact: true)),
                      if (b.creditPaise > 0)
                        const Text(
                          'Voltra pays the ChargeSure credit; the host is still paid in full.',
                          style: TextStyle(color: VoltraColors.muted, fontSize: 12),
                        ),
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
                if (!paid)
                  FilledButton.icon(
                    icon: _paying
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.payments_outlined),
                    label: Text(
                      b.payablePaise == 0
                          ? 'Confirm (covered by ChargeSure credit)'
                          : 'Pay ${rupees(b.payablePaise, exact: true)} with UPI',
                    ),
                    onPressed: _paying ? null : () => _pay(b),
                  ),
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

/// Two-way ratings (PRD F14): the driver rates the host after paying.
class _RatingCard extends StatefulWidget {
  const _RatingCard({required this.bookingId, required this.user});

  final int bookingId;
  final AppUser user;

  @override
  State<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<_RatingCard> {
  static const _tags = ['Easy to find', 'Charger worked well', 'Friendly host', 'Safe spot'];

  int _stars = 0;
  final Set<String> _picked = {};
  bool _sending = false;
  bool _done = false;

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await api.submitReview(
        bookingId: widget.bookingId,
        reviewerId: widget.user.id,
        rating: _stars,
        tags: _picked.toList(),
      );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.favorite, color: VoltraColors.darkGreen),
          title: Text('Thanks for rating your host'),
          subtitle: Text('Your rating shows on this charger’s listing.'),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How was your charge?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star${i == 1 ? '' : 's'}',
                    icon: Icon(i <= _stars ? Icons.star : Icons.star_border, color: VoltraColors.amber, size: 32),
                    onPressed: () => setState(() => _stars = i),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in _tags)
                  FilterChip(
                    label: Text(t),
                    selected: _picked.contains(t),
                    onSelected: (on) => setState(() => on ? _picked.add(t) : _picked.remove(t)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: _stars == 0 || _sending ? null : _submit,
              child: const Text('Submit rating'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.accent = false});

  final String label;
  final String value;
  final bool bold;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold || accent ? FontWeight.w700 : FontWeight.w400,
      fontSize: bold ? 17 : 15,
      color: accent ? VoltraColors.darkGreen : null,
    );
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
