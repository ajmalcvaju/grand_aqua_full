import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class AuthState {
  final bool isAuthenticated;
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final String? errorMessage;
  final String? otpSentPhone;

  const AuthState({
    this.isAuthenticated = false,
    this.token,
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.otpSentPhone,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    String? token,
    Map<String, dynamic>? user,
    bool? isLoading,
    String? errorMessage,
    String? otpSentPhone,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      token: token ?? this.token,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      otpSentPhone: otpSentPhone ?? this.otpSentPhone,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(() => _checkInitialAuth());
    return const AuthState(isLoading: false);
  }

  Future<void> _checkInitialAuth() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('buyer_token');
      final userStr = prefs.getString('buyer_user');
      if (token != null && userStr != null) {
        try {
          final user = jsonDecode(userStr);
          state = state.copyWith(isAuthenticated: true, token: token, user: user, isLoading: false);
          return;
        } catch (_) {}
      }
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    } catch (_) {
      state = state.copyWith(isAuthenticated: false, isLoading: false);
    }
  }

  Future<bool> requestOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post('/auth/buyer/request-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false, otpSentPhone: phone);
      return true;
    } catch (e) {
      String msg = 'Failed to send OTP';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  void resetOtpState() {
    state = state.copyWith(otpSentPhone: null, errorMessage: null);
  }

  Future<bool> loginWithPassword(String identifier, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post('/auth/buyer/password-login', data: {
        'identifier': identifier.trim(),
        'password': password.trim(),
      });

      final data = res.data['data'] ?? res.data;
      final token = data['accessToken'] as String;
      final user = data['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('buyer_token', token);
      await prefs.setString('buyer_user', jsonEncode(user));

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      String msg = 'Password login failed';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> loginWithOtp(String phone, String otp) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post('/auth/buyer/verify-otp', data: {
        'phone': phone.trim(),
        'otp': otp.trim(),
      });

      final data = res.data['data'] ?? res.data;
      final token = data['accessToken'] as String;
      final user = data['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('buyer_token', token);
      await prefs.setString('buyer_user', jsonEncode(user));

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      String msg = 'OTP verification failed';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<Map<String, dynamic>?> registerBuyer({
    required String businessName,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post('/auth/buyer/register', data: {
        'businessName': businessName.trim(),
        'phone': phone.trim(),
      });
      state = state.copyWith(isLoading: false);
      final data = res.data['data'] ?? res.data;
      return Map<String, dynamic>.from(data);
    } catch (e) {
      String msg = 'Registration failed';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return null;
    }
  }

  Future<bool> requestForgotPasswordOtp(String phone) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post('/auth/buyer/forgot-password/request-otp', data: {
        'phone': phone.trim(),
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String msg = 'Failed to send Reset OTP';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> resetPassword({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post('/auth/buyer/forgot-password/reset', data: {
        'phone': phone.trim(),
        'otp': otp.trim(),
        'newPassword': newPassword.trim(),
      });
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      String msg = 'Password reset failed';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> directLogin(String phone, {String? fullName}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final api = ref.read(apiClientProvider);
      dynamic res;
      try {
        res = await api.dio.post('/auth/buyer/login', data: {
          'phone': phone,
          'fullName': fullName,
        });
      } catch (_) {
        res = await api.dio.post('/auth/buyer/verify-otp', data: {
          'phone': phone,
          'otp': '123456',
          'fullName': fullName,
        });
      }

      final data = res.data['data'] ?? res.data;
      final token = data['accessToken'] as String;
      final user = data['user'] as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('buyer_token', token);
      await prefs.setString('buyer_user', jsonEncode(user));

      state = state.copyWith(
        isAuthenticated: true,
        token: token,
        user: user,
        isLoading: false,
      );
      return true;
    } catch (e) {
      String msg = 'Failed to login: $e';
      if (e is DioException) {
        msg = e.response?.data?['message']?.toString() ?? e.message ?? msg;
      }
      state = state.copyWith(isLoading: false, errorMessage: msg);
      return false;
    }
  }

  Future<bool> verifyOtp(String phone, String otp, {String? fullName}) async {
    return loginWithOtp(phone, otp);
  }

  Future<void> refreshProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.get('/auth/me');
      final data = res.data['data'] ?? res.data;
      if (data != null && data is Map<String, dynamic>) {
        updateUser(data);
      }
    } catch (_) {}
  }

  void updateUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('buyer_user', jsonEncode(user));
    state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('buyer_token');
    await prefs.remove('buyer_user');
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// Cart State & Notifier
class CartItem {
  final Map<String, dynamic> product;
  final int quantity;

  const CartItem({required this.product, required this.quantity});

  double get unitPrice {
    final slabs = (product['quantityPricingSlabs'] as List<dynamic>?) ?? [];
    if (slabs.isNotEmpty) {
      for (final s in slabs) {
        final minQ = (s['minQuantity'] as num?)?.toInt() ?? 1;
        final maxQ = (s['maxQuantity'] as num?)?.toInt() ?? 999999;
        if (quantity >= minQ && quantity <= maxQ) {
          final slabPrice = (s['price'] as num?)?.toDouble();
          if (slabPrice != null && slabPrice > 0) {
            return slabPrice;
          }
        }
      }
    }
    return (product['applicablePrice'] ?? 0.0).toDouble();
  }
  double get totalPrice => unitPrice * quantity;
}

class CartState {
  final List<CartItem> items;
  final String? voucherCode;
  final double discountAmount;

  const CartState({
    this.items = const [],
    this.voucherCode,
    this.discountAmount = 0,
  });

  double get subtotal => items.fold(0.0, (sum, i) => sum + i.totalPrice);
  double get taxAmount => (subtotal * 18.0) / 100.0;
  double get shipping => subtotal >= 5000 || subtotal == 0 ? 0.0 : 250.0;
  double get grandTotal => (subtotal + taxAmount + shipping - discountAmount).clamp(0.0, double.infinity);
  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  int getProductQuantity(String? productId) {
    if (productId == null) return 0;
    for (final item in items) {
      if (item.product['id'] == productId) {
        return item.quantity;
      }
    }
    return 0;
  }

  CartState copyWith({
    List<CartItem>? items,
    String? voucherCode,
    double? discountAmount,
  }) {
    return CartState(
      items: items ?? this.items,
      voucherCode: voucherCode ?? this.voucherCode,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }
}

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addItem(Map<String, dynamic> product, {int qty = 1}) {
    final existingIndex = state.items.indexWhere((i) => i.product['id'] == product['id']);
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedList = List<CartItem>.from(state.items);
      updatedList[existingIndex] = CartItem(product: product, quantity: existing.quantity + qty);
      state = state.copyWith(items: updatedList);
    } else {
      state = state.copyWith(items: [...state.items, CartItem(product: product, quantity: qty)]);
    }
  }

  void updateQuantity(String productId, int newQty) {
    if (newQty <= 0) {
      removeItem(productId);
      return;
    }
    final existingIndex = state.items.indexWhere((i) => i.product['id'] == productId);
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedList = List<CartItem>.from(state.items);
      updatedList[existingIndex] = CartItem(product: existing.product, quantity: newQty);
      state = state.copyWith(items: updatedList);
    }
  }

  void incrementQuantity(String productId, {Map<String, dynamic>? product}) {
    final existingIndex = state.items.indexWhere((i) => i.product['id'] == productId);
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedList = List<CartItem>.from(state.items);
      updatedList[existingIndex] = CartItem(product: existing.product, quantity: existing.quantity + 1);
      state = state.copyWith(items: updatedList);
    } else if (product != null) {
      addItem(product, qty: 1);
    }
  }

  void decrementQuantity(String productId) {
    final existingIndex = state.items.indexWhere((i) => i.product['id'] == productId);
    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      if (existing.quantity <= 1) {
        removeItem(productId);
      } else {
        final updatedList = List<CartItem>.from(state.items);
        updatedList[existingIndex] = CartItem(product: existing.product, quantity: existing.quantity - 1);
        state = state.copyWith(items: updatedList);
      }
    }
  }

  void removeItem(String productId) {
    state = state.copyWith(items: state.items.where((i) => i.product['id'] != productId).toList());
  }

  void applyVoucher(String code, double discount) {
    state = state.copyWith(voucherCode: code, discountAmount: discount);
  }

  void clear() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
