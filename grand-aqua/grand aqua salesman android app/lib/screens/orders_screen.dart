import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_provider.dart';

class SalesmanOrdersScreen extends ConsumerStatefulWidget {
  const SalesmanOrdersScreen({super.key});

  @override
  ConsumerState<SalesmanOrdersScreen> createState() => _SalesmanOrdersScreenState();
}

class _SalesmanOrdersScreenState extends ConsumerState<SalesmanOrdersScreen> {
  bool _isLoading = true;
  List<dynamic> _orders = [];
  String? _error;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final response = await api.dio.get('/orders');
      if (mounted) {
        setState(() {
          final resData = response.data;
          if (resData is List) {
            _orders = resData;
          } else if (resData is Map && resData['data'] is List) {
            _orders = resData['data'];
          } else if (resData is Map && resData['orders'] is List) {
            _orders = resData['orders'];
          } else {
            _orders = [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load dealer orders: $e';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'SHIPPED':
        return Colors.blue;
      case 'PROCESSING':
      case 'CONFIRMED':
      case 'ACCEPTED':
        return Colors.indigo;
      case 'PENDING':
        return Colors.amber.shade800;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      width: 40,
      height: 40,
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

  Widget _buildTemplateOptionTile({
    required BuildContext ctx,
    required String templateId,
    required String title,
    required String subtitle,
    required Color color,
    required String tag,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(ctx, templateId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'T$templateId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadInvoicePdf(Map<String, dynamic> order) async {
    final id = order['id'];
    if (id == null) return;

    final selectedTemplate = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Color(0xFF0284C7)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose GST Invoice Template',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Select your preferred bill layout format',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '1',
                title: 'Template 1: Modern Corporate',
                subtitle: 'Navy banner, itemized images & dispatch badge',
                color: const Color(0xFF0369A1),
                tag: 'Modern',
              ),
              const SizedBox(height: 8),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '2',
                title: 'Template 2: Executive Clean Minimal',
                subtitle: 'Minimal emerald styling & NEFT remittance card',
                color: const Color(0xFF059669),
                tag: 'Clean Minimal',
              ),
              const SizedBox(height: 8),
              _buildTemplateOptionTile(
                ctx: ctx,
                templateId: '3',
                title: 'Template 3: GST Formal Wholesale',
                subtitle: 'Statutory double-border, HSN 84212190 & split tax',
                color: const Color(0xFF4338CA),
                tag: 'Statutory GST',
              ),
            ],
          ),
        ),
      ),
    );

    if (selectedTemplate == null) return;

    try {
      final api = ref.read(apiClientProvider);
      final baseUrl = api.dio.options.baseUrl.replaceAll('/api/v1', '');
      final invoiceUrl = '$baseUrl/api/v1/orders/$id/invoice-pdf?template=$selectedTemplate';
      final uri = Uri.parse(invoiceUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open invoice link: $invoiceUrl')),
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

  List<dynamic> get _filteredOrders {
    return _orders.where((order) {
      final status = (order['status'] ?? '').toString().toUpperCase();
      if (_selectedStatus != 'ALL' && status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final orderNum = (order['orderNumber'] ?? order['id'] ?? '').toString().toLowerCase();
        final buyerName = (order['buyer']?['businessName'] ?? order['buyer']?['user']?['name'] ?? '').toString().toLowerCase();
        return orderNum.contains(q) || buyerName.contains(q);
      }
      return true;
    }).toList();
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    final items = (order['items'] as List?) ?? [];
    final buyer = order['buyer'] ?? {};
    final buyerUser = buyer['user'] ?? {};
    final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
    final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final subtotal = (order['subtotal'] as num?)?.toDouble() ?? (totalAmount / 1.18);
    final taxAmount = (order['taxAmount'] as num?)?.toDouble() ?? (totalAmount - subtotal);
    final trackingNumber = order['trackingNumber']?.toString();
    final carrierName = order['carrierName']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order['orderNumber'] ?? 'Order #${order['id']?.toString().substring(0, 8)}',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                order['createdAt'] != null
                                    ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(order['createdAt']))
                                    : 'Date unavailable',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(status)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Buyer info box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront, size: 16, color: Color(0xFF0D9488)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  buyer['businessName'] ?? buyerUser['name'] ?? 'Assigned Dealer',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (buyerUser['phone'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Phone: ${buyerUser['phone']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                          if (buyer['gstin'] != null) ...[
                            const SizedBox(height: 2),
                            Text('GSTIN: ${buyer['gstin']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                          ],
                          if (order['deliveryAddress'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Delivery: ${order['deliveryAddress']}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ],
                      ),
                    ),

                    if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_shipping_outlined, color: Colors.blue, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dispatched via ${carrierName ?? "Logistics Partner"}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                                  ),
                                  Text(
                                    'Docket / Tracking No: $trackingNumber',
                                    style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    const Text(
                      'Order Items',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            ),
                            child: const Row(
                              children: [
                                SizedBox(width: 24, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                SizedBox(width: 44, child: Text('Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                Expanded(child: Text('Product Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                SizedBox(width: 40, child: Text('Qty', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                SizedBox(width: 60, child: Text('Rate', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                                SizedBox(width: 70, child: Text('Total', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                              ],
                            ),
                          ),
                          ...items.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final item = entry.value;
                            final product = item['product'] ?? {};
                            final imageUrl = product['imageUrl'] ?? product['image'] ?? item['imageUrl'];
                            final unitPrice = (item['unitPrice'] as num?)?.toDouble() ?? 0.0;
                            final itemTotal = (item['totalPrice'] as num?)?.toDouble() ?? (unitPrice * (item['quantity'] ?? 1));

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text('$idx', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                  SizedBox(
                                    width: 44,
                                    child: imageUrl != null && imageUrl.toString().isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(4),
                                            child: Image.network(
                                              imageUrl,
                                              width: 36,
                                              height: 36,
                                              fit: BoxFit.cover,
                                              errorBuilder: (ctx, err, st) => _buildCameraPlaceholder(),
                                            ),
                                          )
                                        : _buildCameraPlaceholder(),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['name'] ?? item['productName'] ?? 'Product Item',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (product['sku'] != null)
                                          Text('SKU: ${product['sku']}', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: Text('${item['quantity'] ?? 1}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Text('₹${unitPrice.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
                                  ),
                                  SizedBox(
                                    width: 70,
                                    child: Text('₹${itemTotal.toStringAsFixed(0)}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                              Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GST (18%)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                              Text('₹${taxAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          const Divider(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text('₹${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D9488))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Action button: Download GST Tax Invoice
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 20),
                      label: const Text('Download Official GST Tax Invoice (PDF)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _downloadInvoicePdf(order),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dealer Orders', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by Order # or Dealer name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'ALL',
                      'PENDING',
                      'CONFIRMED',
                      'SHIPPED',
                      'DELIVERED',
                      'CANCELLED',
                    ].map((status) {
                      final isSelected = _selectedStatus == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D9488),
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                          onSelected: (_) => setState(() => _selectedStatus = status),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadOrders, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No orders found matching "$_selectedStatus"',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadOrders,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (context, index) {
                                final order = _filteredOrders[index];
                                final buyer = order['buyer'] ?? {};
                                final buyerUser = buyer['user'] ?? {};
                                final items = (order['items'] as List?) ?? [];
                                final status = (order['status'] ?? 'PENDING').toString().toUpperCase();
                                final totalAmount = (order['totalAmount'] as num?)?.toDouble() ?? 0.0;
                                final trackingNumber = order['trackingNumber']?.toString();

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => _showOrderDetailSheet(order),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                order['orderNumber'] ?? 'Order #${order['id']?.toString().substring(0, 8)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: _getStatusColor(status),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  buyer['businessName'] ?? buyerUser['name'] ?? 'Assigned Shop',
                                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                order['createdAt'] != null
                                                    ? DateFormat('dd MMM yyyy').format(DateTime.parse(order['createdAt']))
                                                    : '',
                                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                              ),
                                            ],
                                          ),
                                          if (trackingNumber != null && trackingNumber.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.local_shipping, size: 14, color: Colors.blue),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Docket: $trackingNumber (${order['carrierName'] ?? "Logistics"})',
                                                  style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500),
                                                ),
                                              ],
                                            ),
                                          ],
                                          const Divider(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '${items.length} ${items.length == 1 ? "item" : "items"} • ₹${totalAmount.toStringAsFixed(0)}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: const Color(0xFF0D9488),
                                                  side: const BorderSide(color: Color(0xFF0D9488)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                ),
                                                icon: const Icon(Icons.picture_as_pdf, size: 14),
                                                label: const Text('GST Invoice', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                                onPressed: () => _downloadInvoicePdf(order),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
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
}
