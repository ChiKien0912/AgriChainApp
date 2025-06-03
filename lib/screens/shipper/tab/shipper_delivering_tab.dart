import 'dart:async';
import 'package:argri_chain_app/screens/shipper/order/confirm_deliverying.dart';
import 'package:argri_chain_app/screens/shipper/order/order_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../order/order_tiles.dart';
import '../order/order_detail_screen.dart';
import '../route/route_mapping.dart';

class ShipperDeliveringTab extends StatefulWidget {
  final String storeId;
  final TextTheme textTheme;
  final Color themeColor;

  const ShipperDeliveringTab({
    super.key,
    required this.storeId,
    required this.textTheme,
    required this.themeColor,
  });

  @override
  State<ShipperDeliveringTab> createState() => _ShipperDeliveringTabState();
}

class _ShipperDeliveringTabState extends State<ShipperDeliveringTab> {
  Timer? locationTimer;

  @override
  void initState() {
    super.initState();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    locationTimer?.cancel();
    super.dispose();
  }

  void _startLocationUpdates() {
    locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final position = await Geolocator.getCurrentPosition();
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'Đang giao')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      for (var doc in snapshot.docs) {
        await FirebaseFirestore.instance.collection('orders').doc(doc.id).update({
          'shipperLocation': {
            'lat': position.latitude,
            'lng': position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'Đang giao')
          .where('storeId', isEqualTo: widget.storeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Không có đơn đang giao"));
        }

        final orders = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final order = orders[idx];
            final data = order.data() as Map<String, dynamic>;

            return OrderTile(
              order: order,
              textTheme: widget.textTheme,
              context: context,
              isDelivering: true,
              orderIndex: idx + 1,
onConfirmDelivered: () async {
  try {
    // 1. Gọi Smart Contract
    await confirmDeliveryOnBlockchain(order.id);

    // 2. Cập nhật trạng thái đơn hàng trong Firestore
    await OrderManagement.updateOrderStatus(order.id, "Đã giao");

    // 3. Thông báo thành công
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Xác nhận giao hàng thành công.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lỗi khi xác nhận blockchain: $e')),
    );
  }
},
              onCallCustomer: () {
                final phone = data['phone'];
                if (phone != null) launchUrl(Uri.parse("tel:$phone"));
              },
              onSmsCustomer: () {
                final phone = data['phone'];
                if (phone != null) launchUrl(Uri.parse("sms:$phone"));
              },
              onShowMap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RouteMapScreen(
                    shipperLat: data['shipperLocation']?['lat'] ?? 0.0,
                    shipperLng: data['shipperLocation']?['lng'] ?? 0.0,
                    destLat: data['destination']?['lat'] ?? 0.0,
                    destLng: data['destination']?['lng'] ?? 0.0,
                  ),
                ),
              ),
              onShowDetail: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShipperOrderDetailScreen(orderId: order.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
