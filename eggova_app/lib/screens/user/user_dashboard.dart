import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _trayCount = 1;
  int _currentIndex = 0;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _trayController = TextEditingController(text: '1');

  // Order history filters
  String _orderFilterMode = 'all'; // 'all', 'upi', 'cash', 'pending'
  DateTimeRange? _orderFilterDateRange;

  @override
  void initState() {
    super.initState();
    _trayController.addListener(_onTrayTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      orderProvider.fetchCurrentPrice();
      orderProvider.fetchOrders();
      orderProvider.fetchTodayStock();
    });
  }

  @override
  void dispose() {
    _trayController.dispose();
    super.dispose();
  }

  void _onTrayTextChanged() {
    final text = _trayController.text;
    if (text.isEmpty) return; // Allow empty while typing

    final val = int.tryParse(text);
    if (val != null && val != _trayCount) {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final maxAvailable =
          orderProvider.isStockSet ? orderProvider.availableTrays : 1000;

      if (val > maxAvailable) {
        setState(() {
          _trayCount = maxAvailable;
          _trayController.text = maxAvailable.toString();
          _trayController.selection = TextSelection.fromPosition(
              TextPosition(offset: _trayController.text.length));
        });
        _showSnack('Only $maxAvailable trays available today');
      } else if (val < 1) {
        setState(() {
          _trayCount = 1;
        });
      } else {
        setState(() {
          _trayCount = val;
        });
      }
    }
  }

  void _updateTrayCount(int newCount) {
    if (newCount < 1) {
      if (_trayCount != 1) {
        setState(() {
          _trayCount = 1;
          _trayController.text = '1';
        });
      }
      return;
    }

    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final maxAvailable =
        orderProvider.isStockSet ? orderProvider.availableTrays : 1000;

    if (newCount > maxAvailable) {
      _showSnack('Maximum $maxAvailable trays available');
      newCount = maxAvailable;
    }

    setState(() {
      _trayCount = newCount;
      _trayController.text = newCount.toString();
      _trayController.selection = TextSelection.fromPosition(
          TextPosition(offset: _trayController.text.length));
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.amber.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildOrdersTab(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
                color: AppColors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -5)),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.black,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.lightGray,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.egg), label: 'Order'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  // ─── HOME TAB ─────────────────────────────────────────
  Widget _buildHomeTab() {
    final auth = Provider.of<AuthProvider>(context);
    return CustomScrollView(
      slivers: [
        // App bar
        SliverAppBar(
          expandedHeight: 140,
          floating: false,
          pinned: true,
          backgroundColor: AppColors.black,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.black, Color(0xFF2A2A2A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.egg,
                                color: AppColors.black, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Hello, ${auth.user?.name?.split(' ').first ?? 'User'} 👋',
                                    style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.white)),
                                Text('Order fresh eggs today',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: AppColors.lightGray)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.notifications_outlined,
                                color: AppColors.primary, size: 26),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live price card
                _buildPriceCard()
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: 14),

                // Stock availability badge
                Consumer<OrderProvider>(
                  builder: (context, provider, _) {
                    if (!provider.isStockSet) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.amber.shade700, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Stock not set for today. Orders may be unavailable.',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: Colors.amber.shade800),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
                    }
                    final avail = provider.availableTrays;
                    final isOut = avail <= 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isOut
                            ? AppColors.error.withOpacity(0.08)
                            : avail <= 50
                                ? Colors.amber.withOpacity(0.1)
                                : AppColors.success.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isOut
                              ? AppColors.error.withOpacity(0.3)
                              : avail <= 50
                                  ? Colors.amber.withOpacity(0.3)
                                  : AppColors.success.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isOut
                                ? Icons.error_outline
                                : Icons.inventory_2_outlined,
                            color: isOut
                                ? AppColors.error
                                : avail <= 50
                                    ? Colors.amber.shade700
                                    : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isOut
                                  ? 'All stock for today has been sold out!'
                                  : '$avail tray${avail == 1 ? '' : 's'} available today',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isOut
                                    ? AppColors.error
                                    : avail <= 50
                                        ? Colors.amber.shade800
                                        : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
                  },
                ),

                const SizedBox(height: 24),

                // Tray selector
                Text('Select Egg Trays',
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGray)),
                const SizedBox(height: 4),
                Text('Each tray contains 30 eggs',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppColors.gray)),
                const SizedBox(height: 16),
                _buildTraySelector()
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms),

                const SizedBox(height: 24),

                // Order summary
                _buildOrderSummary()
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 500.ms),

                const SizedBox(height: 24),

                // Checkout buttons
                _buildCheckoutButtons()
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 500.ms),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriceCard() {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final price = provider.currentPrice;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            price?.isToday == true
                                ? Icons.check_circle
                                : Icons.warning_amber_rounded,
                            size: 10,
                            color: price?.isToday == true
                                ? AppColors.success
                                : AppColors.error),
                        const SizedBox(width: 6),
                        Text(
                          price?.isToday == true
                              ? "Today's Rate"
                              : 'Price Pending',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkGray),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => provider.fetchCurrentPrice(),
                    icon: const Icon(Icons.refresh,
                        color: AppColors.black, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provider.isLoading)
                const Center(
                    child: CircularProgressIndicator(color: AppColors.black))
              else if (price != null) ...[
                Text(
                  price.isToday == true
                      ? _currencyFormat.format(price.pricePerTray)
                      : "₹--",
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: AppColors.black),
                ),
                Text(
                    price.isToday == true
                        ? 'per tray (${price.district})'
                        : 'Rate will be updated shortly',
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.darkGray)),
                const SizedBox(height: 4),
                if (price.isToday == true)
                  Text('₹${price.pricePerEgg.toStringAsFixed(2)} per egg',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.darkGray.withOpacity(0.7))),
              ] else
                Text('No price available',
                    style: GoogleFonts.outfit(
                        fontSize: 16, color: AppColors.darkGray)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTraySelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: AppColors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Number of Trays',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkGray)),
              Text('${_trayCount * 30} eggs total',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _buildCounterButton(Icons.remove, () {
                  _updateTrayCount(_trayCount - 1);
                }),
                Container(
                  width: 70,
                  alignment: Alignment.center,
                  child: TextField(
                    controller: _trayController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.darkGray),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Consumer<OrderProvider>(
                  builder: (context, provider, _) {
                    return _buildCounterButton(Icons.add, () {
                      _updateTrayCount(_trayCount + 1);
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: AppColors.black, size: 22),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final price = provider.currentPrice;
        final total = (price?.pricePerTray ?? 0) * _trayCount;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            children: [
              _summaryRow('Trays', '$_trayCount'),
              const SizedBox(height: 12),
              _summaryRow(
                  'Price per tray',
                  price != null
                      ? _currencyFormat.format(price.pricePerTray)
                      : '-'),
              const SizedBox(height: 12),
              _summaryRow('Total eggs', '${_trayCount * 30}'),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text('Total Amount',
                        style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGray)),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _currencyFormat.format(total),
                      style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryDark),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkGray),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButtons() {
    return Consumer<OrderProvider>(
      builder: (context, provider, _) {
        final bool isPriceMissing = provider.currentPrice?.isToday != true;
        final bool isStockMissing =
            !provider.isStockSet || provider.availableTrays <= 0;
        final bool isOrderDisabled =
            provider.isLoading || isPriceMissing || isStockMissing;

        String? statusMsg;
        if (!provider.isStockSet) {
          statusMsg = "Today's stock limit has not been set yet.";
        } else if (provider.availableTrays <= 0) {
          statusMsg = "All stock for today has been sold out.";
        } else if (isPriceMissing) {
          statusMsg = "Today's egg rates are not updated yet.";
        }

        return Column(
          children: [
            if (statusMsg != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: AppColors.error),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        statusMsg,
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            // UPI Payment button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isOrderDisabled ? null : () => _placeOrder('upi'),
                icon: const Icon(Icons.payment, size: 22),
                label: Text('Pay with UPI',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  disabledBackgroundColor: AppColors.lightGray.withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Pay Later button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                onPressed:
                    isOrderDisabled ? null : () => _placeOrder('pay_later'),
                icon: const Icon(Icons.schedule, size: 22),
                label: Text('Pay Later',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor:
                      isOrderDisabled ? AppColors.gray : AppColors.darkGray,
                  side: BorderSide(
                      color: isOrderDisabled
                          ? AppColors.lightGray
                          : AppColors.primary,
                      width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _placeOrder(String paymentMethod) async {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    final order = await provider.placeOrder(
      _trayCount,
      paymentMethod,
      userData: {
        'name': auth.user?.name,
        'phone': auth.user?.phone,
        'email': auth.user?.email,
      },
    );

    if (order != null && mounted) {
      if (paymentMethod != 'upi') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order ${order.orderNumber} placed successfully! 🎉',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _trayCount = 1;
          _trayController.text = '1';
          _currentIndex = 1; // Switch to orders tab
        });
      } else {
        // For UPI: Razorpay overlay opens now.
        // Reset tray count AND switch to orders tab (same as cash orders).
        // On success → user sees confirmed order. On cancel → sees cancelled order + error snackbar.
        setState(() {
          _trayCount = 1;
          _trayController.text = '1';
          _currentIndex = 1; // Switch to orders tab
        });

        // Listen on provider to show error snackbar if payment failed/cancelled
        provider.addListener(_onUpiPaymentResult);
      }
    } else if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      provider.clearError();
    }
  }

  // ─── ORDERS TAB ───────────────────────────────────────
  Widget _buildOrdersTab() {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Order History',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
        actions: [
          if (_orderFilterMode != 'all' || _orderFilterDateRange != null)
            TextButton.icon(
              onPressed: () => setState(() {
                _orderFilterMode = 'all';
                _orderFilterDateRange = null;
              }),
              icon: const Icon(Icons.close, size: 14, color: AppColors.error),
              label: Text('Clear',
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.error)),
            ),
        ],
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.orders.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }

          // Apply filters
          final filtered = provider.orders.where((order) {
            // Payment mode filter
            if (_orderFilterMode == 'upi') {
              final via = (order.paidVia ?? order.paymentMethod).toLowerCase();
              if (!via.contains('upi') && !via.contains('razorpay'))
                return false;
            } else if (_orderFilterMode == 'cash') {
              final via = (order.paidVia ?? order.paymentMethod).toLowerCase();
              if (!via.contains('cash')) return false;
            } else if (_orderFilterMode == 'pending') {
              if (order.paymentStatus == 'completed') return false;
            }
            // Date range filter
            if (_orderFilterDateRange != null) {
              final date = order.createdAt;
              if (date.isBefore(_orderFilterDateRange!.start) ||
                  date.isAfter(
                      _orderFilterDateRange!.end.add(const Duration(days: 1))))
                return false;
            }
            return true;
          }).toList();

          return Column(
            children: [
              // ── Filter Card ──
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.darkGray,
                      AppColors.black.withOpacity(0.85)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.15), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.black.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Filter Orders',
                            style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                                letterSpacing: 0.5)),
                        const Spacer(),
                        if (_orderFilterMode != 'all' ||
                            _orderFilterDateRange != null)
                          GestureDetector(
                            onTap: () => setState(() {
                              _orderFilterMode = 'all';
                              _orderFilterDateRange = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close,
                                      size: 11, color: AppColors.error),
                                  const SizedBox(width: 4),
                                  Text('Clear',
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.error)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('All', 'all', _orderFilterMode,
                              (v) => setState(() => _orderFilterMode = v)),
                          const SizedBox(width: 8),
                          _filterChip('UPI', 'upi', _orderFilterMode,
                              (v) => setState(() => _orderFilterMode = v)),
                          const SizedBox(width: 8),
                          _filterChip('Cash', 'cash', _orderFilterMode,
                              (v) => setState(() => _orderFilterMode = v)),
                          const SizedBox(width: 8),
                          _filterChip('Pending', 'pending', _orderFilterMode,
                              (v) => setState(() => _orderFilterMode = v)),
                          const SizedBox(width: 12),
                          // Date range picker
                          GestureDetector(
                            onTap: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                                initialDateRange: _orderFilterDateRange,
                                builder: (context, child) => Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                        primary: AppColors.primary,
                                        onPrimary: AppColors.black,
                                        surface: AppColors.darkGray),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (range != null)
                                setState(() => _orderFilterDateRange = range);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: _orderFilterDateRange != null
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _orderFilterDateRange != null
                                        ? AppColors.primary
                                        : AppColors.gray.withOpacity(0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.date_range_rounded,
                                      size: 14,
                                      color: _orderFilterDateRange != null
                                          ? AppColors.black
                                          : AppColors.lightGray),
                                  const SizedBox(width: 6),
                                  Text(
                                    _orderFilterDateRange != null
                                        ? '${DateFormat('dd MMM').format(_orderFilterDateRange!.start)} – ${DateFormat('dd MMM').format(_orderFilterDateRange!.end)}'
                                        : 'Date Range',
                                    style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _orderFilterDateRange != null
                                            ? AppColors.black
                                            : AppColors.lightGray),
                                  ),
                                  if (_orderFilterDateRange != null) ...[
                                    const SizedBox(width: 6),
                                    GestureDetector(
                                      onTap: () => setState(
                                          () => _orderFilterDateRange = null),
                                      child: Icon(Icons.close,
                                          size: 13, color: AppColors.black),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Orders list
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_list_off,
                                size: 64, color: AppColors.lightGray),
                            const SizedBox(height: 12),
                            Text('No orders match the filter',
                                style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray)),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => setState(() {
                                _orderFilterMode = 'all';
                                _orderFilterDateRange = null;
                              }),
                              child: Text('Clear filters',
                                  style: GoogleFonts.outfit(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.fetchOrders(),
                        color: AppColors.primary,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final order = filtered[index];
                            return _buildOrderCard(order, provider)
                                .animate()
                                .fadeIn(
                                    delay: (index * 80).ms, duration: 400.ms);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip(String label, String value, String currentValue,
      ValueChanged<String> onTap) {
    final isSelected = value == currentValue;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.darkGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.gray.withOpacity(0.4),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.black : AppColors.lightGray,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(dynamic order, OrderProvider provider) {
    Color statusColor;
    IconData statusIcon;
    switch (order.paymentStatus) {
      case 'completed':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        break;
      case 'approval_pending':
        statusColor = AppColors.warning;
        statusIcon = Icons.hourglass_top;
        break;
      default:
        statusColor = AppColors.error;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  order.orderNumber,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkGray),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(order.statusLabel,
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _orderDetail(Icons.egg, '${order.trayCount} Trays'),
              const SizedBox(width: 24),
              _orderDetail(Icons.calendar_today,
                  DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt)),
            ],
          ),
          if (order.paymentStatus == 'completed') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 14, color: AppColors.gray),
                const SizedBox(width: 6),
                Text(order.paymentMethodLabel,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.gray,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  _currencyFormat.format(order.totalAmount),
                  style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (order.paymentStatus == 'pending')
                TextButton.icon(
                  onPressed: () => _showPaymentClaimDialog(order, provider),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text("I've Paid",
                      style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.success),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderDetail(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gray),
        const SizedBox(width: 6),
        Text(text,
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
      ],
    );
  }

  // Listener called after UPI payment result (success or failure)
  void _onUpiPaymentResult() {
    final provider = Provider.of<OrderProvider>(context, listen: false);
    // Only act once the loading is done (payment result is in)
    if (provider.isLoading) return;
    // Remove listener so it only fires once
    provider.removeListener(_onUpiPaymentResult);
    if (provider.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!,
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      provider.clearError();
    }
  }

  void _showPaymentClaimDialog(dynamic order, OrderProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.lightGray,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Confirm Payment',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('How did you pay for ${order.orderNumber}?',
                style: GoogleFonts.outfit(color: AppColors.gray)),
            const SizedBox(height: 24),
            _paymentOptionTile('Cash', Icons.money, () async {
              Navigator.pop(context);
              await provider.requestPaymentCompletion(order.id, 'cash');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Payment request sent to admin!',
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                );
              }
            }),
            const SizedBox(height: 12),
            _paymentOptionTile('UPI', Icons.payment, () async {
              Navigator.pop(context);
              await provider.requestPaymentCompletion(order.id, 'upi_direct');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Payment request sent to admin!',
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                );
              }
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _paymentOptionTile(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.offWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightGray.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 16),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios,
                size: 16, color: AppColors.gray),
          ],
        ),
      ),
    );
  }

  // ─── PROFILE TAB ──────────────────────────────────────
  Widget _buildProfileTab() {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.3), blurRadius: 15)
                ],
              ),
              child: Center(
                child: Text(
                  user?.name.isNotEmpty == true
                      ? user!.name[0].toUpperCase()
                      : 'U',
                  style: GoogleFonts.outfit(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: AppColors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(user?.name ?? '',
                style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkGray)),
            Text(user?.district ?? '',
                style: GoogleFonts.outfit(fontSize: 14, color: AppColors.gray)),
            const SizedBox(height: 28),

            _profileInfoCard(user),

            const SizedBox(height: 20),

            // Edit Profile
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.pushNamed(context, '/edit-profile');
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: Text('Edit Profile',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (mounted)
                    Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout, size: 20),
                label: Text('Logout',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileInfoCard(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)
        ],
      ),
      child: Column(
        children: [
          _profileRow(Icons.email_outlined, 'Email', user?.email ?? ''),
          const Divider(height: 24),
          _profileRow(Icons.phone_outlined, 'Phone', user?.phone ?? ''),
          const Divider(height: 24),
          _profileRow(
              Icons.home_outlined, 'Address', user?.address ?? 'Not set'),
          const Divider(height: 24),
          _profileRow(
              Icons.location_on_outlined, 'District', user?.district ?? ''),
          if (user?.pincode != null && user.pincode.isNotEmpty) ...[
            const Divider(height: 24),
            _profileRow(Icons.pin_drop_outlined, 'Pincode', user.pincode),
          ],
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: AppColors.primaryDark, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
              Text(value,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkGray)),
            ],
          ),
        ),
      ],
    );
  }
}
