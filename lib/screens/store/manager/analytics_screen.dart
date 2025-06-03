import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnalyticsScreen extends StatefulWidget {
  final String branchId;
  const AnalyticsScreen({Key? key, required this.branchId}) : super(key: key);

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> stockData = [];
  List<Map<String, dynamic>> topSellingProducts = [];
  List<Map<String, dynamic>> suggestedProducts = [];
  bool isLoading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    fetchAnalyticsData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> fetchAnalyticsData() async {
    try {
      final results = await Future.wait([
        fetchStockData(),
        fetchTopSellingProducts(),
        fetchSuggestedProducts(),
      ]);

      setState(() {
        stockData = results[0];
        topSellingProducts = results[1];
        suggestedProducts = results[2];
        isLoading = false;
      });
      _controller.forward(from: 0);
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      setState(() => isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchStockData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('branch_products')
        .where('branchId', isEqualTo: widget.branchId)
        .get();

    List<Map<String, dynamic>> result = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final prodSnap = await FirebaseFirestore.instance
          .collection('products')
          .doc(data['productId'])
          .get();

      if (prodSnap.exists) {
        result.add({
          'productId': data['productId'],
          'name': prodSnap.data()?['name'] ?? '',
          'quantity': data['quantity'],
          'unit': prodSnap.data()?['unit'] ?? '',
        });
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchTopSellingProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('storeId', isEqualTo: widget.branchId)
        .get();

    Map<String, int> sales = {};
    for (var doc in snapshot.docs) {
      for (var item in List.from(doc['items'])) {
        final id = item['productId'];
        final qty = item['quantity'] ?? 1;
        sales[id] = (sales[id] ?? 0) + (qty as int);
      }
    }

    final sorted = sales.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<Map<String, dynamic>> result = [];
    for (var e in sorted.take(5)) {
      final prodSnap = await FirebaseFirestore.instance
          .collection('products')
          .doc(e.key)
          .get();
      if (prodSnap.exists) {
        result.add({
          'productId': e.key,
          'name': prodSnap.data()?['name'] ?? '',
          'sold': e.value,
          'unit': prodSnap.data()?['unit'] ?? '',
        });
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> fetchSuggestedProducts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('user_behavior')
        .get();

    Map<String, int> views = {};
    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data.containsKey('productname')) {
        final name = data['productname'];
        views[name] = (views[name] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> result = [];
    for (var e in views.entries) {
      final productSnap = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: e.key)
          .get();

      if (productSnap.docs.isNotEmpty) {
        final p = productSnap.docs.first;
        final prodId = p.id;
        final stockSnap = await FirebaseFirestore.instance
            .collection('branch_products')
            .where('branchId', isEqualTo: widget.branchId)
            .where('productId', isEqualTo: prodId)
            .get();

        int qty = 0;
        if (stockSnap.docs.isNotEmpty) {
          qty = stockSnap.docs.first['quantity'];
        }

        if (qty < 10) {
          result.add({
            'productId': prodId,
            'name': p['name'],
            'views': e.value,
            'quantity': qty,
            'unit': p['unit'],
          });
        }
      }
    }
    return result;
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: const Color(0xFF388E3C), size: 26),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF388E3C)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedList<T>({
    required List<T> items,
    required Widget Function(T, int, Animation<double>) itemBuilder,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Column(
          children: List.generate(items.length, (i) {
            final animation = CurvedAnimation(
              parent: _controller,
              curve: Interval(
                (i * 0.12).clamp(0.0, 1.0),
                1.0,
                curve: Curves.easeOutBack,
              ),
            );
            return itemBuilder(items[i], i, animation);
          }),
        );
      },
    );
  }

  Widget _buildCardTile({
    required String title,
    String? subtitle,
    required String trailing,
    Color? color,
    Animation<double>? animation,
    IconData? leadingIcon,
  }) {
    return FadeTransition(
      opacity: animation ?? const AlwaysStoppedAnimation(1),
      child: SlideTransition(
        position: animation != null
            ? Tween<Offset>(begin: const Offset(0.2, 0), end: Offset.zero)
                .animate(animation)
            : const AlwaysStoppedAnimation(Offset.zero),
        child: Card(
          elevation: 6,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: leadingIcon != null
                ? Container(
                    decoration: BoxDecoration(
                      color: color?.withOpacity(0.18) ?? const Color(0xFF388E3C).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(leadingIcon, color: color ?? const Color(0xFF388E3C), size: 28),
                  )
                : null,
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: subtitle != null
                ? Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey[700], fontSize: 14),
                    ),
                  )
                : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (color ?? const Color(0xFF388E3C)).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color ?? const Color(0xFF388E3C),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color ?? Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: color ?? Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        title: const Text('Thống kê chi nhánh'),
        backgroundColor: themeColor,
        elevation: 2,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAnalyticsData,
              color: themeColor,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _buildSectionTitle('Tồn kho theo sản phẩm', Icons.inventory_2_rounded),
                  const SizedBox(height: 8),
                  stockData.isEmpty
                      ? _buildEmptyState('Không có dữ liệu tồn kho', Icons.inventory_2_rounded, color: Colors.teal)
                      : _buildAnimatedList(
                          items: stockData,
                          itemBuilder: (e, i, anim) => _buildCardTile(
                            title: e['name'],
                            trailing: '${e['quantity']} ${e['unit']}',
                            color: Colors.teal,
                            animation: anim,
                            leadingIcon: Icons.inventory_2_rounded,
                          ),
                        ),
                  const Divider(height: 36, thickness: 1.2),
                  _buildSectionTitle('Sản phẩm bán chạy', Icons.trending_up_rounded),
                  const SizedBox(height: 8),
                  topSellingProducts.isEmpty
                      ? _buildEmptyState('Chưa có sản phẩm bán chạy', Icons.trending_up_rounded, color: Colors.orange)
                      : _buildAnimatedList(
                          items: topSellingProducts,
                          itemBuilder: (e, i, anim) => _buildCardTile(
                            title: e['name'],
                            trailing: '${e['sold']} ${e['unit']}',
                            color: Colors.orange,
                            animation: anim,
                            leadingIcon: Icons.local_fire_department_rounded,
                          ),
                        ),
                  const Divider(height: 36, thickness: 1.2),
                  _buildSectionTitle('Gợi ý nhập hàng thông minh', Icons.lightbulb_rounded),
                  const SizedBox(height: 8),
                  suggestedProducts.isEmpty
                      ? _buildEmptyState('Không có gợi ý nhập hàng', Icons.lightbulb_rounded, color: Colors.amber[700])
                      : _buildAnimatedList(
                          items: suggestedProducts,
                          itemBuilder: (e, i, anim) => _buildCardTile(
                            title: e['name'],
                            subtitle: 'Lượt xem: ${e['views']}',
                            trailing: 'Tồn: ${e['quantity']} ${e['unit']}',
                            color: Colors.amber[700],
                            animation: anim,
                            leadingIcon: Icons.lightbulb_rounded,
                          ),
                        ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
