import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class CreditScreen extends ConsumerStatefulWidget {
  const CreditScreen({super.key});

  @override
  ConsumerState<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends ConsumerState<CreditScreen> {
  bool _isLoading = true;
  List<dynamic> _accounts = [];
  String _searchQuery = '';
  String _selectedCategory = 'ALL';

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  final List<Map<String, dynamic>> _presetCycles = [
    {'days': 7, 'label': '7 Days'},
    {'days': 15, 'label': '15 Days'},
    {'days': 30, 'label': '30 Days'},
    {'days': 45, 'label': '45 Days'},
    {'days': 60, 'label': '60 Days'},
    {'days': 90, 'label': '90 Days'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/credit/accounts');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _accounts = data is List ? data : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load credit accounts: $e')),
        );
      }
    }
  }

  void _showAdjustLimitDialog(Map<String, dynamic> acc) {
    final buyer = acc['buyer'] ?? {};
    final buyerName = buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer';
    final buyerCode = buyer['buyerId'] ?? 'BUY-ID';
    final buyerProfileId = buyer['id'] ?? acc['buyerProfileId'];

    final double currentLimit = ((acc['creditLimit'] ?? 0) as num).toDouble();
    final double currentUtilized = ((acc['utilizedCredit'] ?? acc['currentUtilized'] ?? 0) as num).toDouble();
    final double currentAvailable = ((acc['availableCredit'] ?? (currentLimit - currentUtilized)) as num).toDouble();
    final int currentTerms = (acc['paymentTermsDays'] ?? 15) as int;

    final limitCtrl = TextEditingController(text: currentLimit.toInt().toString());
    final termsCtrl = TextEditingController(text: currentTerms.toString());
    final reasonCtrl = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final double parsedNewLimit = double.tryParse(limitCtrl.text.trim()) ?? 0.0;
          final int parsedTerms = int.tryParse(termsCtrl.text.trim()) ?? 15;
          final double limitDiff = parsedNewLimit - currentLimit;
          final double newAvailable = math.max(0.0, parsedNewLimit - currentUtilized);
          final bool isOverUtilized = parsedNewLimit > 0 && parsedNewLimit < currentUtilized;
          final double projectedPercent = parsedNewLimit > 0 ? (currentUtilized / parsedNewLimit).clamp(0.0, 1.0) : 0.0;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.credit_card, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        buyerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        buyerCode,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    // Current Standing & Live Utilization Card
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.insights, size: 13, color: Color(0xFF0284C7)),
                              SizedBox(width: 4),
                              Text(
                                'CURRENT STANDING & LIVE UTILIZATION',
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Current Limit', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      _currency.format(currentLimit),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Credit Used Now', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      _currency.format(currentUtilized),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: currentUtilized > 0 ? Colors.amber.shade800 : Colors.black87,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Available', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                    Text(
                                      _currency.format(currentAvailable),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green, fontFamily: 'monospace'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Approved Limit Custom Input & Real-Time Calculation
                    const Text('New Approved Credit Limit (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: limitCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Dynamic variance & projected balance
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Limit Variance:', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                              Text(
                                limitDiff > 0
                                    ? '+${_currency.format(limitDiff)} (Increase)'
                                    : limitDiff < 0
                                        ? '-${_currency.format(limitDiff.abs())} (Reduction)'
                                        : 'No change',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: limitDiff > 0
                                      ? Colors.green.shade700
                                      : limitDiff < 0
                                          ? Colors.amber.shade800
                                          : Colors.grey,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('New Available Balance:', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                              Text(
                                _currency.format(newAvailable),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Projected Utilization:', style: TextStyle(fontSize: 10, color: Colors.blueGrey)),
                              Text(
                                '${(projectedPercent * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (isOverUtilized) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Warning: Limit is lower than credit used now (${_currency.format(currentUtilized)}). Excess: ${_currency.format(currentUtilized - parsedNewLimit)}',
                                style: TextStyle(fontSize: 10, color: Colors.red.shade800, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Payment Term Cycle - CUSTOM TYPING & QUICK PRESETS
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Payment Term Cycle (Days) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Custom Typing', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Custom Typing TextField
                    TextField(
                      controller: termsCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Type any custom days (e.g. 7, 15, 21, 30, 45, 60)...',
                        suffixText: 'Days Net',
                        suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Quick Preset Chips
                    const Text('Quick Presets (Tap to fill):', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _presetCycles.map((p) {
                        final isSel = parsedTerms == p['days'];
                        return ActionChip(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          label: Text(p['label'] as String, style: TextStyle(fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : Colors.black87)),
                          backgroundColor: isSel ? const Color(0xFF0284C7) : Colors.grey.shade100,
                          onPressed: () {
                            termsCtrl.text = p['days'].toString();
                            setDialogState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Buyer has $parsedTerms days grace period from dispatch to settle invoices.',
                      style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                    ),

                    const SizedBox(height: 14),

                    // Reason for audit trail
                    const Text('Adjustment Reason (Audit Trail) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'e.g. Approved seasonal trade enhancement based on healthy track record.',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final newLimit = double.tryParse(limitCtrl.text.trim());
                        final terms = int.tryParse(termsCtrl.text.trim());
                        final reason = reasonCtrl.text.trim();

                        if (newLimit == null || terms == null || reason.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please fill all required fields.')),
                          );
                          return;
                        }

                        setDialogState(() => isSaving = true);
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.dio.put('/credit/buyer/$buyerProfileId/limit', data: {
                            'creditLimit': newLimit,
                            'paymentTermsDays': terms,
                            'reason': reason,
                          });

                          if (context.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Credit facility & terms updated successfully')),
                            );
                            _fetchAccounts();
                          }
                        } catch (e) {
                          setDialogState(() => isSaving = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to update credit: $e')),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Limit Adjustment', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic portfolio stats
    double totalLimit = 0;
    double totalUtilized = 0;
    double totalAvailable = 0;
    for (final acc in _accounts) {
      totalLimit += ((acc['creditLimit'] ?? 0) as num).toDouble();
      totalUtilized += ((acc['utilizedCredit'] ?? acc['currentUtilized'] ?? 0) as num).toDouble();
      totalAvailable += ((acc['availableCredit'] ?? 0) as num).toDouble();
    }
    final overallPercent = totalLimit > 0 ? (totalUtilized / totalLimit).clamp(0.0, 1.0) : 0.0;

    final filtered = _accounts.where((acc) {
      final buyer = acc['buyer'] ?? {};
      final bName = (buyer['businessName'] ?? buyer['user']?['fullName'] ?? '').toString().toLowerCase();
      final bCode = (buyer['buyerId'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = bName.contains(q) || bCode.contains(q);

      final bType = buyer['buyerType'] ?? 'CUSTOMER';
      final matchesCategory = _selectedCategory == 'ALL' || bType == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Credit Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Limits, Utilized Credit & Payment Cycles', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAccounts,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/credit'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAccounts,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Dynamic Portfolio Overview Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('TOTAL APPROVED CREDIT', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currency.format(totalLimit),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Credit Used Now', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text(
                                    _currency.format(totalUtilized),
                                    style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text(
                                    _currency.format(totalAvailable),
                                    style: const TextStyle(color: Color(0xFFBBF7D0), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: overallPercent,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFFFDE68A)),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(overallPercent * 100).toStringAsFixed(1)}% of total credit line in active use',
                          style: const TextStyle(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search buyer name or code...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'DEALER', 'WHOLESALER', 'DISTRIBUTOR', 'CUSTOMER'].map((cat) {
                        final isSel = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0284C7).withOpacity(0.15),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.credit_card_off_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No credit facilities found.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...filtered.map((acc) {
                      final buyer = acc['buyer'] ?? {};
                      final bName = buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer';
                      final bCode = buyer['buyerId'] ?? 'ID-####';
                      final bType = buyer['buyerType'] ?? 'CUSTOMER';
                      final limit = ((acc['creditLimit'] ?? 0) as num).toDouble();
                      final utilized = ((acc['utilizedCredit'] ?? acc['currentUtilized'] ?? 0) as num).toDouble();
                      final available = ((acc['availableCredit'] ?? (limit - utilized)) as num).toDouble();
                      final termsDays = (acc['paymentTermsDays'] ?? 15) as int;
                      final percent = limit > 0 ? (utilized / limit).clamp(0.0, 1.0) : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(bName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                        Row(
                                          children: [
                                            Text(bCode, style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(bType, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
                                      foregroundColor: const Color(0xFF0284C7),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    icon: const Icon(Icons.edit, size: 14),
                                    label: const Text('Adjust', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    onPressed: () => _showAdjustLimitDialog(acc),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Credit Metrics Grid
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Approved Limit:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(_currency.format(limit), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Credit Used Now:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(
                                          _currency.format(utilized),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: utilized > 0 ? Colors.amber.shade800 : Colors.black87,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Available Balance:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Text(_currency.format(available), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green, fontFamily: 'monospace')),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: percent,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation(
                                          percent >= 0.8 ? Colors.red : percent >= 0.4 ? Colors.amber : Colors.green,
                                        ),
                                        minHeight: 6,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${(percent * 100).toStringAsFixed(0)}% utilized', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                        Text(
                                          percent >= 0.8 ? 'High Exposure' : 'Normal',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: percent >= 0.8 ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, size: 14, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Payment Cycle: $termsDays Days Net',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: acc['status'] == 'SUSPENDED' ? Colors.red.shade50 : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      acc['status'] ?? 'ACTIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: acc['status'] == 'SUSPENDED' ? Colors.red.shade800 : Colors.green.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
