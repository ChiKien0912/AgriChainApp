import 'package:argri_chain_app/screens/shipper/order/order_management.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../order/order_tiles.dart';
import '../order/order_detail_screen.dart';

class ShipperWaitingTab extends StatefulWidget {
  final String storeId;
  final TextTheme textTheme;
  final Color themeColor;

  const ShipperWaitingTab({
    super.key,
    required this.storeId,
    required this.textTheme,
    required this.themeColor,
  });

  @override
  State<ShipperWaitingTab> createState() => _ShipperWaitingTabState();
}

class _ShipperWaitingTabState extends State<ShipperWaitingTab> {
  Position? currentPosition;
  List<QueryDocumentSnapshot> selectedOrders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      currentPosition = await Geolocator.getCurrentPosition();
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'Chờ giao')
          .where('storeId', isEqualTo: widget.storeId)
          .get();

      final nearbyOrders = snapshot.docs.where((doc) {
        final data = doc.data();
        final loc = data['destination'];
        if (loc == null) return false;
        return OrderManagement.calculateDistance(
              currentPosition!.latitude,
              currentPosition!.longitude,
              loc['lat'],
              loc['lng'],
            ) <= 3.0;
      }).toList();

      setState(() {
        selectedOrders = nearbyOrders;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startDelivery() async {
    setState(() => _loading = true);
    await createDeliveryGroup(
      orders: selectedOrders,
      storeId: widget.storeId,
      position: currentPosition!,
    );
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Đơn gần bạn', style: widget.textTheme.titleLarge),
        const SizedBox(height: 12),
        ...selectedOrders.map((order) => OrderTile(
              order: order,
              textTheme: widget.textTheme,
              context: context,
              isProcessing: false,
              onShowDetail: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShipperOrderDetailScreen(orderId: order.id),
                ),
              ),
            )),
        if (selectedOrders.isNotEmpty)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _startDelivery,
            icon: const Icon(Icons.delivery_dining_rounded),
            label: const Text("Bắt đầu giao"),
          ),
      ],
    );
  }
}
