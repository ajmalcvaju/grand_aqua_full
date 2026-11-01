import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  List<dynamic> _quotations = [];
  List<dynamic> _buyers = [];
  List<dynamic> _salesmen = [];
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
    _fetchDropdownData();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final api = ref.read(apiClientProvider);
      final buyersRes = await api.dio.get('/buyers?limit=100');
      final bData = buyersRes.data['data'] ?? buyersRes.data;

      final salesmenRes = await api.dio.get('/salesmen');
      final sData = salesmenRes.data['data'] ?? salesmenRes.data;

      final productsRes = await api.dio.get('/products?limit=100');
      final pData = productsRes.data['data'] ?? productsRes.data;

      if (mounted) {
        setState(() {
          _buyers = (bData is Map && bData['buyers'] != null)
              ? bData['buyers']
              : (bData is List ? bData : []);
          _salesmen = (sData is List) ? sData : (sData['salesmen'] ?? []);
          _products = (pData is Map && pData['products'] != null)
              ? pData['products']
              : (pData is List ? pData : []);
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchQuotations() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      String url = '/quotations?limit=50';
      if (_selectedStatus != 'ALL') {
        url += '&status=$_selectedStatus';
      }
      final res = await api.dio.get(url);
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _quotations = data['quotations'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 1-Click Set Status to ACCEPTED
  Future<void> _setStatusAccepted(String quotationId) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/quotations/$quotationId/status', data: {
        'status': 'ACCEPTED',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quotation status changed to ACCEPTED!')),
        );
        _fetchQuotations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e')),
        );
      }
    }
  }

  // Convert Quotation into Confirmed Order
  Future<void> _convertToOrder(String quotationId) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post('/quotations/$quotationId/convert-to-order', data: {});
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully converted to Order: ${data['orderNumber'] ?? ''}!')),
        );
        _fetchQuotations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert: $e')),
        );
      }
    }
  }

  // Delete Quotation
  Future<void> _deleteQuotation(String id, String number) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Quotation?'),
        content: Text('Are you sure you want to delete quotation "$number"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final api = ref.read(apiClientProvider);
        await api.dio.delete('/quotations/$id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Quotation deleted successfully!')),
          );
          _fetchQuotations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting quotation: $e')),
          );
        }
      }
    }
  }

  // Helper: Price determination based on buyer category
  double _getPriceForBuyer(Map<String, dynamic>? product, String buyerType) {
    if (product == null || product['pricing'] == null) return 0.0;
    final pr = product['pricing'];
    if (buyerType == 'DISTRIBUTOR') return (pr['distributorPrice'] ?? 0.0).toDouble();
    if (buyerType == 'WHOLESALER') return (pr['wholesalerPrice'] ?? 0.0).toDouble();
    if (buyerType == 'DEALER') return (pr['dealerPrice'] ?? 0.0).toDouble();
    return (pr['customerPrice'] ?? 0.0).toDouble();
  }

  // Show Create / Edit Dialog
  void _showQuotationFormDialog({Map<String, dynamic>? quotation}) {
    final isEditing = quotation != null;

    String selectedBuyerId = quotation?['buyerProfileId'] ??
        (_buyers.isNotEmpty ? _buyers.first['id'] : '');

    // Sales staff: 'NONE' for direct company, or salesmanProfileId
    String selectedSalesmanId = quotation?['salesmanProfileId'] ?? 'NONE';

    String selectedStatus = quotation?['status'] ?? 'ISSUED';
    final shippingChargesCtrl = TextEditingController(
      text: (quotation?['shippingCharges'] ?? 0).toString(),
    );
    final discountCtrl = TextEditingController(
      text: (quotation?['additionalDiscountRequested'] ?? 0).toString(),
    );
    final discountReasonCtrl = TextEditingController(
      text: quotation?['discountReason'] ?? '',
    );
    final paymentTermsCtrl = TextEditingController(
      text: quotation?['paymentTerms'] ?? 'Payment on Delivery / Approved Credit',
    );
    final validityDaysCtrl = TextEditingController(text: '15');
    final buyerNotesCtrl = TextEditingController(text: quotation?['buyerNotes'] ?? '');

    // Line items list
    List<Map<String, dynamic>> items = [];
    if (isEditing && quotation['items'] != null) {
      for (var it in (quotation['items'] as List)) {
        items.add({
          'productId': it['productId'],
          'productName': it['productName'] ?? it['product']?['name'] ?? 'Product',
          'quantity': it['quantity'] ?? 1,
          'unitPrice': (it['unitPrice'] ?? 0.0).toDouble(),
        });
      }
    }

    if (items.isEmpty && _products.isNotEmpty && _buyers.isNotEmpty) {
      final b = _buyers.firstWhere((x) => x['id'] == selectedBuyerId, orElse: () => _buyers.first);
      final p = _products.first;
      final price = _getPriceForBuyer(p, b['buyerType'] ?? 'CUSTOMER');
      items.add({
        'productId': p['id'],
        'productName': p['name'],
        'quantity': 1,
        'unitPrice': price,
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Calculate live totals
          double subtotal = 0;
          for (var it in items) {
            subtotal += (it['unitPrice'] as double) * (it['quantity'] as int);
          }
          final taxAmount = (subtotal * 18) / 100;
          final disc = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
          final shipping = double.tryParse(shippingChargesCtrl.text.trim()) ?? 0.0;
          final grandTotal = (subtotal + taxAmount + shipping - disc).clamp(0.0, double.infinity);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note : Icons.post_add,
                  color: const Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Edit Quotation' : 'Create Quotation',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Buyer Selector
                    const Text(
                      '1. BUYER PROFILE *',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBuyerId.isNotEmpty ? selectedBuyerId : null,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: _buyers.map<DropdownMenuItem<String>>((b) {
                        return DropdownMenuItem<String>(
                          value: b['id'],
                          child: Text(
                            '${b['businessName'] ?? b['user']?['fullName']} (${b['buyerType']})',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedBuyerId = val;
                            // Recalculate default prices for selected buyer
                            final b = _buyers.firstWhere((x) => x['id'] == val, orElse: () => null);
                            if (b != null) {
                              for (var it in items) {
                                final prod = _products.firstWhere(
                                  (p) => p['id'] == it['productId'],
                                  orElse: () => null,
                                );
                                if (prod != null) {
                                  it['unitPrice'] = _getPriceForBuyer(prod, b['buyerType'] ?? 'CUSTOMER');
                                }
                              }
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 12),
                    // Sales Staff Selector with explicit NONE option
                    const Text(
                      '2. SALES STAFF ASSIGNMENT',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSalesmanId,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'NONE',
                          child: Text('None (Direct Company - No Staff)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        ..._salesmen.map<DropdownMenuItem<String>>((s) {
                          return DropdownMenuItem<String>(
                            value: s['id'],
                            child: Text(
                              '${s['user']?['fullName']} (${s['employeeCode'] ?? 'Staff'})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedSalesmanId = val);
                      },
                    ),

                    const SizedBox(height: 12),
                    // Status Option (Super Admin can directly set status to ACCEPTED!)
                    const Text(
                      '3. QUOTATION STATUS',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: const [
                        DropdownMenuItem(value: 'ISSUED', child: Text('ISSUED (Sent to Buyer)', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'PENDING_DISCOUNT_APPROVAL', child: Text('Pending Approval', style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 'ACCEPTED', child: Text('ACCEPTED (Pre-approved for Order)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal))),
                        DropdownMenuItem(value: 'DRAFT', child: Text('DRAFT (Internal Preparation)', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedStatus = val);
                      },
                    ),

                    const SizedBox(height: 16),
                    // Line Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'LINE ITEMS & PRICING',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            if (_products.isNotEmpty) {
                              final b = _buyers.firstWhere((x) => x['id'] == selectedBuyerId, orElse: () => null);
                              final p = _products.first;
                              final price = _getPriceForBuyer(p, b?['buyerType'] ?? 'CUSTOMER');
                              setDialogState(() {
                                items.add({
                                  'productId': p['id'],
                                  'productName': p['name'],
                                  'quantity': 1,
                                  'unitPrice': price,
                                });
                              });
                            }
                          },
                          icon: const Icon(Icons.add_circle, size: 16),
                          label: const Text('Add Item', style: TextStyle(fontSize: 11)),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),

                    ...items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Builder(
                                  builder: (context) {
                                    final prod = _products.firstWhere((p) => p['id'] == item['productId'], orElse: () => null);
                                    final mediaList = (prod?['media'] as List<dynamic>?) ?? [];
                                    final imgObj = mediaList.firstWhere((m) => m['mediaType'] == 'IMAGE', orElse: () => null);
                                    String thumbUrl = imgObj?['url'] ?? prod?['imageUrl'] ?? '';
                                    if (thumbUrl.startsWith('/uploads/')) {
                                      final api = ref.read(apiClientProvider);
                                      thumbUrl = '${api.dio.options.baseUrl.replaceAll('/api/v1', '')}$thumbUrl';
                                    }
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: thumbUrl.isNotEmpty
                                          ? Image.network(
                                              thumbUrl,
                                              width: 32,
                                              height: 32,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                            )
                                          : _buildCameraPlaceholder(),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: item['productId'],
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    items: _products.map<DropdownMenuItem<String>>((p) {
                                      return DropdownMenuItem<String>(
                                        value: p['id'],
                                        child: Text(
                                          '${p['sku']} • ${p['name']}',
                                          style: const TextStyle(fontSize: 11),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final prod = _products.firstWhere((p) => p['id'] == val, orElse: () => null);
                                        final b = _buyers.firstWhere((x) => x['id'] == selectedBuyerId, orElse: () => null);
                                        setDialogState(() {
                                          item['productId'] = val;
                                          item['productName'] = prod?['name'];
                                          if (prod != null) {
                                            item['unitPrice'] = _getPriceForBuyer(prod, b?['buyerType'] ?? 'CUSTOMER');
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                if (items.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() => items.removeAt(idx));
                                    },
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['quantity'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Qty', isDense: true),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        item['quantity'] = int.tryParse(val.trim()) ?? 1;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    initialValue: item['unitPrice'].toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Unit Price (₹)', isDense: true),
                                    onChanged: (val) {
                                      setDialogState(() {
                                        item['unitPrice'] = double.tryParse(val.trim()) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),
                    // Shipping Charges
                    TextField(
                      controller: shippingChargesCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Shipping Charges (₹)',
                        hintText: 'Enter shipping fee',
                        prefixText: '₹ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    // Commercial Terms
                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Special Commercial Discount (₹)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: discountReasonCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Discount Reason / Remarks',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: paymentTermsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),

                    const SizedBox(height: 14),
                    // Summary Strip
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('₹${subtotal.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GST (18%):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                              Text('₹${taxAmount.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shipping Charges:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                              Text('+₹${shipping.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          if (disc > 0)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Discount:', style: TextStyle(color: Colors.amber, fontSize: 11)),
                                Text('-₹${disc.toStringAsFixed(1)}', style: const TextStyle(color: Colors.amber, fontSize: 11)),
                              ],
                            ),
                          const Divider(color: Colors.white24, height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Payable Total:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(
                                '₹${grandTotal.toStringAsFixed(1)}',
                                style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.w900, fontSize: 15),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                onPressed: () async {
                  if (items.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please add at least 1 line item!')),
                    );
                    return;
                  }

                  final payload = {
                    'buyerProfileId': selectedBuyerId,
                    'salesmanProfileId': selectedSalesmanId == 'NONE' ? null : selectedSalesmanId,
                    'status': selectedStatus,
                    'validityDays': int.tryParse(validityDaysCtrl.text.trim()) ?? 15,
                    'paymentTerms': paymentTermsCtrl.text.trim(),
                    'shippingCharges': double.tryParse(shippingChargesCtrl.text.trim()) ?? 0.0,
                    'additionalDiscountRequested': double.tryParse(discountCtrl.text.trim()) ?? 0.0,
                    'discountReason': discountReasonCtrl.text.trim(),
                    'buyerNotes': buyerNotesCtrl.text.trim(),
                    'items': items.map((i) => {
                      'productId': i['productId'],
                      'quantity': i['quantity'],
                      'unitPrice': i['unitPrice'],
                    }).toList(),
                  };

                  try {
                    final api = ref.read(apiClientProvider);
                    if (isEditing) {
                      await api.dio.put('/quotations/${quotation['id']}', data: payload);
                    } else {
                      await api.dio.post('/quotations', data: payload);
                    }

                    if (mounted && ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEditing ? 'Quotation updated successfully!' : 'Quotation created successfully!',
                          ),
                        ),
                      );
                      _fetchQuotations();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error saving quotation: $e')),
                      );
                    }
                  }
                },
                child: Text(isEditing ? 'Update' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Camera Circle Placeholder Icon (matches quotation screenshot)
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

  // Open / Download Quotation PDF
  Future<void> _downloadQuotationPdf(Map<String, dynamic> q) async {
    final qId = q['id'];
    if (qId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final pdfUrl = '${api.dio.options.baseUrl}/quotations/$qId/pdf';
      final uri = Uri.parse(pdfUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading PDF from $pdfUrl...')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening PDF: $e')),
        );
      }
    }
  }

  // Quick Dialog to set shipping charges and approve quotation
  Future<void> _approveWithShippingDialog(Map<String, dynamic> q) async {
    final shippingCtrl = TextEditingController(
      text: _toNumber(q['shippingCharges']) > 0 ? q['shippingCharges'].toString() : '',
    );
    double selectedGstRate = _toNumber(q['taxRate']) > 0 ? _toNumber(q['taxRate']) : 18.0;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Approve Quotation & Finalize Taxes',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quotation #${q['quotationNumber'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                ),
                const SizedBox(height: 10),

                // GST Slab Selector
                const Text(
                  'SELECT APPLICABLE GST SLAB:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<double>(
                  value: selectedGstRate,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 18.0, child: Text('18% GST (Standard Rate)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 12.0, child: Text('12% GST (Water Purifiers)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 5.0, child: Text('5% GST (Concessional / Spares)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 0.0, child: Text('0% GST (Exempted / Nil)', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedGstRate = val);
                  },
                ),
                const SizedBox(height: 12),

                // Shipping Fee
                const Text(
                  'SHIPPING CHARGES (₹):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: shippingCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Shipping Fee (₹)',
                    hintText: 'e.g. 500',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Profit Display
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Estimated Net Profit:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      Text('₹${q['profit'] ?? 0} (${q['profitMargin'] ?? 0}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                    ],
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
            FilledButton.icon(
              onPressed: () async {
                final shipping = double.tryParse(shippingCtrl.text.trim()) ?? 0.0;
                Navigator.pop(ctx);
                try {
                  final api = ref.read(apiClientProvider);
                  await api.dio.put('/quotations/${q['id']}', data: {
                    'shippingCharges': shipping,
                    'taxRate': selectedGstRate,
                    'status': 'ISSUED',
                  });
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Quotation approved with ${selectedGstRate.toInt()}% GST & shipping ₹$shipping!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _fetchQuotations();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error approving quotation: $e')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 16),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              label: const Text('Approve & Send to Buyer'),
            ),
          ],
        ),
      ),
    );
  }

  // Show Details & PDF Preview Dialog
  void _showDetailsDialog(Map<String, dynamic> q) {
    final items = (q['items'] as List<dynamic>?) ?? [];
    final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            q['quotationNumber'] ?? 'Quotation Details',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Status: ${q['status'] == 'PENDING_DISCOUNT_APPROVAL' ? 'Pending Approval' : (q['status'] ?? '').toString().replaceAll('_', ' ')}',
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Buyer & Salesman Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business_outlined, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                q['buyer']?['businessName'] ?? q['buyer']?['user']?['fullName'] ?? 'Buyer',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Staff: ${q['salesman']?['user']?['fullName'] ?? 'Direct Company Account'}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ITEMIZED BREAKDOWN',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B), letterSpacing: 0.5),
                      ),
                      Text(
                        '${items.length} Products Quoted',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Items Table Matching User Layout
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 36,
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 58,
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        border: TableBorder(
                          horizontalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                          verticalInside: BorderSide(color: Colors.grey.shade200, width: 1),
                        ),
                        columns: const [
                          DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                        ],
                        rows: [
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final it = entry.value;

                            final mediaList = (it['product']?['media'] as List<dynamic>?) ?? [];
                            final imgObj = mediaList.firstWhere(
                              (m) => m['mediaType'] == 'IMAGE',
                              orElse: () => null,
                            );
                            String imgUrl = imgObj?['url'] ?? it['product']?['imageUrl'] ?? it['imageUrl'] ?? '';
                            if (imgUrl.startsWith('/uploads/')) {
                              final api = ref.read(apiClientProvider);
                              final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
                              imgUrl = '$base$imgUrl';
                            }

                            final prodName = it['productName'] ?? it['product']?['name'] ?? 'Water Purifier';
                            final sku = it['sku'] ?? it['product']?['sku'] ?? '';
                            final subNote = it['product']?['category']?['name'] ?? it['product']?['shortDescription'] ?? 'Genuine RO Unit';
                            final qty = _toNumber(it['quantity']);
                            final uom = it['product']?['unitOfMeasurement'] ?? 'PCS';
                            final unitPrice = _toNumber(it['unitPrice']);
                            final totalPrice = _toNumber(it['totalPrice']);

                            return DataRow(
                              cells: [
                                // 1. #
                                DataCell(
                                  Center(
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)),
                                    ),
                                  ),
                                ),
                                // 2. Image
                                DataCell(
                                  Center(
                                    child: imgUrl.isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: Image.network(
                                              imgUrl,
                                              width: 38,
                                              height: 38,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                            ),
                                          )
                                        : _buildCameraPlaceholder(),
                                  ),
                                ),
                                // 3. Product
                                DataCell(
                                  SizedBox(
                                    width: 170,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          sku.isNotEmpty ? '$prodName ($sku)' : prodName,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subNote.toUpperCase(),
                                          style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 4. Qty
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(qty.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                      Text(uom, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                // 5. Price
                                DataCell(
                                  Text(
                                    currency.format(unitPrice),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                // 6. Total
                                DataCell(
                                  Text(
                                    currency.format(totalPrice),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ],
                            );
                          }),
                          // Table Footer Row Total
                          DataRow(
                            color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            cells: [
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(Text('')),
                              const DataCell(
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              DataCell(
                                Text(
                                  currency.format(_toNumber(q['subtotal'])),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF0F172A)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Financials Breakdown Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Subtotal:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            Text(currency.format(_toNumber(q['subtotal'])), style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('GST (18%):', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            Text(currency.format(_toNumber(q['taxAmount'])), style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace')),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Shipping Charges:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                            Text(
                              _toNumber(q['shippingCharges']) > 0
                                  ? currency.format(_toNumber(q['shippingCharges']))
                                  : (q['status'] == 'PENDING_DISCOUNT_APPROVAL' || q['status'] == 'DRAFT'
                                      ? 'To be calculated'
                                      : '₹0 (Free / Included)'),
                              style: TextStyle(
                                fontSize: 11,
                                color: _toNumber(q['shippingCharges']) > 0 ? const Color(0xFF38BDF8) : const Color(0xFFFDE68A),
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_toNumber(q['additionalDiscountRequested']) > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Special Discount:', style: TextStyle(fontSize: 11, color: Color(0xFFFDE68A))),
                              Text(
                                '-${currency.format(_toNumber(q['additionalDiscountApproved'] ?? q['additionalDiscountRequested']))}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFFFDE68A), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ],
                        const Divider(color: Colors.white24, height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('FINAL TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
                            Text(
                              currency.format(_toNumber(q['finalTotal'])),
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF38BDF8), fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Actions Toolbar
                  Row(
                    children: [
                      // Download PDF Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF0284C7)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF0284C7)),
                          label: const Text('PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                          onPressed: () => _downloadQuotationPdf(q),
                        ),
                      ),
                      const SizedBox(width: 8),

                      if (q['status'] != 'ACCEPTED' && q['status'] != 'CONVERTED_TO_ORDER')
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.edit_note_rounded, size: 18),
                            label: const Text('Set Shipping & Approve', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _approveWithShippingDialog(q);
                            },
                          ),
                        ),

                      if (q['status'] == 'ACCEPTED')
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                            label: const Text('To Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _convertToOrder(q['id']);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _toNumber(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
  }

  void _reviewDiscount(String id, String action) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/quotations/$id/review-discount', data: {
        'action': action,
        'notes': 'Reviewed from Super Admin Android App',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Discount request $action!')),
        );
        _fetchQuotations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _quotations.filterBySearch(_searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quotation Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            Text('Commercial Workflow, Sales Staff & Orders', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchQuotations();
              _fetchDropdownData();
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/quotations'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuotationFormDialog(),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Quotation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Filter Chips and Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() => _searchQuery = val.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search quotation #, buyer, staff...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All'),
                      _buildFilterChip('PENDING_DISCOUNT_APPROVAL', 'Pending Approval'),
                      _buildFilterChip('ISSUED', 'Issued'),
                      _buildFilterChip('ACCEPTED', 'Accepted'),
                      _buildFilterChip('CONVERTED_TO_ORDER', 'Converted'),
                      _buildFilterChip('REJECTED', 'Rejected'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Quotations List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'No quotations found',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "+ New Quotation" to create one.',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchQuotations,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (ctx, i) {
                            final q = filtered[i];
                            final status = q['status'] ?? '';
                            final isPending = status == 'PENDING_DISCOUNT_APPROVAL';
                            final isAccepted = status == 'ACCEPTED';
                            final isConverted = status == 'CONVERTED_TO_ORDER';

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
                                    // Header: Number and Status
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          q['quotationNumber'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isAccepted
                                                ? Colors.teal.shade50
                                                : isConverted
                                                    ? Colors.green.shade50
                                                    : isPending
                                                        ? Colors.amber.shade100
                                                        : Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isAccepted
                                                  ? Colors.teal.shade200
                                                  : isConverted
                                                      ? Colors.green.shade200
                                                      : Colors.transparent,
                                            ),
                                          ),
                                          child: Text(
                                            isPending ? 'Pending Approval' : status.replaceAll('_', ' '),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: isAccepted
                                                  ? Colors.teal.shade900
                                                  : isConverted
                                                      ? Colors.green.shade900
                                                      : isPending
                                                          ? Colors.amber.shade900
                                                          : Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Buyer & Staff Row
                                    Text(
                                      q['buyer']?['businessName'] ?? q['buyer']?['user']?['fullName'] ?? 'Trade Buyer',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            q['buyer']?['buyerType'] ?? 'CUSTOMER',
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.person_pin, size: 14, color: Colors.grey.shade500),
                                        const SizedBox(width: 3),
                                        Text(
                                          q['salesman']?['user']?['fullName'] ?? 'None (Direct Company)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: q['salesman'] == null ? Colors.teal.shade800 : Colors.grey.shade700,
                                            fontWeight: q['salesman'] == null ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 8),
                                    // Totals
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Final Total: ₹${q['finalTotal']}',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Text(
                                            'Profit: ₹${q['profit'] ?? 0} (${q['profitMargin'] ?? 0}%)',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 10),
                                    // Action Toolbar
                                    Row(
                                      children: [
                                        // 1-Click Accept Button!
                                        if (!isAccepted && !isConverted)
                                          FilledButton.tonal(
                                            onPressed: () => _setStatusAccepted(q['id']),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: Colors.teal.shade50,
                                              foregroundColor: Colors.teal.shade800,
                                            ),
                                            child: const Text('Accept', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),

                                        // Convert to Order Button!
                                        if (isAccepted)
                                          FilledButton.icon(
                                            onPressed: () => _convertToOrder(q['id']),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: Colors.green,
                                            ),
                                            icon: const Icon(Icons.shopping_cart, size: 12),
                                            label: const Text('To Order', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),

                                        if (isPending) ...[
                                          const SizedBox(width: 4),
                                          OutlinedButton(
                                            onPressed: () => _reviewDiscount(q['id'], 'REJECT'),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              visualDensity: VisualDensity.compact,
                                              foregroundColor: Colors.red,
                                            ),
                                            child: const Text('Reject', style: TextStyle(fontSize: 11)),
                                          ),
                                          const SizedBox(width: 4),
                                          FilledButton(
                                            onPressed: () => _reviewDiscount(q['id'], 'APPROVE'),
                                            style: FilledButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                              visualDensity: VisualDensity.compact,
                                              backgroundColor: Colors.green,
                                            ),
                                            child: const Text('Approve', style: TextStyle(fontSize: 11)),
                                          ),
                                        ],

                                        const Spacer(),
                                        // View Details
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18),
                                          onPressed: () => _showDetailsDialog(q),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'View Details',
                                        ),
                                        // Download PDF
                                        IconButton(
                                          icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF0284C7)),
                                          onPressed: () => _downloadQuotationPdf(q),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Download PDF',
                                        ),
                                        // Edit
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0284C7)),
                                          onPressed: () => _showQuotationFormDialog(quotation: q),
                                          visualDensity: VisualDensity.compact,
                                          tooltip: 'Edit Quotation',
                                        ),
                                        // Delete
                                        if (!isConverted)
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                            onPressed: () => _deleteQuotation(q['id'], q['quotationNumber'] ?? ''),
                                            visualDensity: VisualDensity.compact,
                                            tooltip: 'Delete Quotation',
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _selectedStatus = value);
          _fetchQuotations();
        },
      ),
    );
  }
}

extension QuotationSearch on List<dynamic> {
  List<dynamic> filterBySearch(String query) {
    if (query.isEmpty) return this;
    final term = query.toLowerCase();
    return where((q) {
      final qNum = (q['quotationNumber'] ?? '').toString().toLowerCase();
      final bName = (q['buyer']?['businessName'] ?? q['buyer']?['user']?['fullName'] ?? '').toString().toLowerCase();
      final sName = (q['salesman']?['user']?['fullName'] ?? '').toString().toLowerCase();
      return qNum.contains(term) || bName.contains(term) || sName.contains(term);
    }).toList();
  }
}


