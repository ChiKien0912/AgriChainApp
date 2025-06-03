import 'package:argri_chain_app/screens/customer/cart/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tab/home_tab.dart';
import 'tab/orders_tab.dart';
import 'tab/profile_tab.dart';
import 'tab/qr_scanning.dart';


class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    HomeTab(),
    CartScreen(),
    OrdersTab(),
    ProductTabScreen(),
    ProfileTab(),
  ];

  final List<IconData> _icons = [
    Icons.storefront_rounded,
    Icons.shopping_cart_rounded,
    Icons.receipt_long_rounded,
    Icons.qr_code_scanner,
    Icons.person_rounded,
  ];

  final List<String> _labels = [
    "Trang chủ",
    "Giỏ hàng",
    "Đơn hàng",
    "Tra cứu QR",
    "Cá nhân",
  ];
  

  @override
  Widget build(BuildContext context) {
    Theme.of(context);
    final primaryColor = const Color(0xFF388E3C);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final inAnim = Tween<Offset>(
            begin: const Offset(0.15, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
          final outAnim = Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(-0.10, 0),
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInCubic));
          return SlideTransition(
            position: animation.status == AnimationStatus.reverse ? outAnim : inAnim,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(_currentIndex),
          child: _tabs[_currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 0,
            currentIndex: _currentIndex,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey[400],
            selectedLabelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: GoogleFonts.montserrat(
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              letterSpacing: 0.05,
            ),
            onTap: (index) => setState(() => _currentIndex = index),
            items: List.generate(_icons.length, (i) {
              final isSelected = _currentIndex == i;
              return BottomNavigationBarItem(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  margin: EdgeInsets.only(top: isSelected ? 0 : 5, bottom: isSelected ? 2 : 8),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  child: Icon(
                    _icons[i],
                    size: isSelected ? 30 : 25,
                    color: isSelected ? primaryColor : Colors.grey[400],
                    shadows: isSelected
                        ? [
                            Shadow(
                              color: primaryColor.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                ),
                label: _labels[i],
              );
            }),
          ),
        ),
      ),
    );
  }
}
