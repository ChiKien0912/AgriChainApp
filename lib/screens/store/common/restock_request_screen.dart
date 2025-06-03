import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RestockRequestScreen extends StatelessWidget {
  final String branchId;
  const RestockRequestScreen({super.key, required this.branchId});

  Future<void> requestRestock(BuildContext context, String productId, String productName) async {
    await FirebaseFirestore.instance.collection('restock_requests').add({
      'branchId': branchId,
      'productId': productId,
      'productName': productName,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending'
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi yêu cầu xuất hàng cho "$productName"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      appBar: AppBar(
        title: const Text(
          'Yêu cầu xuất hàng',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        foregroundColor: Colors.redAccent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('branch_products')
            .where('branchId', isEqualTo: branchId)
            .where('quantity', isLessThan: 10)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: AnimatedOpacity(
                opacity: 1,
                duration: Duration(milliseconds: 500),
                child: CircularProgressIndicator(
                  color: Colors.redAccent,
                  strokeWidth: 4,
                ),
              ),
            );
          }
          final lowStockItems = snapshot.data!.docs;

          if (lowStockItems.isEmpty) {
            return Center(
              child: AnimatedOpacity(
                opacity: 1,
                duration: const Duration(milliseconds: 500),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, color: Colors.green, size: 80),
                    const SizedBox(height: 18),
                    const Text(
                      'Không có sản phẩm nào gần hết hàng',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            itemCount: lowStockItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final item = lowStockItems[index];
              final productId = item['productId'];
              final quantity = item['quantity'] ?? 0;

              return TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 500 + index * 120),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 40),
                      child: child,
                    ),
                  );
                },
                child: Material(
                  color: Colors.white,
                  elevation: 3,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    splashColor: Colors.redAccent.withOpacity(0.08),
                    highlightColor: Colors.redAccent.withOpacity(0.03),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.redAccent.withOpacity(0.12),
                            child: Icon(Icons.inventory_2_rounded, color: Colors.redAccent, size: 32),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sản phẩm: $productId',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.warning_amber_rounded,
                                      color: quantity < 5 ? Colors.red : Colors.orange,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tồn kho: $quantity',
                                      style: TextStyle(
                                        color: quantity < 5 ? Colors.red : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            onPressed: () => requestRestock(context, productId, productId),
                            icon: const Icon(Icons.send, size: 20),
                            label: const Text('Yêu cầu xuất'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
