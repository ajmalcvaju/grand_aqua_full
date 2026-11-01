import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../widgets/admin_drawer.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiClient _api = ApiClient();

  bool _isLoading = true;
  String? _error;

  // Config
  bool _programEnabled = true;
  double _percentage = 0.5;
  double _rupeeRate = 1.0;
  final TextEditingController _percentageCtrl = TextEditingController();

  // Buyers
  List<dynamic> _buyers = [];
  String _buyerSearch = '';

  // Gifts
  List<dynamic> _gifts = [];

  // Redemptions
  List<dynamic> _redemptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _percentageCtrl.dispose();
    super.dispose();
  }

  String _resolveImageUrl(dynamic url) {
    if (url == null) return '';
    final clean = url.toString().trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    final base = _api.dio.options.baseUrl.replaceAll('/api/v1', '');
    return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final configRes = await _api.dio.get('/loyalty/config');
      final buyersRes = await _api.dio.get('/loyalty/buyers');
      final giftsRes = await _api.dio.get('/loyalty/gifts');
      final redemptionsRes = await _api.dio.get('/loyalty/redemptions');

      final cfg = configRes.data['data'] ?? configRes.data;
      _programEnabled = cfg['enabled'] ?? cfg['programEnabled'] ?? true;
      _percentage = (cfg['percentage'] as num?)?.toDouble() ?? 0.5;
      _rupeeRate = (cfg['rupeePerPoint'] ?? cfg['pointRupeeRate'] as num?)?.toDouble() ?? 1.0;
      _percentageCtrl.text = _percentage.toString();

      _buyers = (buyersRes.data['data'] ?? buyersRes.data) as List<dynamic>? ?? [];
      _gifts = (giftsRes.data['data'] ?? giftsRes.data) as List<dynamic>? ?? [];
      _redemptions = (redemptionsRes.data['data'] ?? redemptionsRes.data) as List<dynamic>? ?? [];

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load loyalty data: $e';
      });
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      if (e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map && d['message'] != null) {
          final m = d['message'];
          if (m is List) return m.join(', ');
          return m.toString();
        }
      }
      return e.message ?? 'Server communication error';
    }
    return e.toString();
  }

  Future<void> _saveConfig() async {
    final rawText = _percentageCtrl.text.replaceAll('%', '').trim();
    final parsedPct = double.tryParse(rawText) ?? _percentage;
    try {
      await _api.dio.put('/loyalty/config', data: {
        'enabled': _programEnabled,
        'programEnabled': _programEnabled,
        'percentage': parsedPct,
        'rupeePerPoint': _rupeeRate,
        'pointRupeeRate': _rupeeRate,
      });
      _percentage = parsedPct;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loyalty settings updated successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update config: ${_extractError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleBuyerLoyalty(String buyerId, bool currentEnabled) async {
    final newEnabled = !currentEnabled;
    try {
      await _api.dio.put('/loyalty/buyers/$buyerId/toggle-loyalty', data: {
        'enabled': newEnabled,
        'loyaltyEnabled': newEnabled,
      });
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newEnabled ? 'Loyalty enabled for customer' : 'Loyalty suspended for customer'),
            backgroundColor: newEnabled ? const Color(0xFF10B981) : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: ${_extractError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAdjustPointsDialog(Map<String, dynamic> buyer) {
    final buyerId = (buyer['id'] ?? buyer['buyerProfileId'] ?? '').toString();
    final buyerName = buyer['businessName'] ?? buyer['buyerName'] ?? 'Buyer';
    final currentPts = ((buyer['loyaltyPoints'] ?? buyer['points'] ?? 0) as num).toDouble();

    final pointsCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    String type = 'CREDIT'; // CREDIT or DEBIT

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Adjust Points: $buyerName',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Balance: ${currentPts.toStringAsFixed(0)} pts (₹${currentPts.toStringAsFixed(0)})',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('+ Credit (Add)'),
                        selected: type == 'CREDIT',
                        selectedColor: Colors.green.shade100,
                        onSelected: (v) => setDlgState(() => type = 'CREDIT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('- Debit (Reduce)'),
                        selected: type == 'DEBIT',
                        selectedColor: Colors.red.shade100,
                        onSelected: (v) => setDlgState(() => type = 'DEBIT'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pointsCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Points Amount',
                    hintText: 'e.g. 500',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Remarks',
                    hintText: 'e.g. Festive promotion bonus',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: type == 'CREDIT' ? const Color(0xFF10B981) : Colors.red,
              ),
              onPressed: () async {
                final pts = double.tryParse(pointsCtrl.text.trim());
                if (pts == null || pts <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid points amount')),
                  );
                  return;
                }
                final reason = reasonCtrl.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a reason')),
                  );
                  return;
                }

                try {
                  await _api.dio.post('/loyalty/buyers/$buyerId/adjust-points', data: {
                    'type': type,
                    'amount': pts,
                    'points': pts,
                    'reason': reason,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Points ${type == 'CREDIT' ? 'credited' : 'debited'} successfully!'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${_extractError(e)}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: Text(type == 'CREDIT' ? 'Add Points' : 'Reduce Points'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBuyerHistorySheet(Map<String, dynamic> buyer) async {
    final buyerId = (buyer['id'] ?? buyer['buyerProfileId'] ?? '').toString();
    final buyerName = buyer['businessName'] ?? buyer['buyerName'] ?? 'Buyer';
    final currentPts = ((buyer['loyaltyPoints'] ?? buyer['points'] ?? 0) as num).toDouble();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => FutureBuilder(
        future: _api.dio.get('/loyalty/buyers/$buyerId/history'),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 350,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return SizedBox(
              height: 350,
              child: Center(child: Text('Error loading history: ${snapshot.error}')),
            );
          }

          final resData = snapshot.data?.data;
          final root = (resData?['data'] ?? resData);
          final history = (root is Map && root['history'] != null)
              ? (root['history'] as List<dynamic>)
              : (root as List<dynamic>? ?? []);

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollController) => Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              buyerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Balance: ${currentPts.toStringAsFixed(0)} pts (₹${currentPts.toStringAsFixed(0)})',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? const Center(child: Text('No transaction history recorded yet'))
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: history.length,
                          separatorBuilder: (ctx2, idx2) => const Divider(height: 1),
                          itemBuilder: (ctx, idx) {
                            final item = history[idx];
                            final pts = (item['points'] as num?)?.toDouble() ?? 0;
                            final isCredit = item['transactionType'] == 'ORDER_EARNED' ||
                                item['transactionType'] == 'ADMIN_CREDIT' ||
                                item['transactionType'] == 'REDEMPTION_REFUND' ||
                                item['type'] == 'CREDIT' ||
                                pts > 0;
                            final balAfter = (item['balanceAfter'] as num?)?.toDouble() ?? 0;
                            final dateStr = item['createdAt'] != null
                                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['createdAt']))
                                : '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
                                child: Icon(
                                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isCredit ? Colors.green : Colors.red,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item['description'] ?? item['reason'] ?? (isCredit ? 'Points Credited' : 'Points Debited'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '$dateStr • Balance after: ${balAfter.toStringAsFixed(0)} pts',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                              trailing: Text(
                                '${isCredit ? '+' : '-'}${pts.abs().toStringAsFixed(0)} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddEditGiftDialog([Map<String, dynamic>? gift]) {
    final titleCtrl = TextEditingController(text: gift?['title'] ?? '');
    final descCtrl = TextEditingController(text: gift?['description'] ?? '');
    final pointsCtrl = TextEditingController(text: gift != null ? '${gift['pointsRequired']}' : '');
    final currentStock = gift != null ? (gift['stockQuantity'] ?? gift['stock'] ?? 10) : 10;
    final stockCtrl = TextEditingController(text: '$currentStock');
    final imgUrlCtrl = TextEditingController(text: gift?['imageUrl'] ?? '');
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final previewUrl = _resolveImageUrl(imgUrlCtrl.text.trim());

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(gift == null ? 'Add New Gift Reward' : 'Edit Gift Reward', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Gift Image Preview & Picker
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: previewUrl.isNotEmpty
                          ? Image.network(
                              previewUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                            )
                          : const Icon(Icons.card_giftcard, size: 44, color: Color(0xFF0284C7)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: isUploadingImage
                            ? null
                            : () async {
                                try {
                                  final result = await FilePicker.pickFiles(type: FileType.image);
                                  if (result.isEmpty) return;
                                  final picked = result.first;

                                  setDialogState(() => isUploadingImage = true);

                                  MultipartFile multipartFile;
                                  if (picked.path != null) {
                                    multipartFile = await MultipartFile.fromFile(picked.path!, filename: picked.name);
                                  } else {
                                    final fileBytes = await picked.readAsBytes();
                                    multipartFile = MultipartFile.fromBytes(fileBytes, filename: picked.name);
                                  }

                                  final formData = FormData.fromMap({'file': multipartFile});
                                  final res = await _api.dio.post('/upload', data: formData);
                                  final data = res.data['data'] ?? res.data;
                                  final uploadedUrl = (data['url'] ?? data['relativePath'] ?? '').toString();

                                  setDialogState(() {
                                    isUploadingImage = false;
                                    if (uploadedUrl.isNotEmpty) {
                                      imgUrlCtrl.text = uploadedUrl;
                                    }
                                  });
                                } catch (err) {
                                  setDialogState(() => isUploadingImage = false);
                                  if (ctx.mounted) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Upload failed: $err'), backgroundColor: Colors.red));
                                  }
                                }
                              },
                        icon: isUploadingImage
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: Text(isUploadingImage ? 'Uploading...' : 'Pick Image', style: const TextStyle(fontSize: 12)),
                      ),
                      if (imgUrlCtrl.text.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              imgUrlCtrl.clear();
                            });
                          },
                          child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Gift Title *', hintText: 'e.g. Stainless Steel Water Bottle', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Points Required *', hintText: 'e.g. 500', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Available Stock *', hintText: 'e.g. 25', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'Specs or terms', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imgUrlCtrl,
                    decoration: const InputDecoration(labelText: 'Image URL / Path', hintText: '/uploads/... or https://...', border: OutlineInputBorder(), isDense: true),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final pts = double.tryParse(pointsCtrl.text.trim()) ?? 0;
                  final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;
                  final imgUrl = imgUrlCtrl.text.trim();

                  if (title.isEmpty || pts <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter valid title and points')));
                    return;
                  }

                  try {
                    if (gift == null) {
                      await _api.dio.post('/loyalty/gifts', data: {
                        'title': title,
                        'description': descCtrl.text.trim(),
                        'pointsRequired': pts,
                        'stockQuantity': stock,
                        'stock': stock,
                        if (imgUrl.isNotEmpty) 'imageUrl': imgUrl,
                        'isActive': true,
                      });
                    } else {
                      await _api.dio.put('/loyalty/gifts/${gift['id']}', data: {
                        'title': title,
                        'description': descCtrl.text.trim(),
                        'pointsRequired': pts,
                        'stockQuantity': stock,
                        'stock': stock,
                        'imageUrl': imgUrl.isNotEmpty ? imgUrl : null,
                      });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadAllData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(gift == null ? 'Gift added successfully!' : 'Gift updated!'),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: ${_extractError(e)}'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: Text(gift == null ? 'Create Gift' : 'Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _updateRedemptionStatus(String id, String status) async {
    try {
      await _api.dio.put('/loyalty/redemptions/$id/status', data: {
        'status': status,
      });
      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Redemption status updated to $status${status == 'REJECTED' ? ' (Points refunded to buyer)' : ''}!'),
            backgroundColor: status == 'REJECTED' ? Colors.orange : const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${_extractError(e)}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loyalty & Gift Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF38BDF8),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: [
            Tab(text: 'Buyers (${_buyers.length})', icon: const Icon(Icons.people_alt_outlined, size: 18)),
            Tab(text: 'Gifts (${_gifts.length})', icon: const Icon(Icons.card_giftcard_outlined, size: 18)),
            Tab(text: 'Redemptions (${_redemptions.length})', icon: const Icon(Icons.inventory_outlined, size: 18)),
          ],
        ),
      ),
      drawer: const AdminDrawer(currentRoute: '/loyalty'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _loadAllData, child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Global Program Config Card
                    _buildGlobalConfigCard(),

                    // Tab View
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildBuyersTab(),
                          _buildGiftsTab(),
                          _buildRedemptionsTab(),
                        ],
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _tabController.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _showAddEditGiftDialog(),
              backgroundColor: const Color(0xFF0284C7),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Gift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildGlobalConfigCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _programEnabled ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.loyalty,
                      color: _programEnabled ? const Color(0xFF10B981) : Colors.red,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Loyalty Rewards Program',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        _programEnabled ? 'Active (All buyers eligible)' : 'Suspended for all customers',
                        style: TextStyle(
                          fontSize: 11,
                          color: _programEnabled ? const Color(0xFF10B981) : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: _programEnabled,
                activeColor: const Color(0xFF10B981),
                onChanged: (val) {
                  setState(() => _programEnabled = val);
                  _saveConfig();
                },
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Text('Accrual Rate: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    SizedBox(
                      width: 50,
                      height: 32,
                      child: TextField(
                        controller: _percentageCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          suffixText: '%',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('1 pt = ₹1', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _saveConfig,
                child: const Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyersTab() {
    final filtered = _buyers.where((b) {
      if (_buyerSearch.isEmpty) return true;
      final q = _buyerSearch.toLowerCase();
      final name = (b['businessName'] ?? b['buyerName'] ?? '').toString().toLowerCase();
      final phone = (b['phone'] ?? '').toString().toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: TextField(
            onChanged: (v) => setState(() => _buyerSearch = v),
            decoration: InputDecoration(
              hintText: 'Search buyer name or phone...',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No buyers found'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final b = filtered[idx];
                    final buyerId = (b['id'] ?? b['buyerProfileId'] ?? '').toString();
                    final pts = ((b['loyaltyPoints'] ?? b['points'] ?? 0) as num).toDouble();
                    final isEnabled = b['loyaltyEnabled'] ?? b['enabled'] ?? true;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                                      Text(
                                        b['businessName'] ?? b['buyerName'] ?? 'Buyer',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      Text(
                                        '${b['buyerType'] ?? 'CUSTOMER'} • ${b['phone'] ?? ''}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${pts.toStringAsFixed(0)} pts',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0284C7)),
                                      ),
                                      Text(
                                        '₹${pts.toStringAsFixed(0)}',
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Individual Toggle
                                Row(
                                  children: [
                                    Text(
                                      isEnabled ? 'Active' : 'Disabled',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isEnabled ? const Color(0xFF10B981) : Colors.red,
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch(
                                        value: isEnabled,
                                        activeColor: const Color(0xFF10B981),
                                        onChanged: (_) => _toggleBuyerLoyalty(buyerId, isEnabled),
                                      ),
                                    ),
                                  ],
                                ),
                                // Action buttons
                                Row(
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showAdjustPointsDialog(b),
                                      icon: const Icon(Icons.edit, size: 13),
                                      label: const Text('Adjust Points', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(Icons.history, size: 18, color: Color(0xFF0284C7)),
                                      onPressed: () => _showBuyerHistorySheet(b),
                                      tooltip: 'View Ledger History',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
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
      ],
    );
  }

  Widget _buildGiftsTab() {
    return _gifts.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.card_giftcard, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('No gift rewards configured yet'),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showAddEditGiftDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Gift Reward'),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: _gifts.length,
            itemBuilder: (ctx, idx) {
              final g = _gifts[idx];
              final pts = (g['pointsRequired'] as num?)?.toDouble() ?? 0;
              final stock = (g['stockQuantity'] ?? g['stock'] ?? 0) as int? ?? 0;
              final imgUrl = _resolveImageUrl(g['imageUrl']);

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imgUrl.isNotEmpty
                              ? Image.network(
                                  imgUrl,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 24),
                                )
                              : const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g['title'] ?? 'Gift', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            if (g['description'] != null && g['description'].toString().isNotEmpty)
                              Text(g['description'], style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${pts.toStringAsFixed(0)} Points Required',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Stock: $stock',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stock > 0 ? Colors.green.shade700 : Colors.red),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _showAddEditGiftDialog(g),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildRedemptionsTab() {
    return _redemptions.isEmpty
        ? const Center(child: Text('No gift redemption requests yet'))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: _redemptions.length,
            itemBuilder: (ctx, idx) {
              final r = _redemptions[idx];
              final pts = (r['pointsSpent'] as num?)?.toDouble() ?? 0;
              final status = r['status'] ?? 'REQUESTED';
              final buyerName = r['buyer']?['businessName'] ?? r['buyer']?['user']?['fullName'] ?? 'Buyer';
              final giftTitle = r['gift']?['title'] ?? 'Gift';
              final dateStr = r['createdAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['createdAt'])) : '';
              final giftImgUrl = _resolveImageUrl(r['gift']?['imageUrl']);

              Color statusColor = Colors.orange;
              if (status == 'APPROVED') statusColor = Colors.blue;
              if (status == 'DISPATCHED') statusColor = Colors.indigo;
              if (status == 'DELIVERED') statusColor = Colors.green;
              if (status == 'REJECTED') statusColor = Colors.red;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: giftImgUrl.isNotEmpty
                                        ? Image.network(
                                            giftImgUrl,
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard, size: 20, color: Color(0xFF0284C7)),
                                          )
                                        : const Icon(Icons.card_giftcard, size: 20, color: Color(0xFF0284C7)),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(buyerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      Text('Claimed: $giftTitle ($dateStr)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${pts.toStringAsFixed(0)} points redeemed', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0284C7))),
                          PopupMenuButton<String>(
                            onSelected: (val) => _updateRedemptionStatus(r['id'], val),
                            itemBuilder: (ctx) => [
                              const PopupMenuItem(value: 'APPROVED', child: Text('Mark Approved')),
                              const PopupMenuItem(value: 'DISPATCHED', child: Text('Mark Dispatched')),
                              const PopupMenuItem(value: 'DELIVERED', child: Text('Mark Delivered')),
                              const PopupMenuItem(value: 'REJECTED', child: Text('Reject & Refund Points', style: TextStyle(color: Colors.red))),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Text('Update Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  Icon(Icons.arrow_drop_down, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
