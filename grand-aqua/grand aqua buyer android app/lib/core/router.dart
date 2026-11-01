import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import '../screens/cart_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/loyalty_screen.dart';
import '../screens/buyer_quotations_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/product_details_screen.dart';
import '../screens/order_detail_screen.dart';

final buyerRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const BuyerLoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/product-details',
      builder: (context, state) => ProductDetailsScreen(
        product: state.extra as Map<String, dynamic>,
      ),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const BuyerNotificationsScreen(),
    ),
    GoRoute(
      path: '/cart',
      builder: (context, state) => const CartScreen(),
    ),
    GoRoute(
      path: '/orders',
      builder: (context, state) => const OrdersScreen(),
    ),
    GoRoute(
      path: '/order-detail',
      builder: (context, state) => OrderDetailScreen(
        order: state.extra as Map<String, dynamic>,
      ),
    ),
    GoRoute(
      path: '/quotations',
      builder: (context, state) => const BuyerQuotationsScreen(),
    ),
    GoRoute(
      path: '/loyalty',
      builder: (context, state) => const LoyaltyScreen(),
    ),
  ],
);

final routerProvider = Provider<GoRouter>((ref) => buyerRouter);
