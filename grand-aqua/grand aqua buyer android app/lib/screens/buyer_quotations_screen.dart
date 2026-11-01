import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_provider.dart';

class BuyerQuotationsScreen extends ConsumerStatefulWidget {
  const BuyerQuotationsScreen({super.key});

  @override
  ConsumerState<BuyerQuotationsScreen> createState() => _BuyerQuotationsScreenState();
}

class _BuyerQuotationsScreenState extends ConsumerState<BuyerQuotationsScreen> {
  List<dynamic> _quotations = [];
  List<dynamic> _products = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/products?limit=100');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _products = (data is Map && data['products'] != null)
              ? data['products']
              : (data is List ? data : []);
        });
      }
    } catch (_) {}
  }

  double _getPriceForProduct(Map<String, dynamic> prod) {
    final authState = ref.read(authProvider);
    final buyer = authState.user?['buyerProfile'] ?? {};
    final buyerType = buyer['buyerType'] ?? 'CUSTOMER';
    final pr = prod['pricing'];
    if (pr == null) return (prod['price'] ?? 0.0).toDouble();
    if (buyerType == 'DISTRIBUTOR') return (pr['distributorPrice'] ?? 0.0).toDouble();
    if (buyerType == 'WHOLESALER') return (pr['wholesalerPrice'] ?? 0.0).toDouble();
    if (buyerType == 'DEALER') return (pr['dealerPrice'] ?? 0.0).toDouble();
    return (pr['customerPrice'] ?? 0.0).toDouble();
  }

  Future<void> _fetchQuotations() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/quotations');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _quotations = data['quotations'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load quotations: $e')),
        );
      }
    }
  }

  double _toNumber(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString()) ?? 0.0;
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

  Future<void> _downloadQuotationPdf(Map<String, dynamic> q) async {
    final id = q['id'];
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
                          'Choose Quotation Template',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Select your preferred layout format',
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
      final pdfUrl = '$baseUrl/api/v1/quotations/$id/pdf?template=$selectedTemplate';
      final uri = Uri.parse(pdfUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open PDF: $pdfUrl')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: $e')),
        );
      }
    }
  }

  Future<void> _respondToQuotation(String id, String response) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.put('/quotations/$id/respond', data: {
        'response': response,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response == 'ACCEPT' ? 'Quotation accepted! Grand Aqua team will process your order.' : 'Quotation declined.'),
            backgroundColor: response == 'ACCEPT' ? Colors.green : Colors.red,
          ),
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

  void _showDetailsDialog(Map<String, dynamic> q) {
    final items = (q['items'] as List<dynamic>?) ?? [];
    final salesman = q['salesman'] ?? {};
    final salesmanUser = salesman['user'] ?? {};

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          constraints: const BoxConstraints(maxHeight: 700),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q['quotationNumber'] ?? 'Quotation Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Valid for ${q['validityDays'] ?? 15} days',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(q['status']),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),

              Expanded(
                child: ListView(
                  children: [
                    // Sales Representative Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Color(0xFF0284C7),
                            radius: 18,
                            child: Icon(Icons.support_agent, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  salesmanUser['fullName'] ?? 'Grand Aqua Direct Support',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                Text(
                                  salesmanUser['phone'] != null ? 'Representative Contact: ${salesmanUser['phone']}' : 'Official Corporate Quote',
                                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Items Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'ITEMIZED BREAKDOWN',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          '${items.length} Product(s)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Table with # | Image | Product | Qty | Price | Total
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 62,
                            dataRowMaxHeight: 72,
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
                                final lineTotalTaxable = qty * unitPrice;

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
                                        width: 180,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              sku.isNotEmpty && prodName.contains('($sku)')
                                                  ? prodName.replaceAll('($sku)', '').trim()
                                                  : prodName,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (sku.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Model: $sku',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0284C7),
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            if (subNote.isNotEmpty) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                subNote,
                                                style: const TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 4. Qty
                                    DataCell(
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              qty.toStringAsFixed(0),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                            ),
                                            Text(
                                              uom,
                                              style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // 5. Price
                                    DataCell(
                                      Text(
                                        currency.format(unitPrice),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A)),
                                      ),
                                    ),
                                    // 6. Total (without GST)
                                    DataCell(
                                      Text(
                                        currency.format(lineTotalTaxable),
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
                    ),
                    const SizedBox(height: 16),

                    if (q['status'] == 'PENDING_DISCOUNT_APPROVAL' || q['status'] == 'DRAFT')
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade800, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Quotation sent for approval! Assigned sales staff & Super Admin are reviewing and calculating shipping charges based on products, quantity, and km distance.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                              const Text('Subtotal (Products):', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              Text(currency.format(_toNumber(q['subtotal'])), style: const TextStyle(fontSize: 11, color: Colors.white, fontFamily: 'monospace')),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _toNumber(q['taxRate']) > 0 ? 'GST (${q['taxRate']}%):' : 'GST Slab:',
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                              Text(
                                _toNumber(q['taxRate']) > 0
                                    ? currency.format(_toNumber(q['taxAmount']))
                                    : 'Pending Approval (5%–18%)',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _toNumber(q['taxRate']) > 0 ? Colors.white : const Color(0xFF93C5FD),
                                  fontFamily: _toNumber(q['taxRate']) > 0 ? 'monospace' : null,
                                  fontWeight: _toNumber(q['taxRate']) > 0 ? FontWeight.normal : FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Shipping Charges Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Shipping Charges:', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              Text(
                                _toNumber(q['shippingCharges']) > 0
                                    ? currency.format(_toNumber(q['shippingCharges']))
                                    : (q['status'] == 'PENDING_DISCOUNT_APPROVAL' || q['status'] == 'DRAFT'
                                        ? 'Pending Calculation (TBD)'
                                        : '₹0 (Free / Included)'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _toNumber(q['shippingCharges']) > 0
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFFFCD34D),
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
                                Text('Special Concession (${q['discountApprovalStatus']}):', style: const TextStyle(fontSize: 11, color: Color(0xFFFCD34D))),
                                Text('-${currency.format(_toNumber(q['additionalDiscountRequested']))}', style: const TextStyle(fontSize: 11, color: Color(0xFFFCD34D), fontFamily: 'monospace')),
                              ],
                            ),
                          ],
                          const Divider(color: Colors.white24, height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('FINAL PAYABLE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
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

                    // Buttons: Download PDF, Edit Quote & Accept Quotation
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF0284C7)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.picture_as_pdf, size: 18, color: Color(0xFF0284C7)),
                            label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                            onPressed: () => _downloadQuotationPdf(q),
                          ),
                        ),
                        if (q['status'] != 'CONVERTED_TO_ORDER') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFF0284C7)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.edit_note, size: 18, color: Color(0xFF0284C7)),
                              label: const Text('Edit Quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _showEditQuotationSheet(q);
                              },
                            ),
                          ),
                        ],
                        if (q['status'] == 'ISSUED') ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Accept Quote', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _respondToQuotation(q['id'], 'ACCEPT');
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showProductPickerDialog() async {
    if (_products.isEmpty) {
      await _fetchProducts();
    }
    if (_products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No products available to add.')),
        );
      }
      return null;
    }

    if (!mounted) return null;
    String searchFilter = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final filtered = _products.where((p) {
            if (searchFilter.isEmpty) return true;
            final query = searchFilter.toLowerCase();
            final name = (p['name'] ?? '').toString().toLowerCase();
            final sku = (p['sku'] ?? '').toString().toLowerCase();
            return name.contains(query) || sku.contains(query);
          }).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Product to Quotation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) => setDialogState(() => searchFilter = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search product...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(child: Text('No matching products found'))
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final p = filtered[idx];
                              final price = _getPriceForProduct(p);
                              return ListTile(
                                dense: true,
                                title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                subtitle: Text(
                                  'SKU: ${p['sku'] ?? 'N/A'} • ₹${price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7)),
                                ),
                                trailing: const Icon(Icons.add_circle, color: Color(0xFF0284C7), size: 20),
                                onTap: () => Navigator.pop(dialogCtx, p),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, null),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditQuotationSheet(Map<String, dynamic> q) async {
    final quotationId = q['id'];
    if (quotationId == null) return;

    if (q['status'] == 'CONVERTED_TO_ORDER') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This quotation has already been converted to an order and cannot be edited.')),
      );
      return;
    }

    final rawItems = (q['items'] as List<dynamic>?) ?? [];
    List<Map<String, dynamic>> editedItems = [];
    for (var it in rawItems) {
      final prod = it['product'] ?? {};
      final mediaList = (prod['media'] as List<dynamic>?) ?? [];
      final imgObj = mediaList.firstWhere((m) => m['mediaType'] == 'IMAGE', orElse: () => null);
      String imgUrl = imgObj?['url'] ?? prod['imageUrl'] ?? it['imageUrl'] ?? '';
      if (imgUrl.startsWith('/uploads/')) {
        final api = ref.read(apiClientProvider);
        imgUrl = '${api.dio.options.baseUrl.replaceAll('/api/v1', '')}$imgUrl';
      }

      editedItems.add({
        'productId': it['productId'] ?? prod['id'],
        'productName': it['productName'] ?? prod['name'] ?? 'Product',
        'sku': it['sku'] ?? prod['sku'] ?? '',
        'imageUrl': imgUrl,
        'quantity': (it['quantity'] is num ? (it['quantity'] as num).toInt() : int.tryParse(it['quantity'].toString()) ?? 1),
        'unitPrice': _toNumber(it['unitPrice']),
      });
    }

    final buyerNotesCtrl = TextEditingController(text: q['buyerNotes'] ?? '');
    bool isSubmitting = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          double subtotal = 0;
          for (var item in editedItems) {
            subtotal += (item['unitPrice'] as double) * (item['quantity'] as int);
          }
          final estTotal = subtotal;

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Quotation',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Text(
                            'Quote #${q['quotationNumber'] ?? ''}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Scrollable Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Information notice about shipping charges
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'You can adjust item quantities, remove items, or add products. After updating, your quotation will be resent for approval so Super Admin can calculate final shipping charges based on items, quantity, and km distance.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Items list title and Add Item button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'QUOTED ITEMS (${editedItems.length})',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              final selectedProd = await _showProductPickerDialog();
                              if (selectedProd != null) {
                                final pId = selectedProd['id'];
                                final existingIdx = editedItems.indexWhere((e) => e['productId'] == pId);
                                if (existingIdx >= 0) {
                                  setSheetState(() {
                                    editedItems[existingIdx]['quantity'] = (editedItems[existingIdx]['quantity'] as int) + 1;
                                  });
                                } else {
                                  final mediaList = (selectedProd['media'] as List<dynamic>?) ?? [];
                                  final imgObj = mediaList.firstWhere((m) => m['mediaType'] == 'IMAGE', orElse: () => null);
                                  String imgUrl = imgObj?['url'] ?? selectedProd['imageUrl'] ?? '';
                                  if (imgUrl.startsWith('/uploads/')) {
                                    final api = ref.read(apiClientProvider);
                                    imgUrl = '${api.dio.options.baseUrl.replaceAll('/api/v1', '')}$imgUrl';
                                  }

                                  final price = _getPriceForProduct(selectedProd);
                                  setSheetState(() {
                                    editedItems.add({
                                      'productId': selectedProd['id'],
                                      'productName': selectedProd['name'] ?? 'Product',
                                      'sku': selectedProd['sku'] ?? '',
                                      'imageUrl': imgUrl,
                                      'quantity': 1,
                                      'unitPrice': price,
                                    });
                                  });
                                }
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 16, color: Color(0xFF0284C7)),
                            label: const Text('Add Product', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Line items list
                      if (editedItems.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Please add at least one item.',
                              style: TextStyle(color: Colors.red.shade400, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        ...editedItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final qty = item['quantity'] as int;
                          final unitPrice = item['unitPrice'] as double;
                          final lineTotal = unitPrice * qty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: item['imageUrl'] != null && (item['imageUrl'] as String).isNotEmpty
                                      ? Image.network(
                                          item['imageUrl'],
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                        )
                                      : _buildCameraPlaceholder(),
                                ),
                                const SizedBox(width: 12),

                                // Product info & unit price
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['productName'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((item['sku'] ?? '').toString().isNotEmpty)
                                        Text(
                                          'SKU: ${item['sku']}',
                                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                        ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${unitPrice.toStringAsFixed(0)} each • Line: ₹${lineTotal.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                                      ),
                                    ],
                                  ),
                                ),

                                // Quantity Controls (- QTY +)
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      InkWell(
                                        onTap: () {
                                          setSheetState(() {
                                            if (qty > 1) {
                                              item['quantity'] = qty - 1;
                                            } else {
                                              if (editedItems.length > 1) {
                                                editedItems.removeAt(idx);
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Quotation must have at least 1 item.')),
                                                );
                                              }
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(6),
                                          child: Icon(
                                            qty == 1 ? Icons.delete_outline : Icons.remove,
                                            size: 16,
                                            color: qty == 1 ? Colors.red : Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '$qty',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          setSheetState(() {
                                            item['quantity'] = qty + 1;
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.all(6),
                                          child: Icon(Icons.add, size: 16, color: Color(0xFF0284C7)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 12),
                      // Buyer Notes
                      const Text(
                        'BUYER NOTES / SPECIAL REQUIREMENTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: buyerNotesCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Add delivery instructions or request special pricing...',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Financial summary strip
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal (Excl. Tax):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('₹${subtotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 11, fontFamily: 'monospace')),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GST Slab:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const Text('Applicable on Approval (5%–18%)', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Shipping Charge:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                Text('Pending Admin Calculation', style: TextStyle(color: Color(0xFFFCD34D), fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Divider(color: Colors.white24, height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('ESTIMATED BASE TOTAL (EXCL. GST):', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                Text(
                                  '₹${estTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.w900, fontSize: 16, fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom Action Button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSubmitting || editedItems.isEmpty
                          ? null
                          : () async {
                              setSheetState(() => isSubmitting = true);
                              try {
                                final api = ref.read(apiClientProvider);
                                await api.dio.put('/quotations/$quotationId', data: {
                                  'items': editedItems.map((e) => {
                                    'productId': e['productId'],
                                    'quantity': e['quantity'],
                                    'unitPrice': e['unitPrice'],
                                  }).toList(),
                                  'buyerNotes': buyerNotesCtrl.text.trim(),
                                });

                                if (mounted && ctx.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Quotation updated and resent for approval!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  _fetchQuotations();
                                }
                              } catch (err) {
                                setSheetState(() => isSubmitting = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update quotation: $err')),
                                  );
                                }
                              }
                            },
                      icon: isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        isSubmitting ? 'Updating...' : 'Save & Resend for Approval',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    String label = (status ?? 'DRAFT').replaceAll('_', ' ');

    switch (status) {
      case 'PENDING_DISCOUNT_APPROVAL':
      case 'DRAFT':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'PENDING APPROVAL';
        break;
      case 'ISSUED':
        bg = const Color(0xFFF0F9FF);
        fg = const Color(0xFF0369A1);
        label = 'APPROVED BY ADMIN';
        break;
      case 'ACCEPTED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'ACCEPTED';
        break;
      case 'CONVERTED_TO_ORDER':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        label = 'ORDER CONFIRMED';
        break;
      case 'REJECTED':
      case 'DISCOUNT_REJECTED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'DECLINED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _quotations.where((q) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final qNum = (q['quotationNumber'] ?? '').toString().toLowerCase();
        return qNum.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Commercial Quotations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Special Pricing Proposals & PDFs', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _fetchQuotations();
              _fetchProducts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search quotation #...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
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
                            Icon(Icons.request_quote_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No commercial proposals received yet', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await _fetchQuotations();
                          await _fetchProducts();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final q = filtered[index];
                            final itemsCount = (q['items'] as List<dynamic>?)?.length ?? 0;
                            final salesman = q['salesman']?['user']?['fullName'] ?? 'Direct Company';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey.shade200),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showDetailsDialog(q),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            q['quotationNumber'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: Color(0xFF0284C7),
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          _buildStatusBadge(q['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Prepared by: $salesman',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      Text(
                                        'Items: $itemsCount products • Valid for ${q['validityDays'] ?? 15} days',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.local_shipping_outlined,
                                            size: 13,
                                            color: _toNumber(q['shippingCharges']) > 0
                                                ? const Color(0xFF0284C7)
                                                : Colors.amber.shade800,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _toNumber(q['shippingCharges']) > 0
                                                ? 'Shipping: ${currency.format(_toNumber(q['shippingCharges']))}'
                                                : (q['status'] == 'PENDING_DISCOUNT_APPROVAL' || q['status'] == 'DRAFT'
                                                    ? 'Shipping: Pending Calculation'
                                                    : 'Shipping: Included'),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _toNumber(q['shippingCharges']) > 0
                                                  ? const Color(0xFF0284C7)
                                                  : Colors.amber.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            currency.format(_toNumber(q['finalTotal'])),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (q['status'] != 'CONVERTED_TO_ORDER')
                                                IconButton(
                                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF0284C7), size: 20),
                                                  tooltip: 'Edit Quotation',
                                                  onPressed: () => _showEditQuotationSheet(q),
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0284C7), size: 22),
                                                tooltip: 'Download PDF',
                                                onPressed: () => _downloadQuotationPdf(q),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.chevron_right, size: 22),
                                                onPressed: () => _showDetailsDialog(q),
                                              ),
                                            ],
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
