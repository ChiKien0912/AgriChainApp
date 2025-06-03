import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../chat/chatscreen.dart';

class OrderTile extends StatelessWidget {
  final QueryDocumentSnapshot order;
  final TextTheme textTheme;
  final BuildContext context;
  final bool isProcessing;
  final bool isDelivering;
  final bool isDelivered;
  final int? orderIndex;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onConfirmDelivered;
  final VoidCallback? onCallCustomer;
  final VoidCallback? onSmsCustomer;
  final VoidCallback? onRateOrder;
  final VoidCallback? onCaptureProof;
  final VoidCallback? onShowMap;
  final VoidCallback? onShowDetail;

  const OrderTile({
    required this.order,
    required this.textTheme,
    required this.context,
    this.isProcessing = false,
    this.isDelivering = false,
    this.isDelivered = false,
    this.orderIndex,
    this.onStartDelivery,
    this.onConfirmDelivered,
    this.onCallCustomer,
    this.onSmsCustomer,
    this.onRateOrder,
    this.onCaptureProof,
    this.onShowMap,
    this.onShowDetail,
    super.key,
  });

  Future<void> _handleStartDelivery() async {
    final scaffoldContext = context;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final shipperName = userDoc.data()?['name'] ?? 'Shipper';
      final shipperEmail = userDoc.data()?['email'] ?? 'Shipper';
      final shipperPhone = userDoc.data()?['phone'] ?? 'Shipper';

      await FirebaseFirestore.instance.collection('orders').doc(order.id).update({  
        'shippername': shipperName,
        'shipperEmail': shipperEmail,
        'shipperPhone': shipperPhone,
        'status': 'Đang giao',
        'shipperId': user.uid,
        'deliveryStartTime': FieldValue.serverTimestamp(),
      });
      // Optionally: show a snackbar or feedback
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('Đã nhận đơn, bắt đầu giao hàng!')),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(scaffoldContext).showSnackBar(
        SnackBar(content: Text('Có lỗi khi nhận đơn: $e')),
      );
    }
    if (onStartDelivery != null) onStartDelivery!();
  }

  @override
  Widget build(BuildContext context) {
    final data = order.data() as Map<String, dynamic>;
    final String itemSummary = (data['items'] as List)
        .map<String>((item) => "${item['name']} (${item['quantity']})")
        .join(", ");

    final modernTextTheme = textTheme.apply(
      fontFamily: 'Montserrat',
      bodyColor: Colors.black87,
      displayColor: Colors.black87,
    );

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.95, end: 1),
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onShowDetail,
        splashColor: Colors.greenAccent.withAlpha((0.15 * 255).toInt()),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(18),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withAlpha((0.06 * 255).toInt()),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: isDelivered
                  ? Colors.green.withAlpha((0.25 * 255).toInt())
                  : isDelivering
                      ? Colors.orange.withAlpha((0.18 * 255).toInt())
                      : Colors.blueGrey.withAlpha((0.13 * 255).toInt()),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(modernTextTheme, data),
              const SizedBox(height: 14),
              _infoRow(
                icon: Icons.shopping_bag_rounded,
                iconColor: Colors.blueGrey.shade700,
                label: itemSummary,
                textTheme: modernTextTheme,
              ),
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.email_rounded,
                iconColor: Colors.orange.shade700,
                label: data['email'],
                textTheme: modernTextTheme,
              ),
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.location_on_rounded,
                iconColor: Colors.redAccent,
                label: data['address'],
                textTheme: modernTextTheme,
              ),
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.attach_money_rounded,
                iconColor: Colors.green.shade700,
                label: "${data['total'].toStringAsFixed(0)}đ",
                textTheme: modernTextTheme,
              ),
              const SizedBox(height: 8),
              _infoRow(
                icon: Icons.access_time_rounded,
                iconColor: Colors.grey.shade600,
                label: data['timestamp'] != null
                    ? _formatDateTime(data['timestamp'].toDate())
                    : '',
                textTheme: modernTextTheme,
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _buildActionButtons(modernTextTheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerRow(TextTheme modernTextTheme, Map<String, dynamic> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Hero(
          tag: 'order_icon_${order.id}',
          child: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.green.withAlpha((0.13 * 255).toInt()),
            child: Icon(
              Icons.receipt_long_rounded,
              color: Colors.green.shade700,
              size: 32,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Đơn: ${order.id.substring(0, 6)}...",
                style: modernTextTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              if (orderIndex != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Chip(
                    label: Text(
                      "Thứ tự: $orderIndex",
                      style: modernTextTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Colors.green.shade900,
                      ),
                    ),
                    // ignore: deprecated_member_use
                    backgroundColor: Colors.green.withOpacity(0.13),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        _statusBadge(modernTextTheme),
      ],
    );
  }

  Widget _statusBadge(TextTheme modernTextTheme) {
    Color badgeColor;
    IconData badgeIcon;
    String badgeText;

    if (isProcessing) {
      badgeColor = Colors.blueGrey.shade100;
      badgeIcon = Icons.timelapse_rounded;
      badgeText = "Chờ giao";
    } else if (isDelivering) {
      badgeColor = Colors.orange.shade100;
      badgeIcon = Icons.delivery_dining_rounded;
      badgeText = "Đang giao";
    } else {
      badgeColor = Colors.green.shade100;
      badgeIcon = Icons.check_circle_rounded;
      badgeText = "Đã giao";
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            badgeIcon,
            color: Colors.green.shade700,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: modernTextTheme.labelMedium?.copyWith(
              color: Colors.green.shade900,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required TextTheme textTheme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              height: 1.35,
              fontFamily: 'Montserrat',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(TextTheme modernTextTheme) {
      final data = order.data() as Map<String, dynamic>;
      final double? rating = data['shipperRating']?.toDouble();
      final String? review = data['review'];
  if (data['status'] == 'Đã hủy') {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Icon(Icons.cancel_rounded, color: Colors.red[400]),
          const SizedBox(width: 6),
          Text(
            'Đơn hàng đã bị hủy',
            style: modernTextTheme.bodyMedium?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  if (isDelivered) {
    if (rating == null && onRateOrder != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                textStyle: modernTextTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.star_rounded),
              label: const Text('Đánh giá đơn hàng'),
              onPressed: onRateOrder,
            ),
          ],
        ),
      );
    } else if (rating != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 4),
            Text(
              '${rating.toStringAsFixed(1)}/5',
              style: modernTextTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (review != null && review.isNotEmpty) ...[
              const SizedBox(width: 12),
              Icon(Icons.comment_rounded, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  review,
                  style: modernTextTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }
  }
    if (isProcessing) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: modernTextTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              onPressed: _handleStartDelivery,
              icon: const Icon(Icons.delivery_dining_rounded, size: 22),
              label: const Text("Bắt đầu giao"),
            ),
          ),
        ],
      );
    }
    if (isDelivering && onConfirmDelivered != null) {
      final data = order.data() as Map<String, dynamic>;
      final phone = data['phone'];
      final customerId = data['userId'];
      final shipperId = data['shipperId'];
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                textStyle: modernTextTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              onPressed: onConfirmDelivered,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
              label: const Text("Đã giao"),
            ),
          ),
          const SizedBox(width: 10),
          _circleIconButton(
            icon: Icons.phone_rounded,
            color: Colors.blue.shade600,
            tooltip: "Gọi khách",
            onPressed: () {
              if (phone != null) {
                launchUrl(Uri.parse("tel:$phone"));
              }
            },
          ),
          const SizedBox(width: 6),
          _circleIconButton(
            icon: Icons.sms_rounded,
            color: Colors.deepPurple.shade400,
            tooltip: "Nhắn tin khách",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    orderId: order.id,
                    customerId: customerId,
                    shipperId: shipperId,
                    isCustomer: false,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          _circleIconButton(
            icon: Icons.map_rounded,
            color: Colors.green.shade700,
            tooltip: "Xem bản đồ",
            onPressed: onShowMap,
          ),
        ],
      );
    }
    if (isDelivered && (onRateOrder != null || onCaptureProof != null)) {
      return Row(
        children: [
          if (onRateOrder != null)
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: modernTextTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                onPressed: onRateOrder,
                icon: const Icon(Icons.star_rounded, color: Colors.white),
                label: const Text("Đánh giá đơn"),
              ),
            ),
          if (onCaptureProof != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: modernTextTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                onPressed: onCaptureProof,
                icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                label: const Text("Chụp minh chứng"),
              ),
            ),
          ]
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _circleIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        // ignore: deprecated_member_use
        color: color.withOpacity(0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day.toString().padLeft(2, '0')}/"
        "${dateTime.month.toString().padLeft(2, '0')}/"
        "${dateTime.year} "
        "${dateTime.hour.toString().padLeft(2, '0')}:"
        "${dateTime.minute.toString().padLeft(2, '0')}";
  }
}