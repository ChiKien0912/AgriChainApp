import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';
import 'generateshippingLabel.dart';

class StoreOrderScreen extends StatefulWidget {
  final String branchId;
  const StoreOrderScreen({super.key, required this.branchId});

  @override
  State<StoreOrderScreen> createState() => _StoreOrderScreenState();
}

class _StoreOrderScreenState extends State<StoreOrderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int batchCount = 0;
  int orderCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _countDocuments();
  }

  Future<void> _countDocuments() async {
    final batchSnap = await FirebaseFirestore.instance
        .collection('approved_batches')
        .where('storeId', isEqualTo: widget.branchId)
        .get();
    final orderSnap = await FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: widget.branchId)
        .where('status', isEqualTo: 'Đang xử lý')
        .get();

    setState(() {
      batchCount = batchSnap.docs.length;
      orderCount = orderSnap.docs.length;
    });
  }

  void _scanBarcode() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text("Quét mã QR")),
          body: MobileScanner(
            onDetect: (capture) async {
              try {
                final barcode = capture.barcodes.first.rawValue;
                if (barcode == null) return;

                final decoded = json.decode(barcode);
                if (!mounted) return;

                if (decoded is Map<String, dynamic> && decoded['productId'] != null) {
                  final productQuery = await FirebaseFirestore.instance
                      .collection('farm_products')
                      .where('productId', isEqualTo: decoded['productId'])
                      .limit(1)
                      .get();

                  if (!mounted) return;
                  Navigator.pop(context);

                  if (productQuery.docs.isNotEmpty) {
                    final product = productQuery.docs.first.data();
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text("Thông tin sản phẩm"),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Tên: ${product['productName']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text("Ngày thu hoạch: ${product['harvestDate']}"),
                            const SizedBox(height: 8),
                            Text("Loại hữu cơ: ${product['organicType']}"),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Đóng"),
                          ),
                        ],
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Không tìm thấy sản phẩm")),
                    );
                  }
                } else {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Mã QR không hợp lệ")),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Lỗi: ${e.toString()}")),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() => const Center(
        child: SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(strokeWidth: 5),
        ),
      );

  Widget _animatedCounter({required int value, required String label, required Color color, required IconData icon}) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      builder: (context, val, child) => Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
  children: [
    CircleAvatar(
      backgroundColor: color.withOpacity(0.2),
      child: Icon(icon, color: color),
    ),
    const SizedBox(width: 12),
    Expanded( 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$val',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: color),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis, 
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    ),
  ],
),

        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white,
        ),
        labelColor: Colors.blue[900],
        unselectedLabelColor: Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        tabs: [
          Tab(text: 'Lô đã xác nhận ($batchCount)'),
          Tab(text: 'Duyệt đơn ($orderCount)'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            title: FittedBox(
  fit: BoxFit.scaleDown,
  child: Text('Quản lý đơn hàng cửa hàng'),
),

            floating: true,
            pinned: true,
            snap: true,
            backgroundColor: theme.primaryColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scanBarcode,
                tooltip: "Quét mã QR",
              )
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: _buildTabBar(),
            ),
          ),
              SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: _animatedCounter(
                value: batchCount,
                label: "Lô xác nhận",
                color: Colors.green,
                icon: Icons.inventory_2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _animatedCounter(
                value: orderCount,
                label: "Đơn cần duyệt",
                color: Colors.blue,
                icon: Icons.shopping_cart,
              ),
            ),
          ],
        ),
      ),
    ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Lô đã xác nhận
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('approved_batches')
                  .where('storeId', isEqualTo: widget.branchId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildLoading();
                final batches = snapshot.data!.docs;
                if (batches.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.inbox, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Không có lô hàng đã xác nhận'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  itemCount: batches.length,
                  itemBuilder: (_, index) {
                    final batch = batches[index];
                    final productName = batch['productName'] ?? 'Không tên';
                    final quantity = batch['quantity'] ?? 0;
                    final productId = batch['productId'];
                    final slotId = batch['slotId'];

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      child: Card(
                        elevation: 8,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: const Icon(Icons.inventory_2, color: Colors.green),
                          ),
                          title: Text(productName,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Số lượng: $quantity\nSlot: $slotId'),
                          isThreeLine: true,
                          trailing: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('Xác nhận'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                    child: CircularProgressIndicator()),
                              );

                              final docId = '${widget.branchId}_$productId';
                              final ref = FirebaseFirestore.instance
                                  .collection('branch_products')
                                  .doc(docId);

                              final snap = await ref.get();

                              if (snap.exists) {
                                await ref.update({
                                  'quantity':
                                      (snap.data()?['quantity'] ?? 0) + quantity,
                                  'lastUpdated': FieldValue.serverTimestamp(),
                                });
                              } else {
                                await ref.set({
                                  'branchId': widget.branchId,
                                  'productId': productId,
                                  'quantity': quantity,
                                  'lastUpdated': FieldValue.serverTimestamp(),
                                });
                              }

                              await batch.reference.delete();
                              _countDocuments();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle,
                                          color: Colors.green),
                                      SizedBox(width: 8),
                                      Text('Đã xác nhận lô hàng'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[600],
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            // Tab 2: Duyệt đơn
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('storeId', isEqualTo: widget.branchId)
                  .where('status', isEqualTo: 'Đang xử lý')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildLoading();
                final orders = snapshot.data!.docs;
                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.assignment_turned_in,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Không có đơn cần xử lý'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                  itemCount: orders.length,
                  itemBuilder: (_, index) {
                    final order = orders[index];
                    final items = List<Map<String, dynamic>>.from(order['items']);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      child: Card(
                        elevation: 8,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                            splashColor: Colors.blue.withOpacity(0.1),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue[100],
                              child: const Icon(Icons.shopping_cart, color: Colors.blue),
                            ),
                            title: Text('Đơn: ${order.id}',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${items.length} sản phẩm'),
                            children: [
                              ...items.map((item) => ListTile(
                                    title: Text(item['name']),
                                    trailing: Text('${item['quantity']}'),
                                  )),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.done_all),
                                  label: const Text('Hoàn tất và giao hàng'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                  onPressed: () async {

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  for (var item in items) {
    final prodId = item['productId'];
    final qty = item['quantity'];
    final docId = '${widget.branchId}_$prodId';
    final ref = FirebaseFirestore.instance.collection('branch_products').doc(docId);
    final snap = await ref.get();

    if (snap.exists) {
      await ref.update({
        'quantity': (snap.data()?['quantity'] ?? 0) - qty,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  await order.reference.update({'status': 'Chờ giao'});
  _countDocuments();
  Navigator.pop(context);

  // Lấy thêm thông tin khách hàng
  final customerName = order['name'] ?? 'Chưa rõ';
  final customerAddress = order['address'] ?? 'Không có địa chỉ';

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("In mã vận đơn"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_shipping, size: 80, color: Colors.blue),
          const SizedBox(height: 12),
          const Text(
            "Tạo và in mã vận đơn cho đơn hàng này?",
            style: TextStyle(fontSize: 15),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text("Hủy"),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.print),
          label: const Text("Tạo PDF"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () async {
            Navigator.pop(context);
            await generateShippingLabelPdf(
              orderId: order.id,
              customerName: customerName,
              customerAddress: customerAddress,
              items: List<Map<String, dynamic>>.from(order['items']),
              storeId: widget.branchId,
            );
          },
        ),
      ],
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: const [
          Icon(Icons.check_circle, color: Colors.blue),
          SizedBox(width: 8),
          Text('Đã duyệt và trừ hàng'),
        ],
      ),
      backgroundColor: Colors.blue[600],
      duration: const Duration(seconds: 2),
    ),
  );
},

                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}