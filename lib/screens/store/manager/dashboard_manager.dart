import 'package:argri_chain_app/screens/store/common/store_order_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../common/restock_request_screen.dart';
import 'analytics_screen.dart';
import 'employees_screen.dart';
import 'add_product_screen.dart';
import 'profile_tab.dart';
import 'package:badges/badges.dart' as badges;
import 'dart:math';

class ManagerDashboard extends StatelessWidget {
  final String storeName;
  final String branchId;

  const ManagerDashboard({
    Key? key,
    required this.storeName,
    required this.branchId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
        appBar: AppBar(
          backgroundColor: theme.colorScheme.primary,
          elevation: 8,
          centerTitle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          title: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: 'Quản lý: ',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
              children: [
                TextSpan(
                  text: storeName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          bottom: TabBar(
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 4.0, color: Colors.white),
              insets: EdgeInsets.symmetric(horizontal: 40.0),
            ),
            labelStyle: (theme.textTheme.titleMedium ?? TextStyle()).copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Quản lý'),
              Tab(text: 'Hồ sơ'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const BouncingScrollPhysics(),
          children: [
            _DashboardTab(branchId: branchId, onSync: () => ensureBranchProductsExist(branchId)),
            ProfileTab(branchId: branchId),
          ],
        ),
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  final String branchId;
  final VoidCallback onSync;
  const _DashboardTab({
    Key? key,
    required this.branchId,
    required this.onSync,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<_MenuItemData> items = [
      _MenuItemData(
        label: 'Đơn hàng',
        icon: Icons.receipt_long,
        color: [Colors.blue.shade400, Colors.blue.shade100],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoreOrderScreen(branchId: branchId)),
        ),
      ),
      _MenuItemData(
        label: 'Thêm sản phẩm',
        icon: Icons.add_box,
        color: [Colors.purple.shade400, Colors.purple.shade100],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddProductScreen(branchId: branchId)),
        ),
      ),
      _MenuItemData(
        label: 'Yêu cầu nhập',
        icon: Icons.inventory,
        color: [Colors.orange.shade400, Colors.orange.shade100],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RestockRequestScreen(branchId: branchId)),
        ),
      ),
      _MenuItemData(
        label: 'Gợi ý nhập',
        icon: Icons.insights,
        color: [Colors.green.shade400, Colors.green.shade100],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnalyticsScreen(branchId: branchId)),
        ),
      ),
      _MenuItemData(
        label: 'Nhân viên',
        icon: Icons.group,
        color: [Colors.teal.shade400, Colors.teal.shade100],
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmployeesScreen(branchId: branchId)),
        ),
      ),
      _MenuItemData(
        label: 'Đồng bộ kho',
        icon: Icons.sync,
        color: [Colors.indigo.shade400, Colors.indigo.shade100],
        onTap: () async {
          onSync();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã đồng bộ tồn kho từ sản phẩm'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    ];
    for (int i = 0; i < items.length; i++) {
  final item = items[i];
  debugPrint('Item $i: '
      'label=${item.label}, '
      'icon=${item.icon}, '
      'color=${item.color}, '
      'onTap=${item.onTap}, '
      'badgeCount=${item.badgeCount}');
}
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
  theme.colorScheme.primary.withOpacity(0.13),
  (theme.colorScheme.secondary).withOpacity(0.08),
],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      
      child: GridView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 28,
          crossAxisSpacing: 28,
          childAspectRatio: 0.88,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _AnimatedMenuGridTile(data: items[i], index: i),
        
      ),
    );
  }
}


class _MenuItemData {
  final String label;
  final IconData icon;
  final List<Color> color;
  final VoidCallback onTap;
  final int? badgeCount;

  _MenuItemData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });
}

Future<void> ensureBranchProductsExist(String branchId) async {
  final productsSnap = await FirebaseFirestore.instance.collection('products').get();

  for (final doc in productsSnap.docs) {
    final productId = doc.id;
    final branchProductId = '${branchId}_$productId';
    final branchProductRef = FirebaseFirestore.instance
        .collection('branch_products')
        .doc(branchProductId);

    final exists = await branchProductRef.get();
    if (!exists.exists) {
      await branchProductRef.set({
        'branchId': branchId,
        'productId': productId,
        'quantity': Random().nextInt(20),
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    }
  }
}

class _AnimatedMenuGridTile extends StatefulWidget {
  final _MenuItemData data;
  final int index;
  const _AnimatedMenuGridTile({Key? key, required this.data, required this.index}) : super(key: key);

  @override
  State<_AnimatedMenuGridTile> createState() => _AnimatedMenuGridTileState();
}

class _AnimatedMenuGridTileState extends State<_AnimatedMenuGridTile> with TickerProviderStateMixin {
  late final AnimationController _tapController;
  late final AnimationController _entranceController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();

    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.96,
      upperBound: 1.0,
      value: 1.0,
    );

    _entranceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400 + widget.index * 70),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );

    _slideIn = Tween<Offset>(
      begin: Offset(0, 0.12 + widget.index * 0.01),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    ));

    _entranceController.forward();
  }

  @override
  void dispose() {
    _tapController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _tapController.reverse();
  void _onTapUp(_) {
    _tapController.forward();
    widget.data.onTap();
  }

  void _onTapCancel() => _tapController.forward();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: ScaleTransition(
            scale: _tapController,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.data.onTap,
                borderRadius: BorderRadius.circular(28),
                splashColor: widget.data.color.first.withOpacity(0.18),
                highlightColor: Colors.transparent,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.data.color,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: widget.data.color.first.withOpacity(0.16),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      badges.Badge(
                        showBadge: (widget.data.badgeCount ?? 0) > 0,
                        badgeContent: Text(
                          '${widget.data.badgeCount ?? 0}',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        badgeStyle: const badges.BadgeStyle(
                          badgeColor: Colors.red,
                          padding: EdgeInsets.all(7),
                        ),
                        child: Hero(
                          tag: '${widget.data.label}_${widget.index}',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: widget.data.color.first.withOpacity(0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Icon(widget.data.icon, size: 44, color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        widget.data.label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 0.2,
                            ) ??
                            const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              letterSpacing: 0.2,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}