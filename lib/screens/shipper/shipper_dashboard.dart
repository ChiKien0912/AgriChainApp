import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'shipper_tabs.dart';
import 'shipper_utils.dart';
import '../../data/store_data.dart';
import '../auth/login_screen.dart';

class ShipperDashboard extends StatefulWidget {
  final String branch;
  const ShipperDashboard({super.key, required this.branch});

  @override
  State<ShipperDashboard> createState() => _ShipperDashboardState();
}

class _ShipperDashboardState extends State<ShipperDashboard>
    with SingleTickerProviderStateMixin {
  final themeColor = const Color(0xFF388E3C);
  String? shipperStoreId;
  String? storeName;
  String? shippername;
  int _bottomTabIndex = 0;
  ShipperTab _currentTab = ShipperTab.delivering;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    loadShipperStoreId().then((branch) {
      if (!mounted) return;
      setState(() {
        shipperStoreId = branch;
        if (branch != null) {
          storeName = getStoreNameById(branch);
        } else {
          storeName = null;
        }
        loadShipperName();
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> loadShipperName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      setState(() {
        shippername = doc.data()?['name'] ?? "Shipper";
      });
    }
  }

  String getStoreNameById(String id) {
    final store = storeLocations.firstWhere(
      (store) => store['id'] == id,
      orElse: () => {'name': 'Không rõ chi nhánh'},
    );
    return store['name'];
  }

  Widget _buildOrderDashboard(TextTheme textTheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
            child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      _animatedTabButton("Chờ giao", ShipperTab.waiting, Icons.check_circle_rounded),
      _animatedTabButton("Đang giao", ShipperTab.delivering, Icons.delivery_dining_rounded),
      _animatedTabButton("Đã giao", ShipperTab.delivered, Icons.check_circle_rounded),
    ],
  ),
        ),
        Expanded(
          child: shipperStoreId == null
              ? const Center(child: CircularProgressIndicator())
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.1, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: buildTabContent(_currentTab, textTheme, shipperStoreId!, themeColor),
                ),
        ),
      ],
    );
  }

  Widget _animatedTabButton(String label, ShipperTab tab, IconData icon) {
    final selected = _currentTab == tab;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? themeColor.withOpacity(0.15) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: themeColor.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _currentTab = tab;
                _controller.forward(from: 0);
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: selected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(icon, color: selected ? themeColor : Colors.grey, size: 26),
                  ),
                  const SizedBox(height: 4),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: selected ? themeColor : Colors.grey,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 14,
                    ),
                    child: Text(label),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _buildProfileTab() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? "Không rõ";
    final name = shippername ?? "Shipper";
    final avatarUrl = user?.photoURL;
    final store = storeName ?? "Đang tải...";

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: ListView(
        key: ValueKey(store),
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Hero(
              tag: 'profile-avatar',
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [themeColor.withOpacity(0.7), Colors.greenAccent.shade100],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.transparent,
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl)
                      : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87),
            ),
          ),
          Center(
            child: Text(
              email,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: storeName == null
                ? Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 120,
                      height: 16,
                      color: Colors.white,
                    ),
                  )
                : AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      store,
                      style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          const SizedBox(height: 24),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _profileTile(
                  icon: Icons.info_outline,
                  color: Colors.blue,
                  title: 'Thông tin tài khoản',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Thông tin tài khoản'),
                        content: Text('Email: $email\nTên: $shippername\nChi nhánh: $store'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Đóng'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _profileTile(
                  icon: Icons.lock_outline,
                  color: Colors.orange,
                  title: 'Đổi mật khẩu',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Đổi mật khẩu'),
                        content: const Text('Một email đổi mật khẩu sẽ được gửi đến email của bạn.'),
                        actions: [
                          TextButton(
                            onPressed: () async {
                              if (user?.email != null) {
                                await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
                              }
                              if (!mounted) return;
                              Navigator.pop(context);
                            },
                            child: const Text('Gửi'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Hủy'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                _profileTile(
                  icon: Icons.settings,
                  color: Colors.grey,
                  title: 'Cài đặt',
                  onTap: () {},
                ),
                const Divider(height: 1),
                _profileTile(
                  icon: Icons.logout,
                  color: Colors.red,
                  title: "Đăng xuất",
                  onTap: () => logout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileTile({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      hoverColor: Colors.green.withOpacity(0.06),
    );
  }

  Widget _buildAppBarTitle() {
    if (storeName == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(width: 180, height: 18, color: Colors.white),
      );
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: themeColor, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shippername ?? "Shipper",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.2,
              ),
            ),
            Text(
              storeName!,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final screens = [
      _buildOrderDashboard(textTheme),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [themeColor, Colors.greenAccent.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: themeColor.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: _buildAppBarTitle(),
            centerTitle: false,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: screens[_bottomTabIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _bottomTabIndex,
          onTap: (index) => setState(() => _bottomTabIndex = index),
          selectedItemColor: themeColor,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.delivery_dining), label: "Đơn hàng"),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: "Hồ sơ"),
          ],
        ),
      ),
    );
  }
}
