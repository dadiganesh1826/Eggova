import 'user.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String? userId;
  final String? customerName;
  final String? customerPhone;
  final bool isOffline;
  final int trayCount;
  final double pricePerTray;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime? paidAt;
  final String? paidVia;
  final DateTime createdAt;
  final UserModel? user;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.userId,
    this.customerName,
    this.customerPhone,
    this.isOffline = false,
    required this.trayCount,
    required this.pricePerTray,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.paidAt,
    this.paidVia,
    required this.createdAt,
    this.user,
  });

  bool get isPending =>
      paymentStatus == 'pending' || paymentStatus == 'approval_pending';
  bool get isCompleted => paymentStatus == 'completed';
  bool get isApprovalPending => paymentStatus == 'approval_pending';

  String get statusLabel {
    switch (paymentStatus) {
      case 'completed':
        return 'Paid';
      case 'approval_pending':
        return 'Awaiting Approval';
      case 'pending':
        return 'Payment Pending';
      default:
        return paymentStatus;
    }
  }

  String get paymentMethodLabel {
    if (paymentStatus != 'completed') return '-';
    switch (paidVia?.toLowerCase() ?? paymentMethod.toLowerCase()) {
      case 'upi':
      case 'razorpay':
        return 'Paid via UPI';
      case 'cash':
        return 'Paid via Cash';
      default:
        return 'Paid via ${paidVia ?? paymentMethod}';
    }
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['orderNumber'] ?? json['order_number'] ?? '',
      userId: json['userId'] ?? json['user_id'],
      customerName: json['customerName'] ?? json['customer_name'],
      customerPhone: json['customerPhone'] ?? json['customer_phone'],
      isOffline: json['isOffline'] ?? json['is_offline'] ?? false,
      trayCount: json['trayCount'] ?? json['tray_count'] ?? 0,
      pricePerTray:
          _parseDouble(json['pricePerTray'] ?? json['price_per_tray']),
      totalAmount: _parseDouble(json['totalAmount'] ?? json['total_amount']),
      paymentMethod: json['paymentMethod'] ?? json['payment_method'] ?? '',
      paymentStatus:
          json['paymentStatus'] ?? json['payment_status'] ?? 'pending',
      orderStatus: json['orderStatus'] ?? json['order_status'] ?? 'placed',
      razorpayOrderId: json['razorpayOrderId'] ?? json['razorpay_order_id'],
      razorpayPaymentId:
          json['razorpayPaymentId'] ?? json['razorpay_payment_id'],
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'])
          : (json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null),
      paidVia: json['paidVia'] ?? json['paid_via'],
      createdAt: DateTime.parse(json['createdAt'] ??
          json['created_at'] ??
          DateTime.now().toIso8601String()),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}
