import 'package:flutter/material.dart';
import 'receive_farm_goods.dart';
import 'stock_allocation.dart';
import 'export_to_store_screen.dart';
import 'pending_export_screen.dart';
import 'inventory_screen.dart';
import 'profile_tab.dart';
import "warehouse_forecast.dart";

class WarehousePanel extends StatefulWidget {
  const WarehousePanel({super.key});

  @override
  State<WarehousePanel> createState() => _WarehousePanelState();
}

class _WarehousePanelState extends State<WarehousePanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> items = [
    {
      'title': 'Nhập hàng từ nông trại',
      'icon': Icons.add_box,
      'screen': const ReceiveFarmGoodsScreen(),
      'color': Color(0xFF43A047),
    },
    {
      'title': 'Sắp xếp hàng lên kệ',
      'icon': Icons.view_in_ar,
      'screen': const StockAllocationScreen(),
      'color': Color(0xFF388E3C),
    },
    {
      'title': 'Xuất hàng cho cửa hàng',
      'icon': Icons.local_shipping,
      'screen': const ExportToStoreScreen(),
      'color': Color(0xFF2E7D32),
    },
    {
      'title': 'Xử lý xuất hàng',
      'icon': Icons.pending_actions,
      'screen': const PendingExportsScreen(),
      'color': Color(0xFF1B5E20),
    },
    {
      'title': 'Dữ liệu tồn kho',
      'icon': Icons.inventory,
      'screen': const InventoryScreen(),
      'color': Color(0xFF66BB6A),
    },
    {
      'title': 'Dự báo nhu cầu nhập hàng',
      'icon': Icons.forklift,
      'screen': const WarehouseForecastScreen(),
      'color': Color(0xFF66BB6A),
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          title: const Text('Kho trung tâm'),
          backgroundColor: const Color(0xFF388E3C),
          elevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white.withOpacity(0.2),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Chức năng'),
              Tab(text: 'Hồ sơ'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          physics: const BouncingScrollPhysics(),
          children: [
            // Tab 1: Các chức năng
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (_, index) {
                  final item = items[index];
                  return _AnimatedGridItem(
                    icon: item['icon'] as IconData,
                    title: item['title'] as String,
                    color: item['color'] as Color,
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => item['screen'] as Widget,
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // Tab 2: Hồ sơ
            const ProfileTab(),
          ],
        ),
      ),
    );
  }
}

class _AnimatedGridItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedGridItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedGridItem> createState() => _AnimatedGridItemState();
}

class _AnimatedGridItemState extends State<_AnimatedGridItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.95),
                  widget.color.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Icon(widget.icon, size: 40, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
