import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../data/bills_repository.dart';
import '../../models/maintenance_bill.dart';
import '../../models/user_role.dart';
import '../bill_kind_tag.dart';

// ============================ shared helpers ============================

Color get _accent => UserRole.resident.color;

String _money(double amount) => '₹${amount.toStringAsFixed(0)}';

double _sumOf(List<MaintenanceBill> bills) =>
    bills.fold<double>(0, (s, b) => s + b.amount);

/// Loads a logo asset, picking SVG vs raster.
Widget _logoImage(String asset) => asset.toLowerCase().endsWith('.svg')
    ? SvgPicture.asset(asset, fit: BoxFit.contain)
    : Image.asset(asset, fit: BoxFit.contain);

/// A soft, rounded, filled input field used across the checkout screens.
InputDecoration _inputDeco(BuildContext context,
        {required String label, String? hint, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accent, width: 1.5),
      ),
    );

/// The green "Amount to pay" header shown on every checkout screen.
Widget _amountHeader(double total) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, _accent.withValues(alpha: 0.75)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Amount to pay', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(_money(total),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );

/// The bottom action bar (no amount — that's already in the header).
Widget _payBar({
  required bool processing,
  required VoidCallback? onPay,
  String label = 'Pay',
}) =>
    SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            minimumSize: const Size.fromHeight(52),
          ),
          onPressed: processing ? null : onPay,
          child: processing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white),
                )
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );

