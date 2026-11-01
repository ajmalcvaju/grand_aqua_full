import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      String url = '/orders?limit=100';
      if (_selectedStatus != 'ALL') {
        url += '&status=$_selectedStatus';
      }
      final res = await api.dio.get(url);
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _orders = data['orders'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load orders: $e')),
        );
      }
    }
  }

  Future<void> _downloadOrderInvoicePdf(Map<String, dynamic> order) async {
    final id = order['id'];
    if (id == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final baseUrl = api.dio.options.baseUrl.replaceAll('/api/v1', '');
      final invoiceUrl = '$baseUrl/api/v1/orders/$id/invoice-pdf';
      final uri = Uri.parse(invoiceUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open invoice: $invoiceUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading invoice: $e')),
        );
      }
    }
  }

  // Update Order Status Dialog
  void _showUpdateStatusDialog(Map<String, dynamic> order) {
    String currentStatus = order['status'] ?? 'PENDING';
    String newStatus = currentStatus;
    final reasonCtrl = TextEditingController(text: 'Status advanced via Super Admin Portal');
    final trackingCtrl = TextEditingController();
    String carrierName = 'Delhivery Express';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Update Order ${order['orderNumber']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Target Order Status:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: newStatus,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'PENDING', child: Text('PENDING')),
                  DropdownMenuItem(value: 'CONFIRMED', child: Text('CONFIRMED (Approved for fulfillment)')),
                  DropdownMenuItem(value: 'PROCESSING', child: Text('PROCESSING (Packing at warehouse)')),
                  DropdownMenuItem(value: 'SHIPPED', child: Text('SHIPPED (In transit / dispatched)')),
                  DropdownMenuItem(value: 'DELIVERED', child: Text('DELIVERED (Handed over to buyer)')),
                  DropdownMenuItem(value: 'CANCELLED', child: Text('CANCELLED (Order aborted)')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => newStatus = val);
                },
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              if (newStatus == 'SHIPPED') ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: carrierName,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'Delhivery Express', child: Text('Delhivery Express')),
                    DropdownMenuItem(value: 'Blue Dart Express', child: Text('Blue Dart Express')),
                    DropdownMenuItem(value: 'V-Trans Cargo Logistics', child: Text('V-Trans Cargo Logistics')),
                    DropdownMenuItem(value: 'DTDC Surface', child: Text('DTDC Surface')),
                    DropdownMenuItem(value: 'Local Transport Fleet', child: Text('Local Transport Fleet')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => carrierName = val);
                  },
                  decoration: const InputDecoration(labelText: 'Carrier Partner', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackingCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dispatch Docket / Tracking Number',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.mark_chat_read, color: Color(0xFF047857), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Automated WhatsApp & SMS alerts with live tracking & GST invoice link will be sent to the buyer upon dispatch.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Status Change Note / Audit Reason',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () async {
                try {
                  final api = ref.read(apiClientProvider);
                  if (newStatus == 'SHIPPED') {
                    await api.dio.put('/orders/${order['id']}/dispatch', data: {
                      'trackingNumber': trackingCtrl.text.trim().isNotEmpty ? trackingCtrl.text.trim() : 'DLV-GA-${order['orderNumber']}',
                      'carrierName': carrierName,
                      'notes': reasonCtrl.text.trim(),
                    });
                  } else {
                    await api.dio.put('/orders/${order['id']}/status', data: {
                      'status': newStatus,
                      'reason': reasonCtrl.text.trim(),
                      'trackingNumber': trackingCtrl.text.trim().isNotEmpty ? trackingCtrl.text.trim() : null,
                    });
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Order ${order['orderNumber']} updated to $newStatus!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                    _fetchOrders();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating status: $e')),
                    );
                  }
                }
              },
              child: const Text('Save Status'),
            ),
          ],
        ),
      ),
    );
  }

  // Record Payment Dialog
  void _showRecordPaymentDialog(Map<String, dynamic> order) {
    final finalAmount = (order['finalAmount'] ?? order['finalTotal'] ?? 0).toDouble();
    final paidAmount = (order['paidAmount'] ?? order['amountPaid'] ?? 0).toDouble();
    final balanceDue = finalAmount - paidAmount;

    final amountCtrl = TextEditingController(text: balanceDue > 0 ? balanceDue.toStringAsFixed(0) : '0');
    final refCtrl = TextEditingController();
    final notesCtrl = TextEditingController(text: 'Payment received against ${order['orderNumber']}');
    String paymentMethod = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Record Payment\n${order['orderNumber']}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Outstanding Balance: ${_currencyFormat.format(balanceDue > 0 ? balanceDue : 0)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFE11D48)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Collection Amount (₹) *',
                    prefixIcon: Icon(Icons.currency_rupee),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: paymentMethod,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'UPI', child: Text('UPI (GPay / PhonePe / Paytm)')),
                    DropdownMenuItem(value: 'CASH', child: Text('Cash in Hand')),
                    DropdownMenuItem(value: 'BANK_TRANSFER', child: Text('Bank Transfer (NEFT / RTGS)')),
                    DropdownMenuItem(value: 'CHEQUE', child: Text('Bank Cheque / DD')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => paymentMethod = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: refCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Transaction / UTR / Cheque Ref No.',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Collection Notes',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount.')),
                  );
                  return;
                }

                try {
                  final api = ref.read(apiClientProvider);
                  await api.dio.post('/payments', data: {
                    'orderId': order['id'],
                    'buyerProfileId': order['buyer']?['id'] ?? order['buyerProfileId'],
                    'amount': amt,
                    'paymentMethod': paymentMethod,
                    'referenceNumber': refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                    'notes': notesCtrl.text.trim(),
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Payment recorded & balance updated!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                    _fetchOrders();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payment recording failed: $e')),
                    );
                  }
                }
              },
              child: const Text('Record Collection'),
            ),
          ],
        ),
      ),
    );
  }

  // Camera Circle Placeholder Icon
  Widget _buildCameraPlaceholder() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.camera_alt_outlined, size: 18, color: Colors.grey.shade400),
          Transform.rotate(
            angle: -0.785, // -45 degrees
            child: Container(
              width: 22,
              height: 1.2,
              color: const Color(0xFFCBD5E1),
            ),
          ),
        ],
      ),
    );
  }

  // Order Detail Bottom Sheet
  Future<void> _showOrderDetailSheet(Map<String, dynamic> summaryOrder) async {
    Map<String, dynamic>? fullOrder;
    bool isLoadingDetail = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          if (fullOrder == null && isLoadingDetail) {
            final api = ref.read(apiClientProvider);
            api.dio.get('/orders/${summaryOrder['id']}').then((res) {
              setSheetState(() {
                fullOrder = res.data['data'] ?? res.data;
                isLoadingDetail = false;
              });
            }).catchError((_) {
              setSheetState(() {
                fullOrder = summaryOrder;
                isLoadingDetail = false;
              });
            });
          }

          final ord = fullOrder ?? summaryOrder;
          final items = (ord['items'] as List<dynamic>?) ?? [];
          final payments = (ord['payments'] as List<dynamic>?) ?? [];
          final buyer = ord['buyer'] ?? {};
          final salesman = ord['salesman'];

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.85,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ord['orderNumber'] ?? 'Order Details',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          ord['createdAt'] != null
                              ? _dateFormat.format(DateTime.parse(ord['createdAt']))
                              : '',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: isLoadingDetail
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          children: [
                            // Buyer & Salesman Box
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    buyer['businessName'] ?? buyer['user']?['fullName'] ?? 'Buyer',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Contact: ${buyer['user']?['mobileNumber'] ?? buyer['user']?['phone'] ?? 'N/A'} • Tier: ${buyer['buyerType'] ?? 'CUSTOMER'}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                  if (salesman != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      'Representative: ${salesman['user']?['fullName']} (${salesman['employeeCode'] ?? 'Staff'})',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Ordered Items
                            const Text(
                              'Ordered Items',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 8),
                            ...items.asMap().entries.map((entry) {
                              final item = entry.value;
                              final pName = item['product']?['name'] ?? item['productName'] ?? 'Product';
                              final pSku = item['product']?['sku'] ?? item['sku'] ?? '';
                              final qty = item['quantity'] ?? 1;
                              final unitPrice = item['unitPrice'] ?? 0;
                              final subtotal = item['subtotal'] ?? (qty * unitPrice);

                              final mediaList = (item['product']?['media'] as List<dynamic>?) ?? [];
                              final imgObj = mediaList.firstWhere((m) => m['mediaType'] == 'IMAGE', orElse: () => null);
                              String thumbUrl = imgObj?['url'] ?? item['product']?['imageUrl'] ?? '';
                              if (thumbUrl.startsWith('/uploads/')) {
                                final api = ref.read(apiClientProvider);
                                thumbUrl = '${api.dio.options.baseUrl.replaceAll('/api/v1', '')}$thumbUrl';
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: thumbUrl.isNotEmpty
                                          ? Image.network(
                                              thumbUrl,
                                              width: 38,
                                              height: 38,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                            )
                                          : _buildCameraPlaceholder(),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pSku.isNotEmpty ? '$pName ($pSku)' : pName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Qty: $qty × ${_currencyFormat.format(unitPrice)}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _currencyFormat.format(subtotal),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              );
                            }),

                            const SizedBox(height: 12),
                            // Financial Breakdown
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                children: [
                                  _buildFinanceRow('Subtotal', _currencyFormat.format(ord['subtotal'] ?? 0)),
                                  _buildFinanceRow('GST / Taxes (${ord['taxRate'] ?? 18}%)', _currencyFormat.format(ord['taxTotal'] ?? ord['taxAmount'] ?? 0)),
                                  const Divider(height: 12),
                                  _buildFinanceRow('Final Total', _currencyFormat.format(ord['finalAmount'] ?? ord['finalTotal'] ?? 0), isBold: true),
                                  _buildFinanceRow('Super Admin Net Profit', '₹${ord['profit'] ?? 0} (${ord['profitMargin'] ?? 0}%)', color: Colors.teal.shade800, isBold: true),
                                  _buildFinanceRow('Amount Paid', _currencyFormat.format(ord['paidAmount'] ?? ord['amountPaid'] ?? 0), color: Colors.green),
                                  _buildFinanceRow('Balance Outstanding', _currencyFormat.format(ord['balanceDue'] ?? ((ord['finalAmount'] ?? 0) - (ord['paidAmount'] ?? 0))), color: Colors.red, isBold: true),
                                ],
                              ),
                            ),

                            if (payments.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const Text('Payment History', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              ...payments.map((p) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                title: Text('${_currencyFormat.format(p['amount'])} via ${p['gatewayProvider'] ?? p['paymentMethod']}'),
                                subtitle: Text(p['createdAt'] != null ? _dateFormat.format(DateTime.parse(p['createdAt'])) : ''),
                              )),
                            ],

                            if (ord['trackingNumber'] != null && (ord['trackingNumber'] as String).isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.local_shipping, size: 18, color: Color(0xFF047857)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Carrier: ${ord['deliveryNotes'] != null && (ord['deliveryNotes'] as String).contains('Carrier: ') ? (ord['deliveryNotes'] as String).split('Carrier: ')[1].split('.')[0] : 'Partner'} • Docket: ${ord['trackingNumber']}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF065F46)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      '✓ Automated WhatsApp & SMS sent with tracking & GST invoice link',
                                      style: TextStyle(fontSize: 11, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF047857),
                                        side: const BorderSide(color: Color(0xFF059669)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.send, size: 15),
                                      label: const Text('Resend WhatsApp & SMS Alert', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      onPressed: () async {
                                        try {
                                          final api = ref.read(apiClientProvider);
                                          await api.dio.post('/orders/${ord['id']}/resend-dispatch-notification', data: {'channel': 'ALL'});
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('WhatsApp & SMS dispatch alerts successfully resent!'), backgroundColor: Color(0xFF047857)),
                                            );
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Download Official GST Tax Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              onPressed: () => _downloadOrderInvoicePdf(ord),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinanceRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _orders.where((ord) {
      final orderNo = (ord['orderNumber'] ?? '').toString().toLowerCase();
      final bName = (ord['buyer']?['businessName'] ?? ord['buyer']?['user']?['fullName'] ?? '').toString().toLowerCase();
      final sName = (ord['salesman']?['user']?['fullName'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();

      final matchesSearch = q.isEmpty || orderNo.contains(q) || bName.contains(q) || sName.contains(q);
      final matchesStatus = _selectedStatus == 'ALL' || ord['status'] == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Pipeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Dispatch Tracking & Payment Settlement', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchOrders,
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/orders'),
      body: Column(
        children: [
          // Search & Filter Box
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by order #, buyer, salesman...',
                    hintStyle: const TextStyle(fontSize: 13),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['ALL', 'PENDING', 'CONFIRMED', 'PROCESSING', 'SHIPPED', 'DELIVERED', 'CANCELLED'].map((st) {
                      final isSelected = _selectedStatus == st;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
                          label: Text(
                            st == 'ALL' ? 'All Orders' : st,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0284C7),
                          backgroundColor: const Color(0xFFF1F5F9),
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _selectedStatus = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchOrders,
                    child: filteredOrders.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey),
                                SizedBox(height: 12),
                                Text('No orders found matching criteria.', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredOrders.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                              final ord = filteredOrders[i];
                              return _buildOrderCard(ord);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> ord) {
    final orderNo = ord['orderNumber'] ?? 'ORD-####';
    final buyerName = ord['buyer']?['businessName'] ?? ord['buyer']?['user']?['fullName'] ?? 'Buyer';
    final buyerTier = ord['buyer']?['buyerType'] ?? 'CUSTOMER';
    final salesman = ord['salesman'];
    final salesmanName = salesman?['user']?['fullName'];

    final status = ord['status'] ?? 'PENDING';
    final pStatus = ord['paymentStatus'] ?? 'PENDING';
    final finalAmount = (ord['finalAmount'] ?? ord['finalTotal'] ?? 0).toDouble();
    final paidAmount = (ord['paidAmount'] ?? ord['amountPaid'] ?? 0).toDouble();
    final balanceDue = finalAmount - paidAmount;

    final dateStr = ord['createdAt'] != null
        ? _dateFormat.format(DateTime.parse(ord['createdAt']))
        : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orderNo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0284C7)),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: status == 'DELIVERED'
                                ? Colors.green.shade50
                                : status == 'CANCELLED'
                                    ? Colors.red.shade50
                                    : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: status == 'DELIVERED'
                                  ? Colors.green.shade200
                                  : status == 'CANCELLED'
                                      ? Colors.red.shade200
                                      : Colors.blue.shade200,
                            ),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: status == 'DELIVERED'
                                  ? Colors.green.shade800
                                  : status == 'CANCELLED'
                                      ? Colors.red.shade800
                                      : Colors.blue.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: pStatus == 'PAID'
                                ? Colors.teal.shade50
                                : pStatus == 'PARTIALLY_PAID'
                                    ? Colors.orange.shade50
                                    : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: pStatus == 'PAID' ? Colors.teal.shade200 : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            pStatus,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: pStatus == 'PAID' ? Colors.teal.shade800 : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$buyerName ($buyerTier)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    if (salesmanName != null)
                      Text('Staff: $salesmanName', style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
                  ],
                ),
              ],
            ),
          ),

          // Finance Band
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFF8FAFC),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Value', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      _currencyFormat.format(finalAmount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Profit: ₹${ord['profit'] ?? 0}',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paid', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      _currencyFormat.format(paidAmount),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Balance Due', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    Text(
                      _currencyFormat.format(balanceDue > 0 ? balanceDue : 0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: balanceDue > 0 ? const Color(0xFFE11D48) : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const Text('Details', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showOrderDetailSheet(ord),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, size: 20, color: Color(0xFF0284C7)),
                  tooltip: 'Download Invoice',
                  onPressed: () => _downloadOrderInvoicePdf(ord),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.local_shipping, size: 15, color: Color(0xFF0284C7)),
                    label: const Text('Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                    onPressed: () => _showUpdateStatusDialog(ord),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 15),
                    label: const Text('Collect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () => _showRecordPaymentDialog(ord),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
