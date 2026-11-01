import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/auth_provider.dart';

class LoyaltyScreen extends ConsumerStatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  ConsumerState<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends ConsumerState<LoyaltyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;

  // Loyalty Summary
  double _points = 0.0;
  double _rupeeValue = 0.0;
  bool _loyaltyEnabled = true;
  bool _programEnabled = true;
  double _accrualPct = 0.5;

  // Catalog & History
  List<dynamic> _gifts = [];
  List<dynamic> _history = [];
  List<dynamic> _myRedemptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(dynamic url) {
    if (url == null) return '';
    final clean = url.toString().trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    final dio = ref.read(dioProvider);
    final base = dio.options.baseUrl.replaceAll('/api/v1', '');
    return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dio = ref.read(dioProvider);

      final summaryRes = await dio.get('/loyalty/my-summary');
      final giftsRes = await dio.get('/loyalty/gifts', queryParameters: {'forBuyer': 'true'});
      final historyRes = await dio.get('/loyalty/my-history');

      final sData = summaryRes.data['data'] ?? summaryRes.data;
      _points = (sData['points'] as num?)?.toDouble() ?? 0.0;
      _rupeeValue = (sData['rupeeValue'] as num?)?.toDouble() ?? _points;
      _loyaltyEnabled = sData['loyaltyEnabled'] ?? true;
      _programEnabled = sData['programEnabled'] ?? true;
      _accrualPct = (sData['accrualPercentage'] as num?)?.toDouble() ?? 0.5;

      _gifts = (giftsRes.data['data'] ?? giftsRes.data) as List<dynamic>? ?? [];
      _history = (historyRes.data['data'] ?? historyRes.data) as List<dynamic>? ?? [];

      // Filter redemptions from history or get redemptions if endpoint available
      try {
        final redRes = await dio.get('/loyalty/my-redemptions');
        _myRedemptions = (redRes.data['data'] ?? redRes.data) as List<dynamic>? ?? [];
      } catch (_) {
        // Fallback: derive from gifts in ledger
        _myRedemptions = [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _redeemGift(Map<String, dynamic> gift) async {
    final ptsReq = (gift['pointsRequired'] as num?)?.toDouble() ?? 0;
    if (_points < ptsReq) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You need ${(ptsReq - _points).toStringAsFixed(0)} more points to redeem this gift.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final notesCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.card_giftcard, color: Color(0xFF0284C7)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Redeem ${gift['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_resolveImageUrl(gift['imageUrl']).isNotEmpty)
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _resolveImageUrl(gift['imageUrl']),
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard, size: 36, color: Color(0xFF0284C7)),
                    ),
                  ),
                ),
              ),
            Text(
              'This will use ${ptsReq.toStringAsFixed(0)} points from your balance.',
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 6),
            Text(
              'Remaining Balance: ${(_points - ptsReq).toStringAsFixed(0)} pts',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Delivery Notes (Optional)',
                hintText: 'e.g. Deliver with my next order',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Claim Gift'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.post('/loyalty/redeem-gift', data: {
        'giftId': gift['id'],
        'notes': notesCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Congratulations! You redeemed ${gift['title']}!'),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Redemption failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final buyer = user?['buyerProfile'];
    final buyerName = buyer?['businessName'] ?? user?['fullName'] ?? 'Valued Customer';
    final loyaltyTier = buyer?['loyaltyTier'] ?? 'DIAMOND';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Loyalty & Gift Rewards', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllData),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Gift Catalog (${_gifts.length})', icon: const Icon(Icons.card_giftcard, size: 18)),
            Tab(text: 'Points History (${_history.length})', icon: const Icon(Icons.history, size: 18)),
            Tab(text: 'My Claims (${_myRedemptions.length})', icon: const Icon(Icons.mark_email_read_outlined, size: 18)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: Column(
                children: [
                  // Balance & Tier Header
                  _buildBalanceCard(buyerName, loyaltyTier),

                  // Tab Views
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildGiftCatalogTab(),
                        _buildHistoryTab(),
                        _buildMyRedemptionsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceCard(String buyerName, String tier) {
    final isProgramActive = _programEnabled && _loyaltyEnabled;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  buyerName,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.stars, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      tier,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'AVAILABLE LOYALTY POINTS',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _points.toStringAsFixed(0),
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 6),
              const Text(
                'points',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                  ],
                ),
                child: Text(
                  'Worth ₹${_rupeeValue.toStringAsFixed(0)}',
                  style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isProgramActive ? Icons.check_circle_outline : Icons.pause_circle_outline,
                  color: isProgramActive ? const Color(0xFF4ADE80) : Colors.orangeAccent,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isProgramActive
                        ? '1 pt = ₹1 • You earn ${_accrualPct}% points automatically on purchases'
                        : 'Loyalty program currently paused by Super Admin',
                    style: TextStyle(
                      color: isProgramActive ? const Color(0xFFE2E8F0) : Colors.orangeAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftCatalogTab() {
    if (_gifts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.card_giftcard, size: 56, color: Colors.grey),
              SizedBox(height: 12),
              Text('No gift rewards currently available', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              SizedBox(height: 4),
              Text('Check back soon! Super Admin regularly adds exclusive gifts.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _gifts.length,
      itemBuilder: (ctx, idx) {
        final gift = _gifts[idx];
        final ptsReq = (gift['pointsRequired'] as num?)?.toDouble() ?? 0;
        final stock = gift['stock'] as int? ?? 0;
        final canRedeem = _points >= ptsReq && stock > 0 && _loyaltyEnabled && _programEnabled;
        final imgUrl = _resolveImageUrl(gift['imageUrl']);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.15)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: imgUrl.isNotEmpty
                        ? Image.network(
                            imgUrl,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 28),
                          )
                        : const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gift['title'] ?? 'Gift',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                      if (gift['description'] != null && gift['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            gift['description'],
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Text(
                              '${ptsReq.toStringAsFixed(0)} pts',
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, color: Colors.amber.shade900),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stock > 0 ? '$stock in stock' : 'Out of stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: stock > 0 ? Colors.green.shade700 : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: canRedeem ? const Color(0xFF0284C7) : Colors.grey.shade300,
                            foregroundColor: canRedeem ? Colors.white : Colors.grey.shade600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: canRedeem ? () => _redeemGift(gift) : null,
                          child: Text(
                            canRedeem
                                ? 'Claim Gift (${ptsReq.toStringAsFixed(0)} pts)'
                                : stock <= 0
                                    ? 'Out of Stock'
                                    : 'Need ${(ptsReq - _points).toStringAsFixed(0)} More Pts',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 52, color: Colors.grey),
              SizedBox(height: 10),
              Text('No points transactions yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 4),
              Text('Points earned from your purchases or gift redemptions will appear here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _history.length,
      separatorBuilder: (ctx, idx) => const Divider(height: 1),
      itemBuilder: (ctx, idx) {
        final item = _history[idx];
        final isCredit = item['type'] == 'CREDIT';
        final pts = (item['points'] as num?)?.toDouble() ?? 0;
        final balAfter = (item['balanceAfter'] as num?)?.toDouble() ?? 0;
        final dateStr = item['createdAt'] != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['createdAt']))
            : '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: isCredit ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(
              isCredit ? Icons.add : Icons.remove,
              color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
              size: 20,
            ),
          ),
          title: Text(
            item['reason'] ?? (isCredit ? 'Points Earned' : 'Points Spent'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          subtitle: Text(
            '$dateStr • Balance: ${balAfter.toStringAsFixed(0)} pts',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          trailing: Text(
            '${isCredit ? '+' : '-'}${pts.toStringAsFixed(0)} pts',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: isCredit ? const Color(0xFF10B981) : Colors.red.shade700,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMyRedemptionsTab() {
    if (_myRedemptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 52, color: Colors.grey),
              SizedBox(height: 10),
              Text('No gifts claimed yet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 4),
              Text('Redeem any gift from the Gift Catalog using your loyalty points!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _myRedemptions.length,
      itemBuilder: (ctx, idx) {
        final r = _myRedemptions[idx];
        final giftTitle = r['gift']?['title'] ?? 'Gift Reward';
        final pts = (r['pointsSpent'] as num?)?.toDouble() ?? 0;
        final status = r['status'] ?? 'REQUESTED';
        final dateStr = r['createdAt'] != null ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['createdAt'])) : '';

        Color statusColor = Colors.orange;
        if (status == 'APPROVED') statusColor = Colors.blue;
        if (status == 'DISPATCHED') statusColor = Colors.indigo;
        if (status == 'DELIVERED') statusColor = Colors.green;
        if (status == 'REJECTED') statusColor = Colors.red;

        final giftImgUrl = _resolveImageUrl(r['gift']?['imageUrl']);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: giftImgUrl.isNotEmpty
                    ? Image.network(
                        giftImgUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 20),
                      )
                    : const Icon(Icons.card_giftcard, color: Color(0xFF0284C7), size: 20),
              ),
            ),
            title: Text(giftTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Claimed on $dateStr • ${pts.toStringAsFixed(0)} pts', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            trailing: Container(
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
          ),
        );
      },
    );
  }
}