/// The success confirmation shown once a payment goes through.
Widget _successView(
  BuildContext context, {
  required double total,
  required int count,
  required VoidCallback onDone,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accent.withValues(alpha: 0.12),
          ),
          child: Icon(Icons.check_circle, color: _accent, size: 64),
        ),
        const SizedBox(height: 24),
        Text('Payment successful',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('${_money(total)} paid for $count bill${count == 1 ? '' : 's'}',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: onDone,
            child: const Text('Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    ),
  );
}

enum _Stage { form, processing, done }

// ============================ method chooser ============================

/// Step 1 of checkout: pick a payment method (and its sub-option). UPI pays
/// right here; card / net-banking hand off to a details screen on Pay.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.bills});

  final List<MaintenanceBill> bills;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PayMethod {
  const _PayMethod(this.id, this.label, this.subtitle, this.icon);
  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
}

class _UpiApp {
  const _UpiApp(this.id, this.label, this.asset, {this.fill = false});
  final String id;
  final String label;
  final String asset;

  /// True for full app-icon images (their own background) → clip edge-to-edge.
  final bool fill;
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _methods = [
    _PayMethod('upi', 'UPI', 'Google Pay, PhonePe, Paytm & more',
        Icons.account_balance_wallet_outlined),
    _PayMethod('card', 'Credit / Debit Card', 'Visa, Mastercard, RuPay',
        Icons.credit_card),
    _PayMethod('netbanking', 'Net Banking', 'All major banks',
        Icons.account_balance_outlined),
  ];

  static const _upiApps = [
    _UpiApp('gpay', 'Google Pay', 'assets/logos/gpay.jpeg', fill: true),
    _UpiApp('phonepe', 'PhonePe', 'assets/logos/phonepe.svg'),
    _UpiApp('paytm', 'Paytm', 'assets/logos/paytm.png', fill: true),
  ];

  // (name, logo asset or null → generic icon, fill = clip edge-to-edge for
  // logos that carry their own background)
  static const _banks = <(String, String?, bool)>[
    ('HDFC Bank', 'assets/logos/hdfc.svg', false),
    ('ICICI Bank', 'assets/logos/icici.svg', false),
    ('Axis Bank', 'assets/logos/axis.svg', false),
    ('State Bank of India', 'assets/logos/sbi.svg', false),
    ('Kotak Mahindra Bank', 'assets/logos/kotak.png', false),
    ('Punjab National Bank', 'assets/logos/pnb.jpeg', true),
    ('Bank of Baroda', 'assets/logos/bob.png', false),
    ('Yes Bank', 'assets/logos/yes.png', false),
    ('IDFC First Bank', 'assets/logos/idfc.png', true),
    ('Canara Bank', 'assets/logos/canara.png', false),
    ('Union Bank of India', 'assets/logos/union.png', false),
    ('IndusInd Bank', 'assets/logos/indusind.jpeg', true),
  ];

  static const _cardNetworks = <(String, String, String)>[
    ('visa', 'Visa', 'assets/logos/visa.svg'),
    ('mastercard', 'Mastercard', 'assets/logos/mastercard.svg'),
    ('rupay', 'RuPay', 'assets/logos/rupay.png'),
  ];

  String _method = 'upi';
  String _upiApp = 'gpay';
  String _cardNetwork = '';
  String _bank = '';
  String _bankQuery = '';
  _Stage _stage = _Stage.form;

  double get _total => _sumOf(widget.bills);

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _onPay() async {
    switch (_method) {
      case 'card':
        if (_cardNetwork.isEmpty) {
          _snack('Choose a card type first');
          return;
        }
        final net = _cardNetworks.firstWhere((n) => n.$1 == _cardNetwork);
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => _CardDetailsScreen(
              bills: widget.bills, network: net.$2, networkAsset: net.$3),
        ));
        if (ok == true && mounted) Navigator.of(context).pop(true);
      case 'netbanking':
        if (_bank.isEmpty) {
          _snack('Choose your bank first');
          return;
        }
        final b = _banks.firstWhere((x) => x.$1 == _bank);
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => _BankDetailsScreen(
              bills: widget.bills, bank: b.$1, asset: b.$2, fill: b.$3),
        ));
        if (ok == true && mounted) Navigator.of(context).pop(true);
      default: // upi — pay right here
        await _payInline();
    }
  }

  Future<void> _payInline() async {
    setState(() => _stage = _Stage.processing);
    try {
      await BillsRepository.instance.payMany(widget.bills);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _stage = _Stage.done);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.form);
      _snack('Payment failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: _stage != _Stage.processing,
      ),
      body: _stage == _Stage.done
          ? _successView(context,
              total: _total,
              count: widget.bills.length,
              onDone: () => Navigator.of(context).pop(true))
          : _buildForm(),
      bottomNavigationBar: _stage == _Stage.done
          ? null
          : _payBar(
              processing: _stage == _Stage.processing,
              onPay: _onPay,
              // Card / bank go to a details screen next; UPI pays here.
              label: _method == 'upi' ? 'Pay' : 'Continue'),
    );
  }

  Widget _buildForm() {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        _amountHeader(_total),
        const SizedBox(height: 24),
        _label('Paying for', theme),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (final b in widget.bills)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      BillKindTag(bill: b, accent: _accent),
                      const SizedBox(width: 8),
                      Text(b.period, style: theme.textTheme.bodyMedium),
                      const Spacer(),
                      Text(_money(b.amount),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _label('Payment method', theme),
        const SizedBox(height: 8),
        for (final m in _methods) ...[
          _methodTile(m, theme),
          _expander(
              open: _method == m.id,
              child: switch (m.id) {
                'upi' => _upiAppsPanel(theme),
                'card' => _cardPanel(theme),
                'netbanking' => _bankPanel(theme),
                _ => const SizedBox.shrink(),
              }),
        ],
      ],
    );
  }

  Widget _expander({required bool open, required Widget child}) => AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: open ? child : const SizedBox(width: double.infinity),
      );

  Widget _upiAppsPanel(ThemeData theme) => _panelBox(
        theme,
        Column(
          children: [
            for (final a in _upiApps)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _upiApp = a.id),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                  child: Row(
                    children: [
                      _logoCircle(a.asset, fill: a.fill),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(a.label,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      _RadioDot(selected: _upiApp == a.id, accent: _accent),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _cardPanel(ThemeData theme) => _panelBox(
        theme,
        Column(
          children: [
            for (final n in _cardNetworks)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _cardNetwork = n.$1),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                  child: Row(
                    children: [
                      _BrandLogo(asset: n.$3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(n.$2,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      _RadioDot(
                          selected: _cardNetwork == n.$1, accent: _accent),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _bankPanel(ThemeData theme) {
    final query = _bankQuery.trim().toLowerCase();
    final matches =
        _banks.where((b) => b.$1.toLowerCase().contains(query)).toList();
    return _panelBox(
      theme,
      Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _bankQuery = v),
            decoration: InputDecoration(
              hintText: 'Search your bank',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide(color: _accent, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 4),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('No banks found', style: theme.textTheme.bodySmall),
            )
          else
            for (final b in matches)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => _bank = b.$1),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
                  child: Row(
                    children: [
                      _bankLeading(b.$2, b.$3),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(b.$1,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      _RadioDot(selected: _bank == b.$1, accent: _accent),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _bankLeading(String? asset, bool fill) {
    if (asset != null) return _logoCircle(asset, fill: fill);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _accent.withValues(alpha: 0.10),
      ),
      child: Icon(Icons.account_balance_outlined, size: 20, color: _accent),
    );
  }

  Widget _panelBox(ThemeData theme, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );

  Widget _label(String text, ThemeData theme) => Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );

  Widget _methodTile(_PayMethod m, ThemeData theme) {
    final selected = _method == m.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected
            ? _accent.withValues(alpha: 0.08)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _method = m.id),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _accent : theme.colorScheme.outlineVariant,
                width: selected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(m.icon, color: _accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(m.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                _RadioDot(selected: selected, accent: _accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================ card details ============================

/// Step 2 for cards: enter the card, then pay.
class _CardDetailsScreen extends StatefulWidget {
  const _CardDetailsScreen({
    required this.bills,
    required this.network,
    required this.networkAsset,
  });

  final List<MaintenanceBill> bills;
  final String network;
  final String networkAsset;

  @override
  State<_CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<_CardDetailsScreen> {
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _name = TextEditingController();
  _Stage _stage = _Stage.form;

  double get _total => _sumOf(widget.bills);

  @override
  void dispose() {
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
    super.dispose();
  }

  InputDecoration _fieldDeco(
          {required String label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      );

  /// A live preview of the card being entered, styled like a real one.
  Widget _cardPreview() {
    final digits = _number.text;
    final groups = <String>[];
    for (var i = 0; i < 16; i += 4) {
      final g = i < digits.length
          ? digits.substring(i, (i + 4).clamp(0, digits.length))
          : '';
      groups.add(g.padRight(4, '•'));
    }
    return Container(
      height: 190,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2B3A55), Color(0xFF1B2436)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, color: Color(0xFFE6C06B), size: 34),
              const Spacer(),
              Container(
                width: 54,
                height: 34,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _logoImage(widget.networkAsset),
              ),
            ],
          ),
          const Spacer(),
          Text(groups.join('   '),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                    _name.text.isEmpty
                        ? 'CARDHOLDER NAME'
                        : _name.text.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 1)),
              ),
              Text(_expiry.text.isEmpty ? 'MM/YY' : _expiry.text,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13, letterSpacing: 1)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    if (_number.text.trim().length < 12 ||
        _expiry.text.trim().isEmpty ||
        _cvv.text.trim().length < 3 ||
        _name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fill in your card details')),
      );
      return;
    }
    setState(() => _stage = _Stage.processing);
    try {
      await BillsRepository.instance.payMany(widget.bills);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _stage = _Stage.done);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.form);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.network} Card'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: _stage != _Stage.processing,
      ),
      body: _stage == _Stage.done
          ? _successView(context,
              total: _total,
              count: widget.bills.length,
              onDone: () => Navigator.of(context).pop(true))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _amountHeader(_total),
                const SizedBox(height: 20),
                _cardPreview(),
                const SizedBox(height: 20),
                TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                  ],
                  decoration: _fieldDeco(
                    label: 'Card number',
                    hint: '1234 5678 9012 3456',
                    icon: Icons.credit_card,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _expiry,
                        keyboardType: TextInputType.datetime,
                        onChanged: (_) => setState(() {}),
                        inputFormatters: [LengthLimitingTextInputFormatter(5)],
                        decoration:
                            _fieldDeco(label: 'Expiry', hint: 'MM/YY'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cvv,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        decoration: _fieldDeco(label: 'CVV', hint: '123'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: _fieldDeco(
                    label: 'Name on card',
                    icon: Icons.person_outline,
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _stage == _Stage.done
          ? null
          : _payBar(processing: _stage == _Stage.processing, onPay: _pay),
    );
  }
}

// ============================ net banking ============================

/// Step 2 for net banking: log in to the chosen bank, then pay.
class _BankDetailsScreen extends StatefulWidget {
  const _BankDetailsScreen({
    required this.bills,
    required this.bank,
    this.asset,
    this.fill = false,
  });

  final List<MaintenanceBill> bills;
  final String bank;
  final String? asset;
  final bool fill;

  @override
  State<_BankDetailsScreen> createState() => _BankDetailsScreenState();
}

class _BankDetailsScreenState extends State<_BankDetailsScreen> {
  final _accountNo = TextEditingController();
  final _ifsc = TextEditingController();
  final _holder = TextEditingController();
  _Stage _stage = _Stage.form;

  double get _total => _sumOf(widget.bills);

  @override
  void dispose() {
    _accountNo.dispose();
    _ifsc.dispose();
    _holder.dispose();
    super.dispose();
  }

  /// A card showing which bank you're paying from — its logo and name.
  Widget _bankHeaderCard(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          if (widget.asset != null)
            _logoCircle(widget.asset!, fill: widget.fill)
          else
            Icon(Icons.account_balance, color: _accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.bank,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('NetBanking',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          Icon(Icons.verified_user_outlined,
              size: 20, color: _accent.withValues(alpha: 0.7)),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    if (_accountNo.text.trim().length < 6 ||
        _ifsc.text.trim().isEmpty ||
        _holder.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your bank account details')),
      );
      return;
    }
    setState(() => _stage = _Stage.processing);
    try {
      await BillsRepository.instance.payMany(widget.bills);
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() => _stage = _Stage.done);
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.form);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.bank),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: _stage != _Stage.processing,
      ),
      body: _stage == _Stage.done
          ? _successView(context,
              total: _total,
              count: widget.bills.length,
              onDone: () => Navigator.of(context).pop(true))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                _amountHeader(_total),
                const SizedBox(height: 20),
                _bankHeaderCard(context),
                const SizedBox(height: 20),
                Text('ENTER YOUR ACCOUNT DETAILS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        )),
                const SizedBox(height: 12),
                TextField(
                  controller: _accountNo,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(18),
                  ],
                  decoration: _inputDeco(context,
                      label: 'Account number',
                      icon: Icons.account_balance_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _ifsc,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(11),
                    UpperCaseTextFormatter(),
                  ],
                  decoration: _inputDeco(context,
                      label: 'IFSC code',
                      hint: 'e.g. HDFC0001234',
                      icon: Icons.tag),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _holder,
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco(context,
                      label: 'Account holder name',
                      icon: Icons.person_outline),
                ),
              ],
            ),
      bottomNavigationBar: _stage == _Stage.done
          ? null
          : _payBar(processing: _stage == _Stage.processing, onPay: _pay),
    );
  }
}

// ============================ small shared widgets ============================

/// A brand logo mark. [fill] app-icon images fill the circle edge-to-edge;
/// transparent symbols sit on a padded white circle.
Widget _logoCircle(String asset, {bool fill = false}) {
  if (fill) {
    return ClipOval(
      child: Image.asset(asset, width: 40, height: 40, fit: BoxFit.cover),
    );
  }
  return Container(
    width: 40,
    height: 40,
    padding: const EdgeInsets.all(7),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      border: Border.all(color: const Color(0x1F000000)),
    ),
    child: _logoImage(asset),
  );
}

/// A brand logo (SVG or PNG) on a clean white tile.
class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: _logoImage(asset),
    );
  }
}

/// Forces typed text to upper case (IFSC codes are upper case).
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// The trailing radio indicator on a selectable row.
class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.accent});

  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : Theme.of(context).colorScheme.outline,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}
