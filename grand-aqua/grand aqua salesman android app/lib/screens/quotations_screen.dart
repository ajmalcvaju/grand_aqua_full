import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth_provider.dart';

class QuotationsScreen extends ConsumerStatefulWidget {
  const QuotationsScreen({super.key});

  @override
  ConsumerState<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends ConsumerState<QuotationsScreen> {
  List<dynamic> _quotations = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  final currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹ ', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _fetchQuotations();
  }

  Future<void> _fetchQuotations() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/quotations');
      final data = res.data['data'] ?? res.data;
      setState(() {
        _quotations = data['quotations'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
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

  void _showDetailsDialog(Map<String, dynamic> q) {
    final items = (q['items'] as List<dynamic>?) ?? [];
    final buyer = q['buyer'] ?? {};
    final buyerUser = buyer['user'] ?? {};

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
                          'Created: ${q['createdAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(q['createdAt'])) : 'N/A'}',
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
                    // Buyer details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BUYER INFORMATION',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text(
                            buyer['businessName'] ?? buyerUser['fullName'] ?? 'Valued Customer',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Type: ${buyer['buyerType'] ?? 'CUSTOMER'} • Tier: ${buyer['loyaltyTier'] ?? 'BRONZE'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                          ),
                          if (buyerUser['phone'] != null)
                            Text(
                              'Phone: ${buyerUser['phone']}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Items Title
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
                                              overflow: TextOverflow.ellipsis,
                                            ),
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
                          if (_toNumber(q['additionalDiscountRequested']) > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Special Discount (${q['discountApprovalStatus']}):', style: const TextStyle(fontSize: 11, color: Color(0xFFFCD34D))),
                                Text('-${currency.format(_toNumber(q['additionalDiscountRequested']))}', style: const TextStyle(fontSize: 11, color: Color(0xFFFCD34D), fontFamily: 'monospace')),
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
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF2DD4BF), fontFamily: 'monospace'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Download PDF Button
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _downloadQuotationPdf(q),
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

  Widget _buildStatusBadge(String? status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;

    switch (status) {
      case 'PENDING_DISCOUNT_APPROVAL':
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade800;
        break;
      case 'ISSUED':
        bg = Colors.teal.shade50;
        fg = Colors.teal.shade800;
        break;
      case 'ACCEPTED':
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        break;
      case 'CONVERTED_TO_ORDER':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade800;
        break;
      case 'REJECTED':
      case 'DISCOUNT_REJECTED':
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        (status ?? 'DRAFT').replaceAll('_', ' '),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _quotations.where((q) {
      if (_statusFilter != 'ALL' && q['status'] != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final qNum = (q['quotationNumber'] ?? '').toString().toLowerCase();
        final buyerName = (q['buyer']?['businessName'] ?? q['buyer']?['user']?['fullName'] ?? '').toString().toLowerCase();
        return qNum.contains(query) || buyerName.contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Quotations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Trade Proposals & PDF Downloads', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchQuotations,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/quotation-builder'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('New Quotation', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search quotation # or shop name...',
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
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'ALL',
                      'PENDING_DISCOUNT_APPROVAL',
                      'ISSUED',
                      'ACCEPTED',
                      'CONVERTED_TO_ORDER',
                    ].map((status) {
                      final isSelected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            status == 'ALL' ? 'All' : status.replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.grey.shade700,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D9488),
                          backgroundColor: Colors.grey.shade100,
                          showCheckmark: false,
                          onSelected: (val) {
                            if (val) setState(() => _statusFilter = status);
                          },
                        ),
                      );
                    }).toList(),
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
                            Icon(Icons.request_quote_outlined, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 8),
                            Text('No quotations found', style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchQuotations,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final q = filtered[index];
                            final buyer = q['buyer'] ?? {};
                            final buyerUser = buyer['user'] ?? {};
                            final itemsCount = (q['items'] as List<dynamic>?)?.length ?? 0;

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
                                              color: Color(0xFF0D9488),
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          _buildStatusBadge(q['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        buyer['businessName'] ?? buyerUser['fullName'] ?? 'Valued Customer',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Type: ${buyer['buyerType'] ?? 'CUSTOMER'} • Items: $itemsCount',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
                                              IconButton(
                                                icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF0D9488), size: 22),
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
