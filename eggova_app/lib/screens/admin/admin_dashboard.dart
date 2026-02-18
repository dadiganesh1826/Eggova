import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  late TabController _paymentTabController;

  @override
  void initState() {
    super.initState();
    _paymentTabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = Provider.of<AdminProvider>(context, listen: false);
      admin.fetchDashboardStats();
      admin.fetchUsers();
      admin.fetchPendingPayments();
      admin.fetchCompletedPayments();
    });
  }

  @override
  void dispose() {
    _paymentTabController.dispose();
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
                      childAspectRatio: 1.25,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.darkGray)),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, color: AppColors.gray)),
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
        title: Text('Payments', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
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

  Widget _buildPendingPaymentsList() {
    return Consumer<AdminProvider>(
      builder: (context, admin, _) {
        if (admin.isLoading && admin.pendingPayments.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (admin.pendingPayments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 80, color: AppColors.success.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text('No pending payments!', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => admin.fetchPendingPayments(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admin.pendingPayments.length,
            itemBuilder: (context, index) {
              final order = admin.pendingPayments[index];
              return _buildAdminPaymentCard(order, isPending: true)
                  .animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
            },
          ),
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

        if (admin.completedPayments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 80, color: AppColors.lightGray),
                const SizedBox(height: 16),
                Text('No completed payments yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => admin.fetchCompletedPayments(),
          color: AppColors.primary,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: admin.completedPayments.length,
            itemBuilder: (context, index) {
              final order = admin.completedPayments[index];
              return _buildAdminPaymentCard(order, isPending: false)
                  .animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
            },
          ),
        );
      },
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
                    Text(user?.name ?? 'Unknown', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkGray)),
                    const SizedBox(height: 2),
                    Text(user?.phone ?? '', style: GoogleFonts.outfit(fontSize: 13, color: AppColors.gray)),
                  ],
                ),
              ),
              if (order.isApprovalPending)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('Approval Needed', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.warning)),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Order details row
          Row(
            children: [
              _detailChip(Icons.egg, '${order.trayCount} trays'),
              const SizedBox(width: 10),
              _detailChip(Icons.calendar_today, DateFormat('dd MMM').format(order.createdAt)),
              const SizedBox(width: 10),
              _detailChip(Icons.tag, order.orderNumber),
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
        title: Text('Registered Users', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.black,
      ),
      body: Consumer<AdminProvider>(
        builder: (context, admin, _) {
          if (admin.isLoading && admin.users.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (admin.users.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: AppColors.lightGray),
                  const SizedBox(height: 16),
                  Text('No users registered yet', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.gray)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => admin.fetchUsers(),
            color: AppColors.primary,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: admin.users.length,
              itemBuilder: (context, index) {
                final user = admin.users[index];
                return _buildUserCard(user).animate().fadeIn(delay: (index * 80).ms, duration: 400.ms);
              },
            ),
          );
        },
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
    final _priceController = TextEditingController();
    final _districtController = TextEditingController();

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
            // Set egg price section
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
                  TextField(
                    controller: _districtController,
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'District',
                      prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                      labelStyle: GoogleFonts.outfit(color: AppColors.gray),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(fontSize: 15),
                    decoration: InputDecoration(
                      labelText: 'Price per Egg (₹)',
                      prefixIcon: const Icon(Icons.currency_rupee, color: AppColors.primary),
                      labelStyle: GoogleFonts.outfit(color: AppColors.gray),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final district = _districtController.text.trim();
                        final priceStr = _priceController.text.trim();
                        if (district.isEmpty || priceStr.isEmpty) {
                          _showSnack('Please fill all fields');
                          return;
                        }
                        final price = double.tryParse(priceStr);
                        if (price == null || price <= 0) {
                          _showSnack('Enter a valid price');
                          return;
                        }
                        final admin = Provider.of<AdminProvider>(context, listen: false);
                        await admin.setEggPrice(district, price);
                        _priceController.clear();
                        _districtController.clear();
                        _showSnack('Price set successfully! ✅');
                      },
                      icon: const Icon(Icons.save, size: 20),
                      label: Text('Set Price', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
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

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
