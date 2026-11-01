import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_provider.dart';
import '../widgets/product_sort_sheet.dart';
import '../widgets/product_filter_sheet.dart';
import '../widgets/product_whatsapp_share_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  List<dynamic> _products = [];
  List<dynamic> _categories = [];
  List<dynamic> _banners = [];
  Set<String> _purchasedProductIds = {};
  bool _isLoading = true;

  // Banner Carousel State
  final PageController _bannerController = PageController();
  int _currentBannerPage = 0;
  Timer? _bannerAutoScrollTimer;

  // Search, Sort & Filter State
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;
  String _searchQuery = '';
  ProductSortOption _currentSort = ProductSortOption.relevance;
  ProductFilterCriteria _filterCriteria = const ProductFilterCriteria();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _bannerAutoScrollTimer?.cancel();
    _bannerController.dispose();
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val);
    _searchDebounceTimer?.cancel();
    final trimmed = val.trim();
    if (trimmed.length >= 2) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        _logSearchKeyword(trimmed);
      });
    }
  }

  Future<void> _logSearchKeyword(String keyword) async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post('/search-analytics/log', data: {'keyword': keyword});
      debugPrint('[SearchAnalytics] Logged keyword "$keyword": ${res.statusCode}');
    } catch (e) {
      debugPrint('[SearchAnalytics] Error logging keyword "$keyword": $e');
    }
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      ref.read(authProvider.notifier).refreshProfile();
      final authState = ref.read(authProvider);
      final buyerType = authState.user?['buyerProfile']?['buyerType'] ?? 'CUSTOMER';

      // 1. Fetch products
      final res = await api.dio.get('/products?buyerType=$buyerType&limit=100');
      final data = res.data['data'] ?? res.data;

      // 2. Fetch categories
      List<dynamic> categories = [];
      try {
        final catRes = await api.dio.get('/products/categories');
        categories = (catRes.data['data'] ?? catRes.data) as List<dynamic>? ?? [];
      } catch (_) {}

      // 3. Fetch buyer purchase history for verified badges and review eligibility
      Set<String> purchasedIds = {};
      try {
        final purchasesRes = await api.dio.get('/reviews/my-purchases');
        final rawPurchases = purchasesRes.data is Map ? purchasesRes.data['data'] : purchasesRes.data;
        purchasedIds = (rawPurchases as List? ?? []).map((e) => e.toString()).toSet();
      } catch (_) {}

      // 4. Fetch audience-targeted promotional banners for this buyer
      List<dynamic> banners = [];
      try {
        final bRes = await api.dio.get('/banners/buyer-feed');
        banners = (bRes.data['data'] ?? bRes.data) as List<dynamic>? ?? [];
      } catch (_) {}

      setState(() {
        _products = data['products'] ?? [];
        _categories = categories;
        _banners = banners;
        _purchasedProductIds = purchasedIds;
        _isLoading = false;
      });

      _startBannerAutoScroll();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _startBannerAutoScroll() {
    _bannerAutoScrollTimer?.cancel();
    if (_banners.length <= 1) return;

    _bannerAutoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_banners.length > 1 && _bannerController.hasClients) {
        final next = (_currentBannerPage + 1) % _banners.length;
        _bannerController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  List<dynamic> get _filteredAndSortedProducts {
    List<dynamic> list = List.from(_products);

    // 1. Text Search Filter (name, sku, description, brand)
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      list = list.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        final brand = (p['brand'] ?? '').toString().toLowerCase();
        final desc = (p['shortDescription'] ?? '').toString().toLowerCase();
        return name.contains(q) || sku.contains(q) || brand.contains(q) || desc.contains(q);
      }).toList();
    }

    // 2. Category Filter
    if (_filterCriteria.selectedCategoryId != null) {
      list = list.where((p) => p['categoryId'] == _filterCriteria.selectedCategoryId).toList();
    }

    // 3. Price Range Filter
    list = list.where((p) {
      final price = (p['applicablePrice'] as num?)?.toDouble() ?? 0.0;
      return price >= _filterCriteria.minPrice && price <= _filterCriteria.maxPrice;
    }).toList();

    // 4. Customer Rating Filter
    if (_filterCriteria.minRating != null && _filterCriteria.minRating! > 0) {
      list = list.where((p) {
        final rating = (p['avgRating'] as num?)?.toDouble() ?? 0.0;
        return rating >= _filterCriteria.minRating!;
      }).toList();
    }

    // 5. In Stock Filter
    if (_filterCriteria.inStockOnly) {
      list = list.where((p) {
        final stock = (p['stockQuantity'] as num?)?.toInt() ?? 0;
        return stock > 0;
      }).toList();
    }

    // 6. Purchased by Me Filter
    if (_filterCriteria.purchasedOnly) {
      list = list.where((p) => _purchasedProductIds.contains(p['id'])).toList();
    }

    // 7. Featured Products Only Filter
    if (_filterCriteria.featuredOnly) {
      list = list.where((p) => p['isFeatured'] == true).toList();
    }

    // 8. Sorting
    switch (_currentSort) {
      case ProductSortOption.popularity:
        list.sort((a, b) {
          final popA = (a['popularity'] as num?)?.toInt() ?? 0;
          final popB = (b['popularity'] as num?)?.toInt() ?? 0;
          if (popB != popA) return popB.compareTo(popA);
          final revA = (a['reviewCount'] as num?)?.toInt() ?? 0;
          final revB = (b['reviewCount'] as num?)?.toInt() ?? 0;
          return revB.compareTo(revA);
        });
        break;

      case ProductSortOption.priceLowToHigh:
        list.sort((a, b) {
          final pA = (a['applicablePrice'] as num?)?.toDouble() ?? 0.0;
          final pB = (b['applicablePrice'] as num?)?.toDouble() ?? 0.0;
          return pA.compareTo(pB);
        });
        break;

      case ProductSortOption.priceHighToLow:
        list.sort((a, b) {
          final pA = (a['applicablePrice'] as num?)?.toDouble() ?? 0.0;
          final pB = (b['applicablePrice'] as num?)?.toDouble() ?? 0.0;
          return pB.compareTo(pA);
        });
        break;

      case ProductSortOption.ratingHighToLow:
        list.sort((a, b) {
          final rA = (a['avgRating'] as num?)?.toDouble() ?? 0.0;
          final rB = (b['avgRating'] as num?)?.toDouble() ?? 0.0;
          if (rB != rA) return rB.compareTo(rA);
          final cA = (a['reviewCount'] as num?)?.toInt() ?? 0;
          final cB = (b['reviewCount'] as num?)?.toInt() ?? 0;
          return cB.compareTo(cA);
        });
        break;

      case ProductSortOption.newest:
        list.sort((a, b) {
          final dateA = DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(1970);
          final dateB = DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        break;

      case ProductSortOption.alphabetical:
        list.sort((a, b) {
          final nameA = (a['name'] ?? '').toString().toLowerCase();
          final nameB = (b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });
        break;

      case ProductSortOption.relevance:
        // Featured items first, then original catalog order
        list.sort((a, b) {
          final featA = a['isFeatured'] == true ? 1 : 0;
          final featB = b['isFeatured'] == true ? 1 : 0;
          return featB.compareTo(featA);
        });
        break;
    }

    return list;
  }

  void _openSortSheet() async {
    final selected = await ProductSortSheet.show(
      context,
      currentSort: _currentSort,
    );
    if (selected != null && mounted) {
      setState(() => _currentSort = selected);
    }
  }

  void _openFilterSheet() async {
    final updated = await ProductFilterSheet.show(
      context,
      initialCriteria: _filterCriteria,
      categories: _categories,
    );
    if (updated != null && mounted) {
      setState(() => _filterCriteria = updated);
    }
  }

  void _resetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _currentSort = ProductSortOption.relevance;
      _filterCriteria = const ProductFilterCriteria();
    });
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF1F5F9),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
          ),
          child: Icon(Icons.water_drop_outlined, size: 22, color: Colors.blue.shade300),
        ),
      ),
    );
  }

  String _formatCredit(dynamic val) {
    if (val == null) return '0';
    final n = num.tryParse(val.toString()) ?? 0;
    return n.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final cartState = ref.watch(cartProvider);
    final buyer = authState.user?['buyerProfile'] ?? {};
    final buyerType = buyer['buyerType'] ?? 'CUSTOMER';
    final loyaltyTier = buyer['loyaltyTier'] ?? 'NONE';
    final creditAccount = buyer['creditAccount'] as Map<String, dynamic>?;
    final num creditLimit = num.tryParse((creditAccount?['creditLimit'] ?? buyer['creditLimit'] ?? 0).toString()) ?? 0;
    final num utilizedCredit = num.tryParse((creditAccount?['utilizedCredit'] ?? buyer['outstandingBalance'] ?? 0).toString()) ?? 0;
    final num availableCredit = num.tryParse((creditAccount?['availableCredit'] ?? (creditLimit - utilizedCredit).clamp(0, double.infinity)).toString()) ?? 0;

    final displayedProducts = _filteredAndSortedProducts;
    final totalActiveFilters = _filterCriteria.activeFilterCount + (_searchQuery.isNotEmpty ? 1 : 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Image.asset(
            'assets/images/grand_aqua_logo.png',
            height: 28,
            fit: BoxFit.contain,
          ),
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => context.push('/cart'),
              ),
              if (cartState.itemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${cartState.itemCount}',
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Loyalty & Account Status Banner (Tap to view Loyalty & Gifts)
            InkWell(
              onTap: () => context.push('/loyalty'),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          authState.user?['fullName'] ?? 'Valued Customer',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            buyerType,
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.stars, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text('Tier: $loyaltyTier Member', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.card_giftcard, color: Colors.white, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${((buyer['loyaltyPoints'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)} pts',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const Icon(Icons.chevron_right, color: Colors.white70, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (creditLimit > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.only(top: 8),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: Colors.white24, width: 0.8)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFEF08A), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Utilised Credit: ₹${_formatCredit(utilizedCredit)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFEF08A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Available: ₹${_formatCredit(availableCredit)}',
                              style: const TextStyle(
                                color: Color(0xFFBBF7D0),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_banners.isNotEmpty) const SizedBox(height: 12),

            // 2. Audience-Targeted Promotional Banners Carousel
            _buildBannerCarousel(),

            const SizedBox(height: 16),

            // 3. Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (val) {
                  final trimmed = val.trim();
                  if (trimmed.length >= 2) {
                    _searchDebounceTimer?.cancel();
                    _logSearchKeyword(trimmed);
                  }
                },
                decoration: InputDecoration(
                  hintText: 'Search purifiers, membranes, spares...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF0284C7), size: 20),
                    onPressed: () {
                      final trimmed = _searchController.text.trim();
                      if (trimmed.length >= 2) {
                        _searchDebounceTimer?.cancel();
                        _logSearchKeyword(trimmed);
                      }
                    },
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 3. Sort & Filter Action Bar
            Row(
              children: [
                // SORT BY BUTTON (Opens bottom sheet matching user's image)
                Expanded(
                  child: InkWell(
                    onTap: _openSortSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _currentSort != ProductSortOption.relevance
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_vert_rounded,
                            size: 18,
                            color: _currentSort != ProductSortOption.relevance
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _currentSort.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _currentSort != ProductSortOption.relevance
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF94A3B8)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // FILTER BUTTON (With Badge)
                InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _filterCriteria.activeFilterCount > 0
                          ? const Color(0xFFE0F2FE)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filterCriteria.activeFilterCount > 0
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: _filterCriteria.activeFilterCount > 0
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _filterCriteria.activeFilterCount > 0
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF334155),
                          ),
                        ),
                        if (_filterCriteria.activeFilterCount > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF0284C7),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_filterCriteria.activeFilterCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                if (totalActiveFilters > 0 || _currentSort != ProductSortOption.relevance) ...[
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFFE11D48)),
                    tooltip: 'Reset all filters',
                    onPressed: _resetAllFilters,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 10),

            // 4. Quick Filter Chips Row (Horizontal Scroll)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // In Stock Quick Filter
                  _buildQuickPill(
                    label: '⚡ In Stock',
                    isSelected: _filterCriteria.inStockOnly,
                    onTap: () {
                      setState(() {
                        _filterCriteria = _filterCriteria.copyWith(inStockOnly: !_filterCriteria.inStockOnly);
                      });
                    },
                  ),
                  // Rating 4★+ Quick Filter
                  _buildQuickPill(
                    label: '⭐ 4★ & Above',
                    isSelected: _filterCriteria.minRating == 4.0,
                    onTap: () {
                      setState(() {
                        _filterCriteria = _filterCriteria.copyWith(
                          minRating: _filterCriteria.minRating == 4.0 ? null : 4.0,
                          clearRating: _filterCriteria.minRating == 4.0,
                        );
                      });
                    },
                  ),
                  // Under ₹15k Quick Filter
                  _buildQuickPill(
                    label: '🏷️ Under ₹15k',
                    isSelected: _filterCriteria.maxPrice == 15000,
                    onTap: () {
                      setState(() {
                        if (_filterCriteria.maxPrice == 15000) {
                          _filterCriteria = _filterCriteria.copyWith(maxPrice: 100000);
                        } else {
                          _filterCriteria = _filterCriteria.copyWith(minPrice: 0, maxPrice: 15000);
                        }
                      });
                    },
                  ),
                  // Purchased by me Quick Filter
                  _buildQuickPill(
                    label: '📦 My Purchases',
                    isSelected: _filterCriteria.purchasedOnly,
                    onTap: () {
                      setState(() {
                        _filterCriteria = _filterCriteria.copyWith(purchasedOnly: !_filterCriteria.purchasedOnly);
                      });
                    },
                  ),
                  // Featured Quick Filter
                  _buildQuickPill(
                    label: '🌟 Featured',
                    isSelected: _filterCriteria.featuredOnly,
                    onTap: () {
                      setState(() {
                        _filterCriteria = _filterCriteria.copyWith(featuredOnly: !_filterCriteria.featuredOnly);
                      });
                    },
                  ),
                  // Category quick chips
                  ..._categories.map((cat) {
                    final isSel = _filterCriteria.selectedCategoryId == cat['id'];
                    return _buildQuickPill(
                      label: cat['name'] ?? '',
                      isSelected: isSel,
                      onTap: () {
                        setState(() {
                          if (isSel) {
                            _filterCriteria = _filterCriteria.copyWith(clearCategory: true);
                          } else {
                            _filterCriteria = _filterCriteria.copyWith(
                              selectedCategoryId: cat['id'],
                              selectedCategoryName: cat['name'],
                            );
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),

            // 5. Active Filters Tags (Dismissible)
            if (totalActiveFilters > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (_searchQuery.isNotEmpty)
                    _buildActiveFilterChip('Search: "$_searchQuery"', () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    }),
                  if (_filterCriteria.selectedCategoryName != null)
                    _buildActiveFilterChip('Category: ${_filterCriteria.selectedCategoryName}', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(clearCategory: true));
                    }),
                  if (_filterCriteria.minPrice > 0 || _filterCriteria.maxPrice < 100000)
                    _buildActiveFilterChip('₹${_filterCriteria.minPrice.round()} - ₹${_filterCriteria.maxPrice.round()}', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(minPrice: 0, maxPrice: 100000));
                    }),
                  if (_filterCriteria.minRating != null)
                    _buildActiveFilterChip('Rating: ${_filterCriteria.minRating!.round()}★+', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(clearRating: true));
                    }),
                  if (_filterCriteria.inStockOnly)
                    _buildActiveFilterChip('In Stock Only', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(inStockOnly: false));
                    }),
                  if (_filterCriteria.purchasedOnly)
                    _buildActiveFilterChip('My Purchases Only', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(purchasedOnly: false));
                    }),
                  if (_filterCriteria.featuredOnly)
                    _buildActiveFilterChip('Featured Only', () {
                      setState(() => _filterCriteria = _filterCriteria.copyWith(featuredOnly: false));
                    }),
                  ActionChip(
                    label: const Text('Clear All', style: TextStyle(color: Color(0xFFE11D48), fontSize: 11, fontWeight: FontWeight.bold)),
                    backgroundColor: const Color(0xFFFFE4E6),
                    onPressed: _resetAllFilters,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            // 6. Results Count Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Products (${displayedProducts.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                ),
                Text(
                  _currentSort != ProductSortOption.relevance
                      ? 'Sorted: ${_currentSort.label}'
                      : 'All Catalogs',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 7. Products Grid or Empty State
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (displayedProducts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: const Icon(Icons.search_off_rounded, size: 36, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No products found matching your filters',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try resetting filters or searching with a different term',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _resetAllFilters,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset All Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: displayedProducts.length,
                itemBuilder: (ctx, i) {
                  final p = displayedProducts[i];
                  final price = p['applicablePrice'] ?? 0;
                  final stock = (p['stockQuantity'] as num?)?.toInt() ?? 0;
                  final avgRating = (p['avgRating'] as num?)?.toDouble() ?? 0.0;
                  final reviewCount = (p['reviewCount'] as num?)?.toInt() ?? 0;

                  final mediaList = (p['media'] as List<dynamic>?) ?? [];
                  final imgObj = mediaList.firstWhere(
                    (m) => m['mediaType'] == 'IMAGE',
                    orElse: () => null,
                  );
                  String imgUrl = imgObj?['url'] ?? p['imageUrl'] ?? '';
                  if (imgUrl.startsWith('/uploads/')) {
                    final api = ref.read(apiClientProvider);
                    final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
                    imgUrl = '$base$imgUrl';
                  }

                  final isPurchased = _purchasedProductIds.contains(p['id']);

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    elevation: 0,
                    child: InkWell(
                      onTap: () => context.push('/product-details', extra: p),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => _buildCameraPlaceholder(),
                                            )
                                          : _buildCameraPlaceholder(),
                                    ),
                                  ),
                                  // Stock indicator chip
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stock > 0 ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: stock > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                                        ),
                                      ),
                                      child: Text(
                                        stock > 0 ? 'In Stock' : 'Out of Stock',
                                        style: TextStyle(
                                          color: stock > 0 ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Quick WhatsApp Share Button
                                  Positioned(
                                    top: 6,
                                    left: 6,
                                    child: GestureDetector(
                                      onTap: () {
                                        final api = ref.read(apiClientProvider);
                                        ProductWhatsappShareSheet.show(
                                          context,
                                          product: p,
                                          backendBaseUrl: api.dio.options.baseUrl,
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF25D366),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.share, color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                  // Purchased Badge
                                  if (isPurchased)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade700,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified, size: 10, color: Colors.white),
                                            SizedBox(width: 2),
                                            Text(
                                              'Purchased',
                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Rating stars & reviews count
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: avgRating > 0 ? Colors.amber.shade100 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 11,
                                        color: avgRating > 0 ? Colors.amber.shade800 : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        avgRating > 0 ? avgRating.toStringAsFixed(1) : 'New',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: avgRating > 0 ? Colors.amber.shade900 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (reviewCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '($reviewCount)',
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ],
                              ],
                            ),

                            const SizedBox(height: 4),
                            Text(
                              p['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '₹$price',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                                const Spacer(),
                                if (isPurchased)
                                  InkWell(
                                    onTap: () => context.push('/product-details', extra: p),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.amber.shade300),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rate_rounded, size: 12, color: Colors.amber),
                                          SizedBox(width: 2),
                                          Text(
                                            'Rate',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // ADD TO CART OR QUANTITY STEPPER (+ / -)
                            Builder(
                              builder: (context) {
                                if (stock <= 0) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: FilledButton(
                                      onPressed: null,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.grey.shade300,
                                        disabledBackgroundColor: Colors.grey.shade300,
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                        'Out of Stock',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                      ),
                                    ),
                                  );
                                }

                                final cartQty = cartState.getProductQuantity(p['id']);

                                if (cartQty == 0) {
                                  return SizedBox(
                                    width: double.infinity,
                                    height: 34,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        ref.read(cartProvider.notifier).addItem(p, qty: 1);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('${p['name']} added to cart!'),
                                            duration: const Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.add, size: 14),
                                      label: const Text(
                                        'Add to Cart',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF0284C7),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  );
                                }

                                // Interactive Quantity Stepper (+ and -)
                                return Container(
                                  width: double.infinity,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7),
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                                          onTap: () {
                                            ref.read(cartProvider.notifier).decrementQuantity(p['id']);
                                          },
                                          child: Container(
                                            width: 36,
                                            height: 34,
                                            alignment: Alignment.center,
                                            child: Icon(
                                              cartQty == 1 ? Icons.delete_outline : Icons.remove,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$cartQty',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                                          onTap: cartQty < stock
                                              ? () {
                                                  ref.read(cartProvider.notifier).incrementQuantity(p['id'], product: p);
                                                }
                                              : () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('Max stock limit reached ($stock pcs)'),
                                                      duration: const Duration(seconds: 1),
                                                    ),
                                                  );
                                                },
                                          child: Container(
                                            width: 36,
                                            height: 34,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.add,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF0284C7),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (idx) {
          if (idx == 1) context.push('/cart');
          if (idx == 2) context.push('/quotations');
          if (idx == 3) context.push('/orders');
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.request_quote_outlined), label: 'Quotes'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }

  Widget _buildQuickPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFFE0F2FE),
        backgroundColor: Colors.white,
        checkmarkColor: const Color(0xFF0284C7),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.w500)),
      deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF0284C7)),
      onDeleted: onDeleted,
      backgroundColor: const Color(0xFFE0F2FE),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFBAE6FD)),
      ),
    );
  }

  Widget _buildBannerCarousel() {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _bannerController,
            onPageChanged: (idx) {
              setState(() => _currentBannerPage = idx);
            },
            itemCount: _banners.length,
            itemBuilder: (ctx, i) {
              final b = _banners[i];
              var imgUrl = (b['imageUrl'] ?? '').toString();
              if (imgUrl.startsWith('/')) {
                final api = ref.read(apiClientProvider);
                var base = api.dio.options.baseUrl;
                if (base.endsWith('/api/v1')) base = base.substring(0, base.length - 7);
                imgUrl = '$base$imgUrl';
              }
              final title = (b['title'] ?? '').toString();
              final subtitle = (b['subtitle'] ?? '').toString();
              final action = (b['actionUrl'] ?? '').toString();

              return InkWell(
                onTap: () {
                  if (action.isNotEmpty) {
                    if (action.startsWith('/')) {
                      try {
                        context.push(action);
                      } catch (_) {}
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (imgUrl.isNotEmpty)
                        Image.network(
                          imgUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.water_drop, color: Colors.white24, size: 48),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            ),
                          ),
                        ),
                      // Gradient overlay for readability
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                            ],
                          ),
                        ),
                      ),
                      // Text content
                      Positioned(
                        bottom: 12,
                        left: 14,
                        right: 14,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (idx) {
              final isCurrent = idx == _currentBannerPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 18 : 6,
                height: 5,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
