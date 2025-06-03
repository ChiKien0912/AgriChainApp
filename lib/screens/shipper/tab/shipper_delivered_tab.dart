import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../order/order_tiles.dart';
import '../order/order_detail_screen.dart';

class ShipperDeliveredTab extends StatelessWidget {
  final String storeId;
  final TextTheme textTheme;
  final Color themeColor;

  const ShipperDeliveredTab({
    super.key,
    required this.storeId,
    required this.textTheme,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'Đã giao')
          .where('storeId', isEqualTo: storeId)
          .orderBy('deliveryStartTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return Center(
            child: Text(
              "Chưa có đơn hàng nào đã giao",
              style: textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            // ignore: unused_local_variable
            final double? rating = data['shipperRating']?.toDouble();
            // ignore: unused_local_variable
            final String? review = data['review'];

            return OrderTile(
              order: order,
              textTheme: textTheme,
              context: context,
              isDelivered: true,
              orderIndex: index + 1,
              onShowDetail: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShipperOrderDetailScreen(orderId: order.id),
                ),
              ),
              onRateOrder: () => showRatingDialog(context, order), 
            );
          },
        );
      },
    );
  }
}
void showRatingDialog(BuildContext context, DocumentSnapshot order) {
  final data = order.data() as Map<String, dynamic>;
  final controller = TextEditingController(text: data['review'] ?? '');
  double rating = data['shipperRating']?.toDouble() ?? 0;

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Đánh giá đơn hàng"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Đơn: ${order.id}"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                icon: Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
                onPressed: () => Navigator.pop(context, i + 1.0),
              );
            }),
          ),
          TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Nhận xét'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
        ElevatedButton(
          onPressed: () async {
            await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
              'shipperRating': rating,
              'review': controller.text,
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Đã cập nhật đánh giá")),
            );
          },
          child: const Text("Gửi"),
        ),
      ],
    ),
  );
}
