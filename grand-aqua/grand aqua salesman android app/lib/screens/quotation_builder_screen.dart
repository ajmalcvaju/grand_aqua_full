import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/auth_provider.dart';

class QuotationBuilderScreen extends ConsumerStatefulWidget {
  const QuotationBuilderScreen({super.key});

  @override
  ConsumerState<QuotationBuilderScreen> createState() => _QuotationBuilderScreenState();
}

class _QuotationBuilderScreenState extends ConsumerState<QuotationBuilderScreen> {
  List<dynamic> _buyers = [];
  List<dynamic> _products = [];
  String? _selectedBuyerId;
  final List<Map<String, dynamic>> _items = [];

  final _discountCtrl = TextEditingController(text: '0');
  final _reasonCtrl = TextEditingController();
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

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

  Future<void> _loadData() async {
    try {
      final api = ref.read(apiClientProvider);
      final resBuyers = await api.dio.get('/buyers?limit=100');
      final resProds = await api.dio.get('/products?limit=100');

      final buyersData = resBuyers.data['data'] ?? resBuyers.data;
      final prodsData = resProds.data['data'] ?? resProds.data;

      setState(() {
        _buyers = buyersData['buyers'] ?? [];
        _products = prodsData['products'] ?? [];
        if (_buyers.isNotEmpty) _selectedBuyerId = _buyers.first['id'];
        if (_products.isNotEmpty && _items.isEmpty) {
          _items.add({'productId': _products.first['id'], 'quantity': 1});
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitQuotation() async {
    if (_selectedBuyerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a buyer.')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one product.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final api = ref.read(apiClientProvider);
      final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;

      final res = await api.dio.post('/quotations', data: {
        'buyerProfileId': _selectedBuyerId,
        'items': _items.map((i) => {
          'productId': i['productId'],
          'quantity': i['quantity'],
        }).toList(),
        'additionalDiscountRequested': discount,
        'discountReason': _reasonCtrl.text.trim(),
      });

      final quotation = res.data['data'] ?? res.data;
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Quotation Created!'),
            content: Text(
              'Quotation #${quotation['quotationNumber']} successfully generated.\nStatus: ${quotation['status']}',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pushReplacement('/quotations');
                },
                child: const Text('View Quotations'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotation Builder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Buyer Selection
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Select Buyer Shop',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488))),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBuyerId,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: _buyers.map<DropdownMenuItem<String>>((b) {
                              return DropdownMenuItem<String>(
                                value: b['id'],
                                child: Text(
                                  '${b['businessName'] ?? b['user']?['fullName']} (${b['buyerType']})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedBuyerId = val),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Line Items Section
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('2. Products & Line Items',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0D9488))),
                              TextButton.icon(
                                icon: const Icon(Icons.add, size: 16, color: Color(0xFF0D9488)),
                                label: const Text('Add Product', style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold, fontSize: 12)),
                                onPressed: () {
                                  if (_products.isNotEmpty) {
                                    setState(() {
                                      _items.add({'productId': _products.first['id'], 'quantity': 1});
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_items.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No products added. Click "+ Add Product" to quote items.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ),
                            ),

                          ..._items.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;

                            final prod = _products.firstWhere(
                              (p) => p['id'] == item['productId'],
                              orElse: () => null,
                            );

                            final mediaList = (prod?['media'] as List<dynamic>?) ?? [];
                            final imgObj = mediaList.firstWhere(
                              (m) => m['mediaType'] == 'IMAGE',
                              orElse: () => null,
                            );
                            String imgUrl = imgObj?['url'] ?? prod?['imageUrl'] ?? '';
                            if (imgUrl.startsWith('/uploads/')) {
                              final api = ref.read(apiClientProvider);
                              final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
                              imgUrl = '$base$imgUrl';
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Product Image Thumbnail Preview
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: Colors.grey.shade200),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                            )
                                          : _buildCameraPlaceholder(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Product Dropdown
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: item['productId'],
                                      isExpanded: true,
                                      underline: const SizedBox(),
                                      items: _products.map<DropdownMenuItem<String>>((p) {
                                        return DropdownMenuItem<String>(
                                          value: p['id'],
                                          child: Text(
                                            '${p['name']} (${p['sku']})',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => item['productId'] = val);
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Quantity Controls
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                                        onPressed: item['quantity'] > 1
                                            ? () => setState(() => item['quantity']--)
                                            : null,
                                      ),
                                      Text(
                                        '${item['quantity']}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, size: 20),
                                        onPressed: () => setState(() => item['quantity']++),
                                      ),
                                    ],
                                  ),

                                  // Delete item
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      setState(() => _items.removeAt(idx));
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Concession Request
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.amber.shade200),
                    ),
                    color: Colors.amber.shade50.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.discount_outlined, color: Colors.amber, size: 18),
                              SizedBox(width: 6),
                              Text('3. Commercial Concession Request',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFB45309))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _discountCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Additional Concession Amount',
                              prefixText: '₹ ',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonCtrl,
                            decoration: InputDecoration(
                              labelText: 'Justification for Super Admin',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitQuotation,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Generate & Submit Quotation',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
