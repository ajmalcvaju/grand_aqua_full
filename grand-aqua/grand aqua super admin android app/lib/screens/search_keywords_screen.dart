import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class SearchKeywordsScreen extends ConsumerStatefulWidget {
  const SearchKeywordsScreen({super.key});

  @override
  ConsumerState<SearchKeywordsScreen> createState() => _SearchKeywordsScreenState();
}

class _SearchKeywordsScreenState extends ConsumerState<SearchKeywordsScreen> {
  List<dynamic> _buyers = [];
  bool _isLoading = true;
  String _buyerSearch = '';
  String _selectedBuyerType = 'ALL';

  @override
  void initState() {
    super.initState();
    _fetchBuyers();
  }

  Future<void> _fetchBuyers() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/search-analytics/buyers');
      dynamic listData = res.data;
      while (listData is Map && listData.containsKey('data')) {
        listData = listData['data'];
      }
      setState(() {
        _buyers = (listData as List<dynamic>?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> get _filteredBuyers {
    return _buyers.filter((b) {
      final q = _buyerSearch.toLowerCase().trim();
      final name = (b['fullName'] ?? '').toString().toLowerCase();
      final bName = (b['businessName'] ?? '').toString().toLowerCase();
      final phone = (b['phone'] ?? '').toString().toLowerCase();
      final code = (b['buyerId'] ?? '').toString().toLowerCase();

      final matchesSearch = q.isEmpty || name.contains(q) || bName.contains(q) || phone.contains(q) || code.contains(q);
      final matchesType = _selectedBuyerType == 'ALL' || b['buyerType'] == _selectedBuyerType;
      return matchesSearch && matchesType;
    }).toList();
  }

  void _showBuyerKeywordsSheet(Map<String, dynamic> buyerSummary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BuyerKeywordsDetailModal(buyerId: buyerSummary['id']),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBuyers;
    final totalSearches = _buyers.fold<int>(0, (sum, b) => sum + ((b['totalSearches'] as num?)?.toInt() ?? 0));
    final totalTerms = _buyers.fold<int>(0, (sum, b) => sum + ((b['uniqueKeywordsCount'] as num?)?.toInt() ?? 0));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Buyer Search Keywords', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchBuyers,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/search-keywords'),
      body: RefreshIndicator(
        onRefresh: _fetchBuyers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Stats Overview Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Buyer Search Analytics',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Track what products and terms buyers are searching for across the mobile catalog.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat('${_buyers.length}', 'Active Buyers'),
                      Container(width: 1, height: 28, color: Colors.white24),
                      _buildSummaryStat('$totalSearches', 'Total Searches'),
                      Container(width: 1, height: 28, color: Colors.white24),
                      _buildSummaryStat('$totalTerms', 'Unique Terms'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Buyer Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _buyerSearch = val),
                decoration: InputDecoration(
                  hintText: 'Search buyer name, phone, code...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF0284C7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // 3. Buyer Type Filter Pills
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['ALL', 'CUSTOMER', 'DEALER', 'WHOLESALER', 'DISTRIBUTOR'].map((type) {
                  final isSelected = _selectedBuyerType == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(type),
                      selected: isSelected,
                      onSelected: (_) => setState(() => _selectedBuyerType = type),
                      selectedColor: const Color(0xFF0284C7),
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 14),

            // 4. Header with count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Buyers with Searches (${filtered.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const Text(
                  'Tap buyer for keywords',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 5. Buyers List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        'No buyers have searched matching this filter',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) {
                  final b = filtered[i];
                  final totalS = b['totalSearches'] ?? 0;
                  final uniqueK = b['uniqueKeywordsCount'] ?? 0;
                  final topK = (b['topKeywords'] as List<dynamic>?) ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: InkWell(
                      onTap: () => _showBuyerKeywordsSheet(b),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar with initial
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: const Color(0xFFE0F2FE),
                                  child: Text(
                                    (b['fullName'] ?? 'B').toString().substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              b['businessName'] ?? b['fullName'] ?? 'Buyer',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              b['buyerType'] ?? 'CUSTOMER',
                                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${b['fullName']} • ${b['phone'] ?? ''}',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const Divider(height: 18),

                            // Stats & Top searches preview
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.local_fire_department, size: 14, color: Color(0xFF0284C7)),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$totalS Searches',
                                            style: const TextStyle(color: Color(0xFF0369A1), fontWeight: FontWeight.bold, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '$uniqueK keywords',
                                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF94A3B8)),
                              ],
                            ),

                            if (topK.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: topK.map((k) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Text(
                                      '"${k['keyword']}" (${k['count']}x)',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF334155), fontFamily: 'monospace'),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

class _BuyerKeywordsDetailModal extends ConsumerStatefulWidget {
  final String buyerId;
  const _BuyerKeywordsDetailModal({required this.buyerId});

  @override
  ConsumerState<_BuyerKeywordsDetailModal> createState() => _BuyerKeywordsDetailModalState();
}

class _BuyerKeywordsDetailModalState extends ConsumerState<_BuyerKeywordsDetailModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _buyerData;
  List<dynamic> _keywords = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/search-analytics/buyer/${widget.buyerId}');
      dynamic mapData = res.data;
      while (mapData is Map && mapData.containsKey('data') && mapData['data'] is Map) {
        mapData = mapData['data'];
      }
      setState(() {
        _buyerData = mapData is Map ? mapData['buyer'] : null;
        _keywords = (mapData is Map && mapData['keywords'] is List) ? (mapData['keywords'] as List<dynamic>) : [];
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _keywords.where((k) {
      final kw = (k['keyword'] ?? '').toString().toLowerCase();
      return _filter.isEmpty || kw.contains(_filter.toLowerCase().trim());
    }).toList();

    final maxCount = _keywords.fold<int>(1, (max, k) {
      final c = (k['searchCount'] as num?)?.toInt() ?? 1;
      return c > max ? c : max;
    });

    final totalSearches = _keywords.fold<int>(0, (sum, k) => sum + ((k['searchCount'] as num?)?.toInt() ?? 0));

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _buyerData?['businessName'] ?? 'Buyer Search Detail',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                      ),
                      if (_buyerData != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_buyerData?['fullName']} • ${_buyerData?['phone'] ?? ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Summary Stats Bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 4),
                    Text(
                      '$totalSearches Total Searches',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                Container(width: 1, height: 16, color: Colors.grey.shade300),
                Row(
                  children: [
                    const Icon(Icons.tag, size: 16, color: Colors.purple),
                    const SizedBox(width: 4),
                    Text(
                      '${_keywords.length} Unique Terms',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Keyword filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Filter searched keywords...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                prefixIcon: const Icon(Icons.filter_list, size: 16, color: Color(0xFF0284C7)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),

          // Keywords List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Text(
                          _keywords.isEmpty ? 'No keywords searched by this buyer yet.' : 'No matching keywords.',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final kw = filtered[i];
                          final count = (kw['searchCount'] as num?)?.toInt() ?? 1;
                          final pct = count / maxCount;
                          final dateStr = kw['lastSearchedAt'] != null
                              ? DateTime.tryParse(kw['lastSearchedAt'])?.toLocal().toString().split('.')[0] ?? ''
                              : '';

                          return Container(
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '"${kw['keyword']}"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          fontFamily: 'monospace',
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F2FE),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFBAE6FD)),
                                      ),
                                      child: Text(
                                        'Searched $count ${count == 1 ? 'time' : 'times'}',
                                        style: const TextStyle(
                                          color: Color(0xFF0284C7),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Progress bar of search frequency
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0.08, 1.0),
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                                    minHeight: 4,
                                  ),
                                ),
                                if (dateStr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Last searched: $dateStr',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

extension _IterableFilter<T> on Iterable<T> {
  Iterable<T> filter(bool Function(T) test) => where(test);
}
