import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/district_data.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../models/user.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  late TabController _paymentTabController;
  late TabController _userTabController;

  // User Search state
  String _userSearchQuery = '';
  final _userSearchController = TextEditingController();

  // Settings tab state
  String? _selectedDistrict;
  String? _selectedTrendDistrict;
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  bool _isSettingPrice = false;
  bool _isSettingStock = false;

  // Payment filters
  String _paymentSearchQuery = '';
  final _paymentSearchController = TextEditingController();
  String _completedFilterMode = 'all'; // 'all', 'upi', 'cash'
  DateTimeRange? _completedFilterDate;
  DateTimeRange? _pendingFilterDate;

  @override
  void initState() {
    super.initState();
    _paymentTabController = TabController(length: 2, vsync: this);
    _userTabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchDashboardStats();
      admin.fetchUsers();
      admin.fetchPendingUsers();
      admin.fetchPendingPhoneUsers();
      admin.fetchPendingPayments();
      admin.fetchCompletedPayments();
      admin.fetchTodayPrices();
      admin.fetchTodayStock();
    });
  }

  @override
  @override
  void dispose() {
    _paymentTabController.dispose();
    _paymentSearchController.dispose();
    _userTabController.dispose();
    _userSearchController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildOverviewTab(),
          _buildEggRatesTab(),
          _buildPaymentsTab(),
          _buildUsersTab(),
          _buildSettingsTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.black,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.lightGray,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
              BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: 'Rates'),
              BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payments'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  // ─── OVERVIEW TAB ─────────────────────────────────────
  Widget _buildOverviewTab() {
    final auth = Provider.of<AuthProvider>(context);
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.black,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.black, Color(0xFF2A2A2A)]),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.admin_panel_settings, color: AppColors.black, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Admin Panel', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                            Text('Welcome, ${auth.user?.name ?? 'Admin'}', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.lightGray)),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_outlined, color: AppColors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Consumer<AdminProvider>(
            builder: (context, admin, _) {
              final stats = admin.dashboardStats;
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats grid
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 2.2,
                      children: [
                        _statCard('Total Users', '${stats['totalUsers'] ?? 0}', Icons.people, AppColors.info)
                            .animate().fadeIn(duration: 400.ms),
                        _statCard('Total Orders', '${stats['totalOrders'] ?? 0}', Icons.shopping_bag, AppColors.primaryDark)
                            .animate().fadeIn(delay: 100.ms, duration: 400.ms),
                        _statCard('Pending', '${stats['pendingPayments'] ?? 0}', Icons.pending_actions, AppColors.warning)
                            .animate().fadeIn(delay: 200.ms, duration: 400.ms),
                        _statCard('Completed', '${stats['completedPayments'] ?? 0}', Icons.check_circle, AppColors.success)
                            .animate().fadeIn(delay: 300.ms, duration: 400.ms),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Revenue cards
                    _revenueCard(
                      'Total Revenue',
                      _currencyFormat.format(stats['totalRevenue'] ?? 0),
                      Icons.trending_up,
                      AppColors.success,
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                    const SizedBox(height: 14),
                    _revenueCard(
                      'Pending Amount',
                      _currencyFormat.format(stats['pendingAmount'] ?? 0),
                      Icons.hourglass_top,
                      AppColors.warning,
                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                    const SizedBox(height: 24),

                    // Offline Order Section
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.black, Color(0xFF1A1A1A)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                                child: const Icon(Icons.storefront, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text('Offline Orders', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.white)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Record sales for customers visiting the farm who do not use the app.', 
                            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.lightGray.withOpacity(0.8))),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _showOfflineOrderDialog(),
                              icon: const Icon(Icons.add_shopping_cart, size: 20),
                              label: Text('Record Manual Order', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.black,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutQuad).fadeIn(),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
                ),
                Text(label, style: GoogleFonts.outfit(fontSize: 10, color: AppColors.gray), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _revenueCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
                Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── PAYMENTS TAB ─────────────────────────────────────
  Widget _buildPaymentsTab() {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: _buildPaymentSearchBar(),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
        bottom: TabBar(
          controller: _paymentTabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.lightGray,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _paymentTabController,
        children: [
          _buildPendingPaymentsList(),
          _buildCompletedPaymentsList(),
        ],
      ),
    );
  }

  Widget _buildPaymentSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _paymentSearchController,
        style: GoogleFonts.outfit(color: AppColors.black, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Search orders by name or phone...',
          hintStyle: GoogleFonts.outfit(color: AppColors.gray),
          prefixIcon: const Icon(Icons.search, color: AppColors.gray, size: 20),
          suffixIcon: _paymentSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.gray, size: 20),
                  onPressed: () {
                    _paymentSearchController.clear();
                    setState(() => _paymentSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onChanged: (val) {
          setState(() => _paymentSearchQuery = val);
        },
      ),
    );
  }

  Widget _buildPendingPaymentsList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        if (admin.isLoading && admin.pendingPayments.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final filtered = admin.pendingPayments.where((order) {
          // Text search filter
          if (_paymentSearchQuery.isNotEmpty) {
            final query = _paymentSearchQuery.toLowerCase();
            final userName = (order.isOffline ? order.customerName : order.user?.name)?.toLowerCase() ?? '';
            final userPhone = (order.isOffline ? order.customerPhone : order.user?.phone) ?? '';
            if (!userName.contains(query) && !userPhone.contains(query)) {
              return false;
            }
          }

          if (_pendingFilterDate != null) {
            final date = order.createdAt;
            if (date.isBefore(_pendingFilterDate!.start) ||
                date.isAfter(_pendingFilterDate!.end.add(const Duration(days: 1)))) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // ── Pending Filter Card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkGray, AppColors.black.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Filter by Date', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
                      const Spacer(),
                      if (_pendingFilterDate != null)
                        GestureDetector(
                          onTap: () => setState(() => _pendingFilterDate = null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, size: 11, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text('Clear', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                        initialDateRange: _pendingFilterDate,
                        builder: (ctx, child) => Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: AppColors.black, surface: AppColors.darkGray),
                          ),
                          child: child!,
                        ),
                      );
                      if (range != null) setState(() => _pendingFilterDate = range);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: _pendingFilterDate != null ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _pendingFilterDate != null ? AppColors.primary : AppColors.gray.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.date_range_rounded, size: 14, color: _pendingFilterDate != null ? AppColors.black : AppColors.lightGray),
                          const SizedBox(width: 6),
                          Text(
                            _pendingFilterDate != null
                                ? '${DateFormat('dd MMM').format(_pendingFilterDate!.start)} – ${DateFormat('dd MMM').format(_pendingFilterDate!.end)}'
                                : 'Select Date Range',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _pendingFilterDate != null ? AppColors.black : AppColors.lightGray),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(admin.pendingPayments.isEmpty
                              ? Icons.check_circle_outline
                              : Icons.filter_list_off,
                            size: 80, color: AppColors.success.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          Text(
                            admin.pendingPayments.isEmpty ? 'No pending payments!' : 'No payments match the filter',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray),
                          ),
                          if (_pendingFilterDate != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => setState(() => _pendingFilterDate = null),
                              child: Text('Clear filter', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => admin.fetchPendingPayments(),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          return _buildAdminPaymentCard(order, isPending: true)
                              .animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletedPaymentsList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        if (admin.isLoading && admin.completedPayments.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final filtered = admin.completedPayments.where((order) {
          // Text search filter
          if (_paymentSearchQuery.isNotEmpty) {
            final query = _paymentSearchQuery.toLowerCase();
            final userName = (order.isOffline ? order.customerName : order.user?.name)?.toLowerCase() ?? '';
            final userPhone = (order.isOffline ? order.customerPhone : order.user?.phone) ?? '';
            if (!userName.contains(query) && !userPhone.contains(query)) {
              return false;
            }
          }

          // Payment mode filter
          if (_completedFilterMode == 'upi') {
            final via = (order.paidVia ?? order.paymentMethod ?? '').toLowerCase();
            if (!via.contains('upi') && !via.contains('razorpay')) return false;
          } else if (_completedFilterMode == 'cash') {
            final via = (order.paidVia ?? order.paymentMethod ?? '').toLowerCase();
            if (!via.contains('cash')) return false;
          }
          // Date filter
          if (_completedFilterDate != null) {
            final date = order.paidAt ?? order.createdAt;
            if (date.isBefore(_completedFilterDate!.start) ||
                date.isAfter(_completedFilterDate!.end.add(const Duration(days: 1)))) return false;
          }
          return true;
        }).toList();

        return Column(
          children: [
            // ── Completed Filter Card ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.darkGray, AppColors.black.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
                boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Filter Payments', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5)),
                      const Spacer(),
                      if (_completedFilterMode != 'all' || _completedFilterDate != null)
                        GestureDetector(
                          onTap: () => setState(() { _completedFilterMode = 'all'; _completedFilterDate = null; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, size: 11, color: AppColors.error),
                                const SizedBox(width: 4),
                                Text('Clear', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.error)),
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
                        _adminPayModeChip('All', 'all'),
                        const SizedBox(width: 8),
                        _adminPayModeChip('UPI', 'upi'),
                        const SizedBox(width: 8),
                        _adminPayModeChip('Cash', 'cash'),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            final range = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2024),
                              lastDate: DateTime.now(),
                              initialDateRange: _completedFilterDate,
                              builder: (ctx, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(primary: AppColors.primary, onPrimary: AppColors.black, surface: AppColors.darkGray),
                                ),
                                child: child!,
                              ),
                            );
                            if (range != null) setState(() => _completedFilterDate = range);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: _completedFilterDate != null ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _completedFilterDate != null ? AppColors.primary : AppColors.gray.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.date_range_rounded, size: 14, color: _completedFilterDate != null ? AppColors.black : AppColors.lightGray),
                                const SizedBox(width: 6),
                                Text(
                                  _completedFilterDate != null
                                      ? '${DateFormat('dd MMM').format(_completedFilterDate!.start)} – ${DateFormat('dd MMM').format(_completedFilterDate!.end)}'
                                      : 'Date Range',
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _completedFilterDate != null ? AppColors.black : AppColors.lightGray),
                                ),
                                if (_completedFilterDate != null) ...[
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () => setState(() => _completedFilterDate = null),
                                    child: Icon(Icons.close, size: 13, color: AppColors.black),
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
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(admin.completedPayments.isEmpty
                              ? Icons.history
                              : Icons.filter_list_off,
                            size: 80, color: AppColors.lightGray),
                          const SizedBox(height: 16),
                          Text(
                            admin.completedPayments.isEmpty ? 'No completed payments yet' : 'No payments match the filter',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray),
                          ),
                          if (_completedFilterMode != 'all' || _completedFilterDate != null) ...[
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () => setState(() {
                                _completedFilterMode = 'all';
                                _completedFilterDate = null;
                              }),
                              child: Text('Clear filters', style: GoogleFonts.outfit(color: AppColors.primary, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => admin.fetchCompletedPayments(),
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          return _buildAdminPaymentCard(order, isPending: false)
                              .animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _adminPayModeChip(String label, String value) {
    final isSelected = value == _completedFilterMode;
    return GestureDetector(
      onTap: () => setState(() => _completedFilterMode = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.darkGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.gray.withOpacity(0.4)),
        ),
        child: Text(label, style: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: isSelected ? AppColors.black : AppColors.lightGray,
        )),
      ),
    );
  }

  Widget _adminFilterDateBtn(DateTimeRange? range, {required VoidCallback onTap, required VoidCallback onClear}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: range != null ? AppColors.primary : AppColors.darkGray,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: range != null ? AppColors.primary : AppColors.gray.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 13, color: range != null ? AppColors.black : AppColors.lightGray),
            const SizedBox(width: 6),
            Text(
              range != null
                  ? '${DateFormat('dd MMM').format(range.start)} – ${DateFormat('dd MMM').format(range.end)}'
                  : 'Date Range',
              style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: range != null ? AppColors.black : AppColors.lightGray,
              ),
            ),
            if (range != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 13, color: AppColors.black),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAdminPaymentCard(dynamic order, {required bool isPending}) {
    final user = order.user;
    final admin = Provider.of<AdminProvider>(context, listen: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        border: order.isApprovalPending
            ? Border.all(color: AppColors.warning, width: 1.5)
            : null,
      ),
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
                      order.isOffline ? (order.customerName ?? 'Farm Visitor') : (user?.name ?? 'Unknown'), 
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkGray)
                    ),
                    const SizedBox(height: 2),
                    Text(
                      order.isOffline ? (order.customerPhone ?? '') : (user?.phone ?? ''), 
                      style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)
                    ),
                  ],
                ),
              ),
              if (order.isOffline)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('OFFLINE', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                )
              else if (order.isApprovalPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('Approval Needed', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Order details — Wrap so chips flow on narrow screens
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _detailChip(Icons.egg, '${order.trayCount} trays'),
              _detailChip(Icons.calendar_today, DateFormat('dd MMM, hh:mm a').format(order.createdAt)),
            ],
          ),

          const SizedBox(height: 14),

          // Amount + actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _currencyFormat.format(order.totalAmount),
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: isPending ? AppColors.error : AppColors.success),
              ),
              if (isPending)
                Row(
                  children: [
                    if (order.isApprovalPending)
                      _actionButton('Approve', AppColors.success, Icons.check, () async {
                        final ok = await admin.approvePayment(order.id);
                        if (ok && mounted) _showSnack('Payment approved! ✅');
                      }),
                    const SizedBox(width: 8),
                    _actionButton('Mark Paid', AppColors.info, Icons.paid, () {
                      _showMarkPaidDialog(order, admin);
                    }),
                  ],
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Paid via ${order.paidVia ?? 'N/A'}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.offWhite,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.gray),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.outfit(fontSize: 11, color: AppColors.gray, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _actionButton(String label, Color color, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.white),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.white)),
          ],
        ),
      ),
    );
  }

  void _showMarkPaidDialog(dynamic order, AdminProvider admin) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.lightGray, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Mark Payment Complete', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('How was ${order.orderNumber} paid?', style: GoogleFonts.outfit(color: AppColors.gray)),
            const SizedBox(height: 24),
            _payOptionTile('Cash', Icons.money, () async {
              Navigator.pop(ctx);
              final ok = await admin.markPaymentPaid(order.id, 'cash');
              if (ok && mounted) _showSnack('Marked as paid via Cash ✅');
            }),
            const SizedBox(height: 12),
            _payOptionTile('UPI', Icons.payment, () async {
              Navigator.pop(ctx);
              final ok = await admin.markPaymentPaid(order.id, 'upi_direct');
              if (ok && mounted) _showSnack('Marked as paid via UPI ✅');
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _payOptionTile(String label, IconData icon, VoidCallback onTap) {
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
              width: 44, height: 44,
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.primaryDark),
            ),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray),
          ],
        ),
      ),
    );
  }

  // ─── USERS TAB ────────────────────────────────────────
  Widget _buildUsersTab() {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: _buildUserSearchBar(),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
        bottom: TabBar(
          controller: _userTabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.gray,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Pending Auth'),
            Tab(text: 'Phone Updates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _userTabController,
        children: [
          _buildActiveUsersList(),
          _buildPendingUsersList(),
          _buildPendingPhoneUsersList(),
        ],
      ),
    );
  }

  Widget _buildUserSearchBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _userSearchController,
        style: GoogleFonts.outfit(color: AppColors.black, fontSize: 14),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Search by name or phone...',
          hintStyle: GoogleFonts.outfit(color: AppColors.gray),
          prefixIcon: const Icon(Icons.search, color: AppColors.gray, size: 20),
          suffixIcon: _userSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppColors.gray, size: 20),
                  onPressed: () {
                    _userSearchController.clear();
                    setState(() => _userSearchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        onChanged: (val) {
          setState(() => _userSearchQuery = val);
        },
      ),
    );
  }

  Widget _buildActiveUsersList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        final filteredList = admin.users.where((u) {
          final query = _userSearchQuery.toLowerCase();
          return u.name.toLowerCase().contains(query) || u.phone.contains(query);
        }).toList();

        if (admin.isLoading && admin.users.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (filteredList.isEmpty) {
          return _emptyPlaceholder('No active users found', Icons.people_outline);
        }
        return RefreshIndicator(
          onRefresh: () => admin.fetchUsers(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final user = filteredList[index];
              return _buildUserCard(user).animate().fadeIn(delay: (index * 50).ms);
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingUsersList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        final filteredList = admin.pendingUsers.where((u) {
          final query = _userSearchQuery.toLowerCase();
          return u.name.toLowerCase().contains(query) || u.phone.contains(query);
        }).toList();

        if (admin.isLoading && admin.pendingUsers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (filteredList.isEmpty) {
          return _emptyPlaceholder('No pending approvals found', Icons.fact_check_outlined);
        }
        return RefreshIndicator(
          onRefresh: () => admin.fetchPendingUsers(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final user = filteredList[index];
              return _buildPendingUserCard(user, admin).animate().fadeIn(delay: (index * 50).ms);
            },
          ),
        );
      },
    );
  }

  Widget _emptyPlaceholder(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.gray.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(text, style: GoogleFonts.outfit(color: AppColors.gray, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnack('Could not launch dialer');
    }
  }

  Widget _buildPendingUserCard(UserModel user, AdminProvider admin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Text(user.phone, style: GoogleFonts.outfit(color: AppColors.gray, fontSize: 14)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _makePhoneCall(user.phone),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.call, size: 14, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('PENDING', style: GoogleFonts.outfit(color: Colors.amber[800], fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.gray),
              const SizedBox(width: 4),
              Text(user.district, style: GoogleFonts.outfit(color: AppColors.gray, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final success = await admin.rejectUser(user.id);
                  if (success) _showSnack('User rejected successfully');
                },
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                label: Text('Reject', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final success = await admin.approveUser(user.id);
                  if (success) _showSnack('User approved successfully');
                },
                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                label: Text('Approve', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingPhoneUsersList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        final filteredList = admin.pendingPhoneUsers.where((u) {
          final query = _userSearchQuery.toLowerCase();
          return u.name.toLowerCase().contains(query) || 
                 u.phone.contains(query) || 
                 (u.pendingPhone ?? '').contains(query);
        }).toList();

        if (admin.isLoading && admin.pendingPhoneUsers.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (filteredList.isEmpty) {
          return _emptyPlaceholder('No phone updates found', Icons.phone_android);
        }
        return RefreshIndicator(
          onRefresh: () => admin.fetchPendingPhoneUsers(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredList.length,
            itemBuilder: (context, index) {
              final user = filteredList[index];
              return _buildPendingPhoneUserCard(user, admin).animate().fadeIn(delay: (index * 50).ms);
            },
          ),
        );
      },
    );
  }

  Widget _buildPendingPhoneUserCard(UserModel user, AdminProvider admin) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: GoogleFonts.outfit(color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Text('${user.phone} ➔ ${user.pendingPhone}', style: GoogleFonts.outfit(color: AppColors.primaryDark, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _makePhoneCall(user.pendingPhone ?? user.phone),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                            child: const Icon(Icons.call, size: 14, color: AppColors.primaryDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('UPDATE', style: GoogleFonts.outfit(color: Colors.amber[800], fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.gray),
              const SizedBox(width: 4),
              Text(user.district, style: GoogleFonts.outfit(color: AppColors.gray, fontSize: 13)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final success = await admin.rejectPhoneUpdate(user.id);
                  if (success) _showSnack('Phone update rejected');
                },
                icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                label: Text('Reject', style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: () async {
                  final success = await admin.approvePhoneUpdate(user.id);
                  if (success) _showSnack('Phone update approved');
                },
                icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                label: Text('Approve', style: GoogleFonts.outfit(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.black),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.phone, size: 13, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Text(user.phone, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _makePhoneCall(user.phone),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.call, size: 14, color: AppColors.primaryDark),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 13, color: AppColors.gray),
                    const SizedBox(width: 4),
                    Text(user.district, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              user.createdAt != null ? DateFormat('dd MMM').format(user.createdAt!) : '',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SETTINGS TAB ─────────────────────────────────────
  Widget _buildSettingsTab() {
    final auth = Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Set egg price section ──
            Text('Set Egg Price', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
            const SizedBox(height: 6),
            Text('Set today\'s egg price for a district', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)],
              ),
              child: Column(
                children: [
                  // District Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    style: GoogleFonts.outfit(color: AppColors.darkGray, fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Select District',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      labelStyle: GoogleFonts.outfit(color: AppColors.gray),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    items: DistrictData.dropdownItems.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['district'],
                        child: Text(item['label']!, style: GoogleFonts.outfit(fontSize: 15)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDistrict = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Price input
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Price per Egg (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                      labelStyle: GoogleFonts.outfit(color: AppColors.gray),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Set Price button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSettingPrice ? null : () async {
                        if (_selectedDistrict == null) {
                          _showSnack('Please select a district');
                          return;
                        }
                        final priceStr = _priceController.text.trim();
                        if (priceStr.isEmpty) {
                          _showSnack('Please enter a price');
                          return;
                        }
                        final price = double.tryParse(priceStr);
                        if (price == null || price <= 0) {
                          _showSnack('Enter a valid price');
                          return;
                        }
                        setState(() => _isSettingPrice = true);
                        final success = await admin.setEggPrice(_selectedDistrict!, price);
                        setState(() => _isSettingPrice = false);
                        if (success) {
                          _priceController.clear();
                          setState(() => _selectedDistrict = null);
                          _showSnack('Price set successfully! ✅');
                        } else {
                          _showSnack('Failed to set price');
                        }
                      },
                      icon: _isSettingPrice
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                          : const Icon(Icons.save, size: 20),
                      label: Text(
                        _isSettingPrice ? 'Setting...' : 'Set Price',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Today's Prices Overview ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Today's Prices", style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
                IconButton(
                  onPressed: () => admin.fetchTodayPrices(),
                  icon: const Icon(Icons.refresh, color: AppColors.primary, size: 22),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Egg prices across all districts', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
            const SizedBox(height: 16),

            if (admin.todayPrices.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.egg_outlined, size: 40, color: AppColors.lightGray),
                    const SizedBox(height: 8),
                    Text('No prices set yet', style: GoogleFonts.outfit(color: AppColors.gray, fontSize: 14)),
                  ],
                ),
              )
            else
              ...admin.todayPrices.map((p) => _buildPriceCard(p)),

            const SizedBox(height: 28),

            // ── Stock Management ──
            Text('Stock Management', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
            const SizedBox(height: 6),
            Text('Set daily tray availability', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current stock status
                  if (admin.todayStock.isNotEmpty && admin.todayStock['isSet'] == true) ...[
                    _buildStockIndicator(admin.todayStock),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 20),
                  ],

                  // Set/Update stock input
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(fontSize: 15),
                          decoration: InputDecoration(
                            labelText: admin.todayStock['isSet'] == true ? 'Update Tray Limit' : 'Total Trays Available',
                            prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                            labelStyle: GoogleFonts.outfit(color: AppColors.gray),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.lightGray.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSettingStock ? null : () async {
                            final val = int.tryParse(_stockController.text.trim());
                            if (val == null || val <= 0) {
                              _showSnack('Enter a valid tray count');
                              return;
                            }
                            setState(() => _isSettingStock = true);
                            final ok = await admin.setDailyStock(val);
                            setState(() => _isSettingStock = false);
                            if (ok) {
                              _stockController.clear();
                              _showSnack(admin.successMessage ?? 'Stock limit updated! \u2705');
                            } else {
                              _showSnack(admin.error ?? 'Failed to set stock');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: _isSettingStock
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                              : Text(admin.todayStock['isSet'] == true ? 'Update' : 'Set', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Logout
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (mounted) Navigator.pushReplacementNamed(context, '/login');
                },
                icon: const Icon(Icons.logout, size: 20),
                label: Text('Logout', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceCard(Map<String, dynamic> priceData) {
    final district = priceData['district'] as String;
    final pricePerEgg = priceData['pricePerEgg'];
    final isSet = pricePerEgg != null;
    final state = DistrictData.getState(district);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSet ? AppColors.primary.withOpacity(0.15) : Colors.amber.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.03), blurRadius: 8)],
      ),
      child: Row(
        children: [
          // District icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSet ? AppColors.primary.withOpacity(0.1) : Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSet ? Icons.egg : Icons.egg_outlined,
              color: isSet ? AppColors.primary : Colors.amber,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),

          // District name + state
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(district, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkGray)),
                Text(state, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
              ],
            ),
          ),

          // Price
          if (isSet)
            Text(
              '₹${pricePerEgg.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Not set', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800)),
            ),

          const SizedBox(width: 8),

          // Edit button
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedDistrict = district;
                if (isSet) {
                  _priceController.text = pricePerEgg.toString();
                } else {
                  _priceController.clear();
                }
              });
              // Scroll to top
              _showSnack('Editing price for $district');
            },
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.offWhite,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit, size: 16, color: AppColors.gray),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockIndicator(Map<String, dynamic> stock) {
    final total = (stock['totalTrays'] ?? 0) as int;
    final sold = (stock['soldTrays'] ?? 0) as int;
    final remaining = (stock['remainingTrays'] ?? 0) as int;
    final progress = total > 0 ? sold / total : 0.0;

    Color barColor;
    String statusText;
    if (remaining == 0) {
      barColor = AppColors.error;
      statusText = 'OUT OF STOCK';
    } else if (remaining <= 50) {
      barColor = Colors.amber;
      statusText = 'LOW STOCK';
    } else {
      barColor = AppColors.success;
      statusText = 'IN STOCK';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s Stock', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: barColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusText, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: barColor)),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: AppColors.offWhite,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
        const SizedBox(height: 12),

        // Stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStockStat('Total', total, AppColors.darkGray),
            _buildStockStat('Sold', sold, barColor),
            _buildStockStat('Remaining', remaining, AppColors.success),
          ],
        ),
      ],
    );
  }

  Widget _buildStockStat(String label, int value, Color color) {
    return Column(
      children: [
        Text('$value', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
      ],
    );
  }

  void _showOfflineOrderDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final trayController = TextEditingController();
    String selectedMethod = 'cash';
    bool isSaving = false;
    double currentTrayPrice = 0;

    final admin = Provider.of<AdminProvider>(context, listen: false);
    if (admin.todayPrices.isNotEmpty) {
      currentTrayPrice = (admin.todayPrices.first['pricePerTray'] ?? 0).toDouble();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final trayVal = int.tryParse(trayController.text.trim()) ?? 0;
          final totalPrice = trayVal * currentTrayPrice;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            backgroundColor: AppColors.white,
            title: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('Record Offline Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 20)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Customer Details', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray)),
                  const SizedBox(height: 12),
                  _dialogField(nameController, 'Customer Name', Icons.person_outline),
                  const SizedBox(height: 12),
                  _dialogField(phoneController, 'Phone Number', Icons.phone_android, keyboardType: TextInputType.phone),
                  const SizedBox(height: 20),
                  Text('Order Details', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray)),
                  const SizedBox(height: 12),
                  _dialogField(
                    trayController, 
                    'Number of Trays', 
                    Icons.egg_outlined, 
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setDialogState(() {}),
                  ),
                  if (trayVal > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Price:', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text(_currencyFormat.format(totalPrice), style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: AppColors.primaryDark, fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Payment Method', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _paymentChip('Cash', Icons.payments_outlined, selectedMethod == 'cash', () => setDialogState(() => selectedMethod = 'cash')),
                      const SizedBox(width: 10),
                      _paymentChip('Pay Later', Icons.history, selectedMethod == 'pay_later', () => setDialogState(() => selectedMethod = 'pay_later')),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.outfit(color: AppColors.gray, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : () async {
                  final name = nameController.text.trim();
                  final phone = phoneController.text.trim();
                  final trays = int.tryParse(trayController.text.trim());

                  if (name.isEmpty || phone.isEmpty || trays == null || trays < 1) {
                    _showSnack('Please fill all fields correctly');
                    return;
                  }

                  setDialogState(() => isSaving = true);
                  final success = await admin.placeOfflineOrder(
                    trayCount: trays,
                    customerName: name,
                    customerPhone: phone,
                    paymentMethod: selectedMethod,
                  );
                  
                  if (mounted) {
                    setDialogState(() => isSaving = false);
                    if (success) {
                      Navigator.pop(context);
                      _showSnack(admin.successMessage ?? 'Order recorded successfully \u2705');
                    } else {
                      _showSnack(admin.error ?? 'Failed to record order');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isSaving 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.black))
                  : Text('Save Order', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _paymentChip(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.offWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? AppColors.primary : AppColors.lightGray.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isSelected ? AppColors.black : AppColors.gray),
              const SizedBox(width: 6),
              Text(label, style: GoogleFonts.outfit(fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: isSelected ? AppColors.black : AppColors.gray)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController controller, String hint, IconData icon, {TextInputType? keyboardType, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: message.contains('✅') ? AppColors.success : Colors.amber.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── EGG RATES TAB (Trends + Auto Fetch) ────────────────
  Widget _buildEggRatesTab() {
    return Scaffold(
      backgroundColor: AppColors.offWhite,
      appBar: AppBar(
        title: Text('Egg Rate Analysis', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
        actions: [
          Consumer<AdminProvider>(
            builder: (context, admin, _) {
              return IconButton(
                icon: const Icon(Icons.auto_awesome, color: AppColors.primary),
                tooltip: 'Auto-fetch NECC Rates',
                onPressed: admin.isLoading ? null : () async {
                  final ok = await admin.autoFetchLatestPrices();
                  if (ok) {
                    _showSnack('NECC Rates updated successfully! ✅');
                    if (_selectedTrendDistrict != null) {
                      admin.fetchPriceTrends(_selectedTrendDistrict!);
                    }
                  } else if (admin.error != null) {
                    _showSnack(admin.error!);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Section
                Row(
                  children: [
                    _trendSummaryItem('Auto Fetch', 'Enabled', Icons.sync),
                    const SizedBox(width: 12),
                    _trendSummaryItem('Total Districts', '${DistrictData.dropdownItems.length}', Icons.location_city),
                  ],
                ),
                const SizedBox(height: 20),

                // District Selector for Trends
                Text('Price Trends', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 10)],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      hint: Text('Select District to view trends', style: GoogleFonts.outfit(fontSize: 14)),
                      value: _selectedTrendDistrict,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                      items: DistrictData.dropdownItems.map((item) {
                        return DropdownMenuItem<String>(
                          value: item['district'],
                          child: Text(item['label']!, style: GoogleFonts.outfit(fontSize: 15)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedTrendDistrict = val);
                        if (val != null) admin.fetchPriceTrends(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Chart Container
                Container(
                  height: 300,
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(10, 24, 24, 10),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12)],
                  ),
                  child: admin.isLoadingTrends
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _selectedTrendDistrict == null
                      ? Center(child: Text('Select a district above to see charts', style: GoogleFonts.outfit(color: AppColors.gray)))
                      : admin.priceTrends.isEmpty
                        ? Center(child: Text('No historical data available', style: GoogleFonts.outfit(color: AppColors.gray)))
                        : LineChart(
                            LineChartData(
                              lineTouchData: LineTouchData(
                                touchTooltipData: LineTouchTooltipData(
                                  getTooltipColor: (spot) => AppColors.primaryDark,
                                  getTooltipItems: (spots) {
                                    return spots.map((spot) {
                                      final index = admin.priceTrends.length - 1 - spot.x.toInt();
                                      if (index < 0 || index >= admin.priceTrends.length) {
                                        return LineTooltipItem('', GoogleFonts.outfit(color: AppColors.white));
                                      }
                                      final dateStr = admin.priceTrends[index]['priceDate'] ?? admin.priceTrends[index]['price_date'];
                                      final date = dateStr != null ? DateTime.tryParse(dateStr.toString()) : null;
                                      final label = date != null ? DateFormat('MMM dd').format(date) : '?';
                                      return LineTooltipItem(
                                        '$label\n₹${spot.y}',
                                        GoogleFonts.outfit(color: AppColors.white, fontWeight: FontWeight.bold),
                                      );
                                    }).toList();
                                  },
                                ),
                              ),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: AppColors.gray.withOpacity(0.1),
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  axisNameWidget: Text('Date', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    getTitlesWidget: (value, meta) {
                                      final index = admin.priceTrends.length - 1 - value.toInt();
                                      if (index < 0 || index >= admin.priceTrends.length) return const Text('');
                                      
                                      // Only show specific intervals for cleaner look
                                      if (admin.priceTrends.length > 7 && value.toInt() % 3 != 0) return const Text('');
                                      
                                      final dateStr = admin.priceTrends[index]['priceDate'] ?? admin.priceTrends[index]['price_date'];
                                      if (dateStr == null) return const Text('');
                                      final date = DateTime.tryParse(dateStr.toString());
                                      if (date == null) return const Text('');
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(DateFormat('dd').format(date), style: GoogleFonts.outfit(fontSize: 10, color: AppColors.gray)),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  axisNameWidget: Text('Price (₹)', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 40,
                                    getTitlesWidget: (value, meta) {
                                      return Text('₹${value.toStringAsFixed(1)}', style: GoogleFonts.outfit(fontSize: 10, color: AppColors.gray));
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: admin.priceTrends.reversed.toList().asMap().entries.map((e) {
                                    final priceValue = e.value['pricePerEgg'] ?? e.value['price_per_egg'];
                                    double y = 0.0;
                                    if (priceValue != null) {
                                      y = double.tryParse(priceValue.toString()) ?? 0.0;
                                    }
                                    return FlSpot(e.key.toDouble(), y);
                                  }).toList(),
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
                const SizedBox(height: 20),
                Text('Horizontal axis represents dates. Vertical axis represents price per egg (₹).', 
                  style: GoogleFonts.outfit(fontSize: 11, color: AppColors.gray)),
                
                const SizedBox(height: 30),
                // Today's All Rates Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Today's Rates", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700)),
                    TextButton(
                      onPressed: () => admin.fetchTodayPrices(),
                      child: Text('Refresh', style: GoogleFonts.outfit(color: AppColors.primaryDark)),
                    ),
                  ],
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: admin.todayPrices.length,
                  itemBuilder: (context, index) {
                    final item = admin.todayPrices[index];
                    final hasValue = item['pricePerEgg'] != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(item['district'], style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (hasValue) ...[
                            Text('₹${item['pricePerEgg']}', style: GoogleFonts.outfit(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            Text('(₹${item['pricePerTray']}/Tray)', style: GoogleFonts.outfit(fontSize: 11, color: AppColors.gray, fontWeight: FontWeight.w500)),
                          ] else
                            Text('Not Set', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _trendSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
            Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
          ],
        ),
      ),
    );
  }
}
