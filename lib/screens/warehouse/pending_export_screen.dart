import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PendingExportsScreen extends StatefulWidget {
  const PendingExportsScreen({super.key});

  @override
  State<PendingExportsScreen> createState() => _PendingExportsScreenState();
}

class _PendingExportsScreenState extends State<PendingExportsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _approveExport(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;

    await FirebaseFirestore.instance.collection('approved_batches').add({
      ...data,
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    await doc.reference.delete();
  }

  Future<void> _rejectExport(DocumentSnapshot doc) async {
    await doc.reference.update({'status': 'rejected'});
  }

  Future<void> _handleRestockRequest(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final productId = data['productId'];
    final productName = data['productName'];
    final branchId = data['branchId'];

    final slotQuery = await FirebaseFirestore.instance
        .collection('warehouse_slots')
        .where('productName', isEqualTo: productName)
        .where('quantity', isGreaterThan: 0)
        .orderBy('quantity', descending: true)
        .limit(1)
        .get();

    if (slotQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không còn hàng trong kho')),
      );
      return;
    }

    final slot = slotQuery.docs.first;
    final slotData = slot.data();
    final quantityToExport = 1;

    await FirebaseFirestore.instance.collection('pending_batches').add({
      'storeId': branchId,
      'storeName': branchId,
      'productId': productId,
      'productName': productName,
      'slotId': slotData['slotId'],
      'batchId': slotData['batchId'],
      'quantity': quantityToExport,
      'note': '',
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await slot.reference.update({
      'quantity': (slotData['quantity'] ?? 0) - quantityToExport,
    });

    await doc.reference.update({'status': 'processed'});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã tạo đơn xuất từ yêu cầu')),
    );
  }

  Widget _buildCard({
    required Widget child,
    Color? color,
    EdgeInsetsGeometry? margin,
    double elevation = 4,
  }) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: elevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: color ?? Colors.white,
        child: child,
      ),
    );
  }

  Widget _buildPendingList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        return _buildCard(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Icon(Icons.inventory, color: Colors.blue.shade700),
            ),
            title: Text(
              '${data['productName']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SL: ${data['quantity']} thùng',
                      style: const TextStyle(fontSize: 14)),
                  Text('Cửa hàng: ${data['storeName'] ?? data['storeId']}',
                      style: const TextStyle(fontSize: 13, color: Colors.black54)),
                  if ((data['note'] ?? '').toString().isNotEmpty)
                    Text('Ghi chú: ${data['note']}',
                        style: const TextStyle(fontSize: 13, color: Colors.black54)),
                ],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: 'Duyệt xuất',
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green, size: 28),
                      onPressed: () => _approveExport(docs[index]),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Từ chối',
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red, size: 28),
                      onPressed: () => _rejectExport(docs[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestockList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        return _buildCard(
          color: Colors.orange.shade50,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: Icon(Icons.store, color: Colors.orange.shade700),
            ),
            title: Text(
              'SP: ${data['productName']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Từ cửa hàng: ${data['branchId']}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
            ),
            trailing: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.send),
              label: const Text('Tạo đơn xuất'),
              onPressed: () => _handleRestockRequest(docs[index]),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          title: const Text('Duyệt xuất kho',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          elevation: 0,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          bottom: TabBar(
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.2),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: const [
              Tab(text: 'Chờ duyệt'),
              Tab(text: 'Yêu cầu nhập hàng'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('pending_batches')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Center(
                      child: Text(
                        'Không có đơn chờ duyệt',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  );
                }
                return _buildPendingList(docs);
              },
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('restock_requests')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Center(
                      child: Text(
                        'Không có yêu cầu nhập hàng',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ),
                  );
                }
                return _buildRestockList(docs);
              },
            ),
          ],
        ),
      ),
    );
  }
}
