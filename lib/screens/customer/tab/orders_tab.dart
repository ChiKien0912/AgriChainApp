import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../order/order_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:argri_chain_app/screens/customer/checkout/ethereum_service.dart';

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  String? userId;
  late TabController _tabController;
  final List<String> statuses = ['Đang xử lý', 'Chờ giao', 'Đang giao', 'Đã giao'];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userId = user.uid;
    }
    _tabController = TabController(length: statuses.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cancelOrder(String orderId) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': 'Đã hủy',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
     try {
    await refundOrderOnBlockchain(orderId); // Gọi smart contract
  } catch (e) {
    debugPrint('Refund failed: $e');
  }

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã hủy đơn hàng thành công!', style: GoogleFonts.montserrat()),
        backgroundColor: Colors.red[400],
      ),
    );
  }
  }

  Future<void> _showCancelDialog(String orderId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Xác nhận hủy đơn', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn hủy đơn hàng này không?', style: GoogleFonts.montserrat()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Không', style: GoogleFonts.montserrat()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Hủy đơn', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );
    if (result == true) {
      await _cancelOrder(orderId);
    }
  }

  Future<void> _showRatingDialog(String orderId) async {
    double rating = 5;
    String comment = '';
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Đánh giá đơn hàng', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return AnimatedScale(
                    scale: i < rating ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: IconButton(
                      icon: Icon(
                        i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        color: Colors.amber[700],
                        size: 32,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          rating = i + 1.0;
                        });
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Nhận xét',
                  labelStyle: GoogleFonts.montserrat(),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => comment = v,
                maxLines: 2,
                style: GoogleFonts.montserrat(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Bỏ qua', style: GoogleFonts.montserrat()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('orders')
                    .doc(orderId)
                    .update({
                  'rating': rating,
                  'review': comment,
                  'ratedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cảm ơn bạn đã đánh giá!', style: GoogleFonts.montserrat()),
                      backgroundColor: Colors.amber[700],
                    ),
                  );
                }
              },
              child: Text('Gửi', style: GoogleFonts.montserrat()),
            ),
          ],
        ),
      ),
    );
  }

  String formatCurrency(num? amount) {
    if (amount == null) return '0 ₫';
    final format = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);

    if (userId == null) {
      return Center(
        child: Text(
          "Vui lòng đăng nhập",
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          "Đơn hàng của bạn",
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Hero(
            tag: 'orders_icon',
            child: Icon(Icons.receipt_long, color: Colors.white, size: 28),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: statuses.map((s) => Tab(child: Text(s, style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, fontSize: 15)))).toList(),
              indicator: BoxDecoration(
                gradient: LinearGradient(
                  colors: [themeColor, themeColor.withOpacity(0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.18),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: themeColor,
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              splashFactory: InkRipple.splashFactory,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: statuses.map((status) {
          final orderStream = FirebaseFirestore.instance
              .collection('orders')
              .where('userId', isEqualTo: userId)
              .where('status', isEqualTo: status)
              .orderBy('timestamp', descending: true)
              .snapshots();

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Container(
              key: ValueKey(status),
              color: Colors.transparent,
              child: StreamBuilder<QuerySnapshot>(
                stream: orderStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 500),
                          child: Image.asset(
                            'assets/images/empty_box.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          "Chưa có đơn hàng nào",
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            color: Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }

                  final docs = snapshot.data!.docs;

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final order = docs[i];
                      final data = order.data() as Map<String, dynamic>;

                      // Status color
                      Color statusColor;
                      switch (data['status']) {
                        case 'Đã giao':
                          statusColor = Colors.green[700]!;
                          break;
                        case 'Đang xử lý':
                          statusColor = Colors.orange[700]!;
                          break;
                        case 'Đang giao':
                          statusColor = Colors.blue[700]!;
                          break;
                        case 'Chờ giao':
                          statusColor = const Color.fromARGB(255, 24, 196, 121);
                          break;
                        default:
                          statusColor = Colors.blueGrey;
                      }

                      return TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 420),
                        tween: Tween(begin: 0.95, end: 1.0),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) => Transform.scale(
                          scale: scale,
                          child: child,
                        ),
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => OrderDetailScreen(orderId: order.id),
                                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  },
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Hero(
                                        tag: 'order_icon_${order.id}',
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: themeColor.withOpacity(0.09),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          child: Image.asset(
                                            'assets/images/order_bag.png',
                                            width: 40,
                                            height: 40,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  "Mã đơn: ",
                                                  style: GoogleFonts.montserrat(
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                Text(
                                                  order.id.substring(0, 6).toUpperCase(),
                                                  style: GoogleFonts.montserrat(
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                    color: themeColor,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey[400]),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            if (data['address'] != null)
                                              Row(
                                                children: [
                                                  Icon(Icons.location_on_rounded, size: 18, color: themeColor.withOpacity(0.7)),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      data['address'],
                                                      style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                Icon(Icons.payments_rounded, size: 18, color: themeColor.withOpacity(0.7)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  formatCurrency(data['total']),
                                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.red[700]),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.credit_card_rounded, size: 18, color: themeColor.withOpacity(0.7)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  data['payment'] ?? 'Chưa chọn',
                                                  style: GoogleFonts.montserrat(fontSize: 14),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 5),
                                            Row(
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(milliseconds: 350),
                                                  width: 14,
                                                  height: 14,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: statusColor.withOpacity(0.18),
                                                        blurRadius: 6,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  "Trạng thái: ${data['status']}",
                                                  style: GoogleFonts.montserrat(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  AnimatedSize(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: Column(
                                      children: [
                                        if (data['status'] == 'Đang xử lý')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: Row(
                                              children: [
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.red[400],
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                    textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                                                  ),
                                                  icon: const Icon(Icons.cancel_rounded),
                                                  label: Text('Hủy đơn hàng', style: GoogleFonts.montserrat()),
                                                  onPressed: () => _showCancelDialog(order.id),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (data['status'] == 'Đã giao' && (data['rating'] == null))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: Row(
                                              children: [
                                                ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.amber[700],
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                                    textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                                                  ),
                                                  icon: const Icon(Icons.star_rounded),
                                                  label: Text('Đánh giá đơn hàng', style: GoogleFonts.montserrat()),
                                                  onPressed: () => _showRatingDialog(order.id),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (data['status'] == 'Đã giao' && data['rating'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: Row(
                                              children: [
                                                Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${data['rating']}/5',
                                                  style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
                                                ),
                                                if (data['review'] != null && data['review'].toString().isNotEmpty)
                                                  ...[
                                                    const SizedBox(width: 12),
                                                    Icon(Icons.comment_rounded, size: 18, color: Colors.grey[600]),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        data['review'],
                                                        style: GoogleFonts.montserrat(fontSize: 14, color: Colors.black87),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                              ],
                                            ),
                                          ),
                                        if (data['status'] == 'Đã hủy')
                                          Padding(
                                            padding: const EdgeInsets.only(top: 16),
                                            child: Row(
                                              children: [
                                                Icon(Icons.cancel_rounded, color: Colors.red[400]),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Đơn hàng đã bị hủy',
                                                  style: GoogleFonts.montserrat(
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
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
            ),
          );
        }).toList(),
      ),
    );
  }
}
