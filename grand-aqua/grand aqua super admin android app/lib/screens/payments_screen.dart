import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _isLoading = true;
  List<dynamic> _payments = [];
  Map<String, dynamic>? _receivablesSummary;
  List<dynamic> _buyers = [];

  String _searchQuery = '';
  String _selectedMethod = 'ALL';

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final pRes = await api.dio.get('/payments?limit=100');
      final rRes = await api.dio.get('/payments/receivables-summary');
      final bRes = await api.dio.get('/buyers?limit=100');

      if (mounted) {
        setState(() {
          final pData = pRes.data['data'] ?? pRes.data;
          _payments = pData['payments'] ?? [];
          _receivablesSummary = rRes.data['data'] ?? rRes.data;
          final bData = bRes.data['data'] ?? bRes.data;
          _buyers = bData['buyers'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load payments: $e')),
        );
      }
    }
  }

  void _showRecordPaymentDialog() {
    if (_buyers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No buyers found to record payment for.')),
      );
      return;
    }

    String selectedBuyerId = _buyers.first['id'];
    String selectedMethod = 'UPI';
    final amountCtrl = TextEditingController();
    final txnRefCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Payment Entry',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Buyer Select
                const Text('Select Trade Buyer *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedBuyerId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: _buyers.map<DropdownMenuItem<String>>((b) {
                    final bName = b['businessName'] ?? b['user']?['fullName'] ?? 'Buyer';
                    final bCode = b['buyerId'] ?? '';
                    return DropdownMenuItem<String>(
                      value: b['id'],
                      child: Text('$bName ($bCode)', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedBuyerId = val);
                  },
                ),
                const SizedBox(height: 14),

                // Amount
                const Text('Settlement Amount (₹) *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Enter amount (e.g. 25000)',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Payment Method
                const Text('Payment Instrument *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR Code')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT / RTGS)')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Cheque / Demand Draft')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash Receipt')),
                  ],
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedMethod = val);
                  },
                ),
                const SizedBox(height: 14),

                // Txn Ref
                const Text('Transaction Reference / Cheque #', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: txnRefCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. UPI/1234567890 or CHQ-998811',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes
                const Text('Notes / Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Payment remarks, deposit branch...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final parsed = double.tryParse(amountCtrl.text.trim());
                            if (parsed == null || parsed <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a valid amount')),
                              );
                              return;
                            }

                            setSheetState(() => isSubmitting = true);
                            try {
                              final api = ref.read(apiClientProvider);
                              await api.dio.post('/payments', data: {
                                'buyerProfileId': selectedBuyerId,
                                'amount': parsed,
                                'paymentMethod': selectedMethod,
                                'transactionReference': txnRefCtrl.text.trim().isEmpty ? null : txnRefCtrl.text.trim(),
                                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              });

                              if (context.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Payment recorded & reconciled successfully')),
                                );
                                _fetchData();
                              }
                            } catch (err) {
                              setSheetState(() => isSubmitting = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to record payment: $err')),
                                );
                              }
                            }
                          },
                    child: isSubmitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm & Reconcile Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPayments = _payments.where((p) {
      final buyerName = (p['buyer']?['businessName'] ?? p['buyer']?['user']?['fullName'] ?? '').toString().toLowerCase();
      final rNumber = (p['receiptNumber'] ?? '').toString().toLowerCase();
      final refNum = (p['transactionReference'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = buyerName.contains(q) || rNumber.contains(q) || refNum.contains(q);

      final matchesMethod = _selectedMethod == 'ALL' || p['paymentMethod'] == _selectedMethod;
      return matchesSearch && matchesMethod;
    }).toList();

    final totalOutstanding = (_receivablesSummary?['totalOutstanding'] ?? 0).toDouble();
    final debtorsCount = _receivablesSummary?['count'] ?? 0;
    final topDebtors = (_receivablesSummary?['debtors'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payments & Receivables', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Settlements & Balance Reconciliation', style: TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/payments'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRecordPaymentDialog,
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchData,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  // Receivables Overview Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL MARKET RECEIVABLES',
                              style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$debtorsCount Debtors',
                                style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currency.format(totalOutstanding),
                          style: const TextStyle(
                            color: Color(0xFFFBBF24),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Unsettled dues across trade partners & active buyers',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),

                  // Top Debtors Section
                  if (topDebtors.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('Top Outstanding Debtors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155))),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 70,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: topDebtors.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 10),
                        itemBuilder: (ctx, i) {
                          final d = topDebtors[i];
                          final dName = d['businessName'] ?? d['user']?['fullName'] ?? 'Trade Buyer';
                          final dBalance = (d['outstandingBalance'] ?? 0).toDouble();

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(dName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1),
                                const SizedBox(height: 2),
                                Text(
                                  _currency.format(dBalance),
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.amber, fontSize: 12, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Search Field
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search receipt #, buyer name, reference...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['ALL', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'CASH'].map((m) {
                        final isSel = _selectedMethod == m;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(m.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                            selected: isSel,
                            selectedColor: const Color(0xFF0284C7).withOpacity(0.15),
                            onSelected: (_) => setState(() => _selectedMethod = m),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Payment Records List
                  if (filteredPayments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('No payment entries recorded.', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else
                    ...filteredPayments.map((p) {
                      final buyer = p['buyer'];
                      final buyerName = buyer?['businessName'] ?? buyer?['user']?['fullName'] ?? 'Direct Buyer';
                      final buyerCode = buyer?['buyerId'] ?? '';
                      final amt = (p['amount'] ?? 0).toDouble();
                      final method = p['paymentMethod'] ?? 'UPI';
                      final rNum = p['receiptNumber'] ?? 'REC-####';
                      final txnRef = p['transactionReference'];
                      final notes = p['notes'];
                      final dateStr = p['createdAt'] != null ? _dateFormat.format(DateTime.parse(p['createdAt'])) : 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(rNum, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7))),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: p['gatewayProvider'] == 'RAZORPAY'
                                              ? const Color(0xFF0284C7).withOpacity(0.12)
                                              : p['gatewayProvider'] == 'CASHFREE'
                                                  ? const Color(0xFF7C3AED).withOpacity(0.12)
                                                  : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: p['gatewayProvider'] == 'RAZORPAY'
                                                ? const Color(0xFF0284C7).withOpacity(0.3)
                                                : p['gatewayProvider'] == 'CASHFREE'
                                                    ? const Color(0xFF7C3AED).withOpacity(0.3)
                                                    : Colors.green.shade200,
                                          ),
                                        ),
                                        child: Text(
                                          p['gatewayProvider'] != null
                                              ? '${p['gatewayProvider']} PG'
                                              : method.replaceAll('_', ' '),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                            color: p['gatewayProvider'] == 'RAZORPAY'
                                                ? const Color(0xFF0284C7)
                                                : p['gatewayProvider'] == 'CASHFREE'
                                                    ? const Color(0xFF7C3AED)
                                                    : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    _currency.format(amt),
                                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.store_mall_directory_outlined, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$buyerName ($buyerCode)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (txnRef != null && txnRef.toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.tag, size: 14, color: Colors.grey),
                                    const SizedBox(width: 6),
                                    Text('Ref: $txnRef', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'monospace')),
                                  ],
                                ),
                              ],
                              if (notes != null && notes.toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Remarks: $notes', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54)),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  const Row(
                                    children: [
                                      Icon(Icons.check_circle, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text('Reconciled', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}
