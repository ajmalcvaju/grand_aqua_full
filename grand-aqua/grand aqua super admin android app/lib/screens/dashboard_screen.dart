import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../core/auth_provider.dart';
import '../widgets/admin_drawer.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/reports/dashboard');
      setState(() {
        _dashboardData = res.data['data'] ?? res.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final overview = _dashboardData?['overview'] ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Grand Aqua Admin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Enterprise Mobile Portal', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      drawer: const AdminDrawer(currentRoute: '/dashboard'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchDashboard,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // KPI Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Total Sales',
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format((overview['totalSales'] ?? 0) as num),
                          Icons.trending_up,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Collected',
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format((overview['paymentsCollected'] ?? 0) as num),
                          Icons.check_circle_outline,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Receivables',
                          NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format((overview['outstandingReceivables'] ?? 0) as num),
                          Icons.hourglass_top,
                          Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Total Buyers',
                          '${overview['totalBuyers'] ?? 0} Accounts',
                          Icons.people_alt_outlined,
                          Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          'Fulfillment Orders',
                          '${overview['totalOrders'] ?? 0} Active',
                          Icons.local_shipping_outlined,
                          Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildMetricCard(
                          'Pending Quotes',
                          '${overview['quotationsPendingApproval'] ?? 0} Pending',
                          Icons.request_quote_outlined,
                          Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),

                  // Trade Credit Live Exposure Banner
                  if (overview['credit'] != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('TRADE CREDIT EXPOSURE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                              Icon(Icons.shield_outlined, color: Colors.white70, size: 16),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Credit In Use', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text(
                                    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format((overview['credit']['utilized'] ?? 0) as num),
                                    style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Available Line', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  Text(
                                    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0).format((overview['credit']['available'] ?? 0) as num),
                                    style: const TextStyle(color: Color(0xFFBBF7D0), fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'monospace'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Text(
                    'Operational Modules',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),

                  _buildNavTile(
                    'Product Management',
                    'CRUD, Image/Video/3D View & 4-Tier Pricing',
                    Icons.inventory_2,
                    () => context.push('/products'),
                  ),
                  _buildNavTile(
                    'Category Management',
                    'Catalog Hierarchy, Classification & Category CRUD',
                    Icons.category,
                    () => context.push('/categories'),
                  ),
                  _buildNavTile(
                    'Buyer Management',
                    'Owner/Shop Photos, Dues, Purchase History & Tiers',
                    Icons.people,
                    () => context.push('/buyers'),
                  ),
                  _buildNavTile(
                    'Credit Management',
                    'Trade Credit Limits, Utilization & Payment Cycles',
                    Icons.credit_card,
                    () => context.push('/credit'),
                  ),
                  _buildNavTile(
                    'Salesman Management',
                    'CRUD, Assigned Buyers, Sales History & Block Access',
                    Icons.badge,
                    () => context.push('/salesmen'),
                  ),
                  _buildNavTile(
                    'Quotations & Approvals',
                    'Commercial discount approval & PDF invoices',
                    Icons.request_quote,
                    () => context.push('/quotations'),
                  ),
                  _buildNavTile(
                    'Order Management',
                    'Live fulfillment, dispatch docket & delivery history',
                    Icons.local_shipping,
                    () => context.push('/orders'),
                  ),
                  _buildNavTile(
                    'Payments & Receivables',
                    'Record Settlements, Reconcile Dues & Track Receipts',
                    Icons.payments,
                    () => context.push('/payments'),
                  ),
                  _buildNavTile(
                    'Settings & Admin Roles',
                    'Enterprise Profile, 18% GSTIN & Staff Permissions',
                    Icons.settings,
                    () => context.push('/settings'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildNavTile(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0284C7).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF0284C7)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
