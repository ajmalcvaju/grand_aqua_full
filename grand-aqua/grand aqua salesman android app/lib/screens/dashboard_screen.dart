import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/auth_provider.dart';

class SalesmanDashboardScreen extends ConsumerStatefulWidget {
  const SalesmanDashboardScreen({super.key});

  @override
  ConsumerState<SalesmanDashboardScreen> createState() => _SalesmanDashboardScreenState();
}

class _SalesmanDashboardScreenState extends ConsumerState<SalesmanDashboardScreen> {
  Map<String, dynamic>? _performance;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/salesmen/my-performance');
      setState(() {
        _performance = res.data['data'] ?? res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _resolveImageUrl(dynamic url) {
    if (url == null) return '';
    final clean = url.toString().trim();
    if (clean.isEmpty) return '';
    if (clean.startsWith('http://') || clean.startsWith('https://')) return clean;
    final api = ref.read(apiClientProvider);
    final base = api.dio.options.baseUrl.replaceAll('/api/v1', '');
    return clean.startsWith('/') ? '$base$clean' : '$base/$clean';
  }

  @override
  Widget build(BuildContext context) {
    final salesman = _performance?['salesman'] ?? {};
    final metrics = _performance?['metrics'] ?? {};
    final incentives = metrics['incentives'] ?? {};
    final photoUrl = _resolveImageUrl(salesman['profilePhoto'] ?? salesman['imageUrl']);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? Text(
                      (salesman['name'] != null && (salesman['name'] as String).isNotEmpty)
                          ? (salesman['name'] as String).substring(0, 1).toUpperCase()
                          : 'S',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salesman['name'] ?? 'Sales Executive',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('Territory: ${salesman['territory'] ?? 'Local'}',
                      style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPerformance,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchPerformance,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Target Progress Banner
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Monthly Target Progress',
                            style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(
                          '${metrics['targetAchievementPercent'] ?? 0}% Achieved',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ((metrics['targetAchievementPercent'] ?? 0) / 100.0).clamp(0.0, 1.0),
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Net Sales: ₹${metrics['totalSalesValue'] ?? 0} / ₹${salesman['monthlyTarget'] ?? 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Assigned Shops',
                          '${metrics['assignedShopsCount'] ?? 0}',
                          Icons.storefront,
                          Colors.teal,
                          onTap: () => context.push('/shops'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          'Conversion Rate',
                          '${metrics['conversionRate'] ?? 0}%',
                          Icons.trending_up,
                          Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          'Quotations',
                          '${metrics['totalQuotations'] ?? 0}',
                          Icons.request_quote,
                          Colors.indigo,
                          onTap: () => context.push('/quotations'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricTile(
                          'Incentives',
                          '₹${incentives['totalEarned'] ?? 0}',
                          Icons.card_giftcard,
                          Colors.green,
                          onTap: () => context.push('/incentives'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text('Field Operations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 12),

                  _buildActionCard(
                    'Dealer Orders & GST Invoices',
                    'Track dealer orders, dispatch status & download GST Invoices',
                    Icons.inventory_2_outlined,
                    () => context.push('/orders'),
                  ),
                  _buildActionCard(
                    'My Quotations & PDFs',
                    'View issued proposals, line items & download PDF',
                    Icons.request_quote,
                    () => context.push('/quotations'),
                  ),
                  _buildActionCard(
                    'Prepare Trade Quotation',
                    'Create quote with buyer category pricing snapshot',
                    Icons.add_shopping_cart,
                    () => context.push('/quotation-builder'),
                  ),
                  _buildActionCard(
                    'My Assigned Shops',
                    'Dealer ledger, credit limits & shop details',
                    Icons.store,
                    () => context.push('/shops'),
                  ),
                  _buildActionCard(
                    'Incentive Ledger',
                    '3% provisional commission on delivered orders',
                    Icons.monetization_on_outlined,
                    () => context.push('/incentives'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricTile(String title, String value, IconData icon, MaterialColor color, {VoidCallback? onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                Icon(icon, color: color, size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.1),
          child: Icon(icon, color: const Color(0xFF0D9488)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
