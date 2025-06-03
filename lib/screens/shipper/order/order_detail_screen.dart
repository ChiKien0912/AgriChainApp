import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../route/route_mapping.dart';

class ShipperOrderDetailScreen extends StatelessWidget {
  final String orderId;
  const ShipperOrderDetailScreen({required this.orderId, super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Chi tiết đơn hàng',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.green[700],
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('orders').doc(orderId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                'Không tìm thấy đơn hàng',
                style: GoogleFonts.montserrat(fontSize: 18, color: Colors.grey[700]),
              ),
            );
          }
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final items = data['items'] as List<dynamic>? ?? [];

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Padding(
              key: ValueKey(orderId),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ListView(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.green[100],
                            child: Icon(Icons.receipt_long, color: Colors.green[700], size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mã đơn: $orderId',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.green[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(
                                    data['status'] ?? '',
                                    style: GoogleFonts.montserrat(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  backgroundColor: _statusColor(data['status']),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(thickness: 1.2, color: Colors.grey[300]),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.person,
                        label: 'Khách hàng',
                        value: data['name'] ?? '',
                      ),
                      _InfoRow(
                        icon: Icons.phone,
                        label: 'SĐT',
                        value: data['phone'] ?? '',
                      ),
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'Địa chỉ',
                        value: data['address'] ?? '',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Sản phẩm',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedListView(
                        items: items,
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: AnimatedButton(
                          onPressed: () {
                            final shipperLat = data['shipperLocation']?['lat'] ?? 0.0;
                            final shipperLng = data['shipperLocation']?['lng'] ?? 0.0;
                            final destLat = data['destination']?['lat'] ?? 0.0;
                            final destLng = data['destination']?['lng'] ?? 0.0;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RouteMapScreen(
                                  shipperLat: shipperLat,
                                  shipperLng: shipperLng,
                                  destLat: destLat,
                                  destLng: destLng,
                                ),
                              ),
                            );
                          },
                          icon: Icons.map,
                          label: "Xem bản đồ đến khách",
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'Đang giao':
        return Colors.orange;
      case 'Đã giao':
        return Colors.green;
      case 'Đã hủy':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.green[700], size: 22),
          const SizedBox(width: 10),
          Text(
            '$label: ',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 15),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(fontSize: 15, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

class AnimatedListView extends StatelessWidget {
  final List<dynamic> items;
  const AnimatedListView({required this.items, super.key});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'Không có sản phẩm',
          style: GoogleFonts.montserrat(color: Colors.grey[600]),
        ),
      );
    }
    return Column(
      children: List.generate(items.length, (i) {
        final item = items[i];
   return TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.0, end: 1.0),
  duration: Duration(milliseconds: 350 + i * 70),
  curve: Curves.easeOutBack,
  builder: (context, value, child) {
    final clampedValue = value.clamp(0.0, 1.0); // NGĂN opacity lỗi
    return Opacity(
      opacity: clampedValue,
      child: Transform.translate(
        offset: Offset(0, (1 - clampedValue) * 30),
        child: child,
      ),
    );
  },
  child: Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 2,
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.green[50],
        child: Icon(Icons.shopping_bag, color: Colors.green[700]),
      ),
      title: Text(
        item['name'] ?? '',
        style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Số lượng: ${item['quantity']}',
        style: GoogleFonts.montserrat(fontSize: 13),
      ),
      trailing: Text(
        '${item['price']}đ',
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.bold,
          color: Colors.green[800],
          fontSize: 15,
        ),
      ),
    ),
  ),
);

      }),
    );
  }
}

class AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  const AnimatedButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    super.key,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();
  void _onTapUp(TapUpDetails details) => _controller.reverse();
  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green[700],
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.green.withAlpha((0.18 * 255).toInt()),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}