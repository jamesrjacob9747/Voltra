import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../api.dart';
import '../design/tokens.dart';
import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/error_view.dart';
import '../widgets/motion.dart';
import '../widgets/primary_bar.dart';
import '../widgets/skeleton.dart';
import '../widgets/snack.dart';
import '../widgets/tab_shell.dart';

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
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _bill = paid);
      }
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
      isScrollControlled: true,
      context: context,
      builder: (context) {
        final vc = context.vc;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.xl, Gap.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, color: vc.brand),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'Pay with UPI',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: vc.ink),
                    ),
                  ],
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  'Demo mode: no money moves. With Razorpay test keys on the server, this opens Razorpay Checkout.',
                  style: TextStyle(color: vc.muted, height: 1.35),
                ),
                const SizedBox(height: Gap.xl),
                Center(
                  child: Text(
                    rupees(b.payablePaise, exact: true),
                    style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: vc.ink, letterSpacing: -1),
                  ),
                ),
                Center(
                  child: Text('to Voltra', style: TextStyle(color: vc.muted)),
                ),
                const SizedBox(height: Gap.xl),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Approve ${rupees(b.payablePaise, exact: true)}'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: vc.muted),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );
    return ok ?? false;
  }

  /// Back to the driver's home shell, on its Home (map) tab, whichever tab the bill came from.
  void _backToMap() {
    TabShell.current?.goTo(0);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final b = _bill;
    final s = _session;
    final loaded = b != null && s != null;
    final paid = b?.status == 'PAID';
    final backLink = TextButton(
      style: TextButton.styleFrom(foregroundColor: context.vc.muted),
      onPressed: _backToMap,
      child: const Text('Back to map'),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Your bill'), automaticallyImplyLeading: false),
      body: loaded
          ? _buildBody(b, s)
          : (_error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : const Shimmer(
                    child: Padding(
                      padding: EdgeInsets.all(Gap.lg),
                      child: Column(
                        children: [
                          SizedBox(height: Gap.lg),
                          Skeleton.circle(72),
                          SizedBox(height: Gap.lg),
                          Skeleton(width: 180, height: 40),
                          SizedBox(height: Gap.xl),
                          Skeleton(height: 220, radius: Radii.lg),
                        ],
                      ),
                    ),
                  )),
      bottomNavigationBar: !loaded
          ? null
          : paid
          ? PrimaryBar(icon: Icons.map_outlined, label: 'Back to map', onPressed: _backToMap)
          : PrimaryBar(
              icon: Icons.payments_outlined,
              label: b.payablePaise == 0
                  ? 'Confirm · paid by credit'
                  : 'Pay ${rupees(b.payablePaise, exact: true)} with UPI',
              busy: _paying,
              onPressed: () => _pay(b),
              secondary: backLink,
            ),
    );
  }

  Widget _buildBody(Bill b, LiveSession s) {
    final vc = context.vc;
    final paid = b.status == 'PAID';
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.lg, Gap.lg, Gap.xl),
      children: [
        Center(
          child: SizedBox(
            height: 72,
            child: AnimatedSwitcher(
              duration: Motion.medium,
              child: paid
                  ? const AnimatedCheck(key: ValueKey('paid'))
                  : Container(
                      key: const ValueKey('due'),
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(color: vc.brandTint, shape: BoxShape.circle),
                      child: Icon(Icons.receipt_long, color: vc.brand, size: 34),
                    ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Center(
          child: CountUp(
            value: b.payablePaise.toDouble(),
            format: (v) => rupees(v.round(), exact: true),
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              color: vc.ink,
              letterSpacing: -1.5,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: Motion.medium,
          child: Text(
            paid
                ? 'Paid · ${b.energyKwh.toStringAsFixed(3)} kWh at ${s.chargerName}'
                : 'for ${b.energyKwh.toStringAsFixed(3)} kWh at ${s.chargerName}',
            key: ValueKey(paid),
            textAlign: TextAlign.center,
            style: TextStyle(color: paid ? vc.success : vc.muted, fontWeight: paid ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
        const SizedBox(height: Gap.xl),
        // The rating slides in once the payment is through.
        AnimatedSize(
          duration: Motion.slow,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: paid
              ? Padding(
                  padding: const EdgeInsets.only(bottom: Gap.md),
                  child: Entrance(
                    child: _RatingCard(bookingId: b.bookingId, user: widget.user),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Entrance(
          index: 1,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                children: [
                  // Three decimals, as billed: kWh × rate must visibly equal the total.
                  _Line('Energy (smart meter)', '${b.energyKwh.toStringAsFixed(3)} kWh'),
                  _Line('Rate', pricePerKwh(s.pricePerKwhPaise)),
                  _Line('Charging time', elapsed(s.durationS)),
                  const Divider(height: Gap.xl),
                  _Line('Charging total', rupees(b.totalPaise, exact: true), bold: true),
                  if (b.creditPaise > 0)
                    _Line('ChargeSure credit', '− ${rupees(b.creditPaise, exact: true)}', accent: true),
                  _Line(paid ? 'You paid' : 'You pay', rupees(b.payablePaise, exact: true), bold: true),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: Gap.md),
        Entrance(
          index: 2,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Where your money goes',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                  ),
                  const SizedBox(height: Gap.md),
                  // 85 : 15, drawn to scale.
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.pill),
                      child: Row(
                        children: [
                          Expanded(flex: 85, child: Container(height: 10, color: vc.brand)),
                          const SizedBox(width: 3),
                          Expanded(flex: 15, child: Container(height: 10, color: vc.faint)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.md),
                  _Line('Host receives (85%)', rupees(b.hostSharePaise, exact: true), dot: vc.brand),
                  _Line('Voltra fee (15%)', rupees(b.platformFeePaise, exact: true), dot: vc.faint),
                  if (b.creditPaise > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: Gap.xs),
                      child: Text(
                        'Voltra pays the ChargeSure credit; the host is still paid in full.',
                        style: TextStyle(color: vc.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
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
    final vc = context.vc;
    final still = Motion.reduced(context);
    final Widget content;
    if (_done) {
      content = Row(
        key: const ValueKey('thanks'),
        children: [
          Icon(Icons.favorite, color: vc.brand),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thanks for rating your host',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc.ink),
                ),
                Text('Your rating shows on this charger’s listing.', style: TextStyle(color: vc.muted)),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your charge?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: vc.ink),
          ),
          const SizedBox(height: Gap.xs),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  // Each chosen star pops, one after the other, up to the one tapped.
                  icon: AnimatedScale(
                    scale: i <= _stars ? 1.15 : 1,
                    duration: still ? Duration.zero : Motion.medium + Motion.stagger * i,
                    curve: Curves.easeOutBack,
                    child: Icon(
                      i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: i <= _stars ? vc.warning : vc.faint,
                      size: 36,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _stars = i);
                  },
                ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final t in _tags)
                FilterChip(
                  label: Text(t),
                  selected: _picked.contains(t),
                  onSelected: (on) => setState(() => on ? _picked.add(t) : _picked.remove(t)),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: _stars == 0 || _sending ? null : _submit,
            child: const Text('Submit rating'),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: AnimatedSize(
          duration: Motion.medium,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(duration: Motion.medium, child: content),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.accent = false, this.dot});

  final String label;
  final String value;
  final bool bold;
  final bool accent;

  /// A colour key before the label, matching a segment of the split bar.
  final Color? dot;

  @override
  Widget build(BuildContext context) {
    final vc = context.vc;
    final color = accent ? vc.success : (bold ? vc.ink : vc.muted);
    final style = TextStyle(
      fontWeight: bold || accent ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (dot != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: Gap.sm),
          ],
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style.copyWith(
              color: accent ? vc.success : vc.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
