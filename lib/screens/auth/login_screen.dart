import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../customer/customer_home.dart';
import '../store/staff/dashboard_staff.dart';
import '../store/manager/dashboard_manager.dart';
import '../warehouse/warehouse_panel.dart';
import 'register_screen.dart';
import 'forgot_password.dart';
import 'package:argri_chain_app/screens/shipper/shipper_dashboard.dart';
import 'package:argri_chain_app/data/store_data.dart';
import '../farm/farm_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final emailOrPhoneController = TextEditingController();
  final passwordController = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _shakeAnim;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _showErrorAnim = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
    _shakeAnim = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.04, 0),
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_controller);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? Colors.red : Colors.green,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(msg, style: const TextStyle(fontFamily: 'Nunito'))),
          ],
        ),
        backgroundColor: error ? Colors.red[50] : Colors.green[50],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  String getStoreNameByBranch(String branchId) {
    final store = storeLocations.firstWhere(
      (item) => item['id'] == branchId,
      orElse: () => {'name': 'Không rõ'},
    );
    return store['name'];
  }
  Future<void> loginUser() async {
    final input = emailOrPhoneController.text.trim();
    final password = passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _triggerErrorAnim();
      showSnack("Vui lòng nhập đủ thông tin", error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      String email = input;

      if (!input.contains('@')) {
        final query = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: input)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          _triggerErrorAnim();
          showSnack("Không tìm thấy tài khoản với số này", error: true);
          setState(() => _isLoading = false);
          return;
        }

        email = query.docs.first['email'];
      }

      await FirebaseAuth.instance.signOut();
      final userCred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      final uid = userCred.user!.uid;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!snap.exists || snap.data() == null) {
        _triggerErrorAnim();
        showSnack("Tài khoản không hợp lệ", error: true);
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      final role = data['role'];

      String branch = 'Trung tâm';
      if (role == 'store' || role == 'shipper' || role == 'manager') {
        branch = data.containsKey('branch') ? data['branch'] : 'Không xác định';
      }

      showSnack("Đăng nhập thành công ($role)");

      if (role == 'customer') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CustomerHomeScreen()),
        );
        } else if (role == 'store') {
    final storeName = getStoreNameByBranch(branch);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StaffDashboard(
          branchId: branch,
          storeName: storeName,
        ),
      ),
    );
  } else if (role == 'manager') {
    final storeName = getStoreNameByBranch(branch);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerDashboard(
          branchId: branch,
          storeName: storeName,
        ),
      ),
    );
  } 
  else if (role == 'warehouse') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => WarehousePanel()),
        );
      } 
    else if (role == 'farm') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => FarmDashboard()),
        );
      }
  else if (role == 'shipper') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ShipperDashboard(branch: branch)),
        );
      } else {
        _triggerErrorAnim();
        showSnack("Vai trò không hợp lệ", error: true);
      }
  
    } on FirebaseAuthException catch (e) {
      _triggerErrorAnim();
      showSnack("Lỗi: ${e.message}", error: true);
    } catch (e) {
      _triggerErrorAnim();
      showSnack("Lỗi hệ thống: ${e.toString()}", error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _triggerErrorAnim() async {
    setState(() => _showErrorAnim = true);
    await _controller.reverse();
    await _controller.forward();
    setState(() => _showErrorAnim = false);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);
    final accentColor = const Color(0xFF8BC34A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Stack(
          children: [
            // Animated gradient background
            Positioned.fill(
              child: AnimatedContainer(
                duration: const Duration(seconds: 2),
                curve: Curves.easeInOut,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFe8f5e9), Color(0xFFc8e6c9), Color(0xFFf1f8e9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Decorative SVG or PNG image (replace with your asset if available)
            Positioned(
              top: 40,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedScale(
                  scale: 1.1,
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOutBack,
                ),
              ),
            ),
            // Subtle leaf icon
            Positioned(
              top: 120,
              left: 30,
              child: Icon(Icons.eco, color: accentColor.withOpacity(0.10), size: 80),
            ),
            Positioned(
              bottom: 60,
              right: 30,
              child: Icon(Icons.grass, color: themeColor.withOpacity(0.10), size: 70),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: SingleChildScrollView(
                  child: SlideTransition(
                    position: _showErrorAnim ? _shakeAnim : AlwaysStoppedAnimation(Offset.zero),
                    child: Card(
                      elevation: 22,
                      shadowColor: themeColor.withOpacity(0.18),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      color: Colors.white.withOpacity(0.98),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 36),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo with Hero animation
                            Center(
                              child: Hero(
                                tag: "logo",
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundColor: accentColor.withOpacity(0.85),
                                  child: Icon(
                                    Icons.agriculture_rounded,
                                    size: 46,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Center(
                              child: Text(
                                "AgriChain",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: themeColor,
                                  letterSpacing: 1.2,
                                  fontFamily: 'Nunito',
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                "Nền tảng chuỗi cung ứng nông nghiệp",
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey[700],
                                  fontFamily: 'Nunito',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            _CustomTextField(
                              controller: emailOrPhoneController,
                              label: "Email",
                              icon: Icons.person,
                              themeColor: themeColor,
                            ),
                            const SizedBox(height: 16),
                            _CustomTextField(
                              controller: passwordController,
                              label: "Mật khẩu",
                              icon: Icons.lock,
                              themeColor: themeColor,
                              obscureText: _obscurePassword,
                              suffix: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: themeColor,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 22),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                  shadowColor: themeColor.withOpacity(0.18),
                                  textStyle: const TextStyle(
                                    fontFamily: 'Nunito',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                  ),
                                ),
                                onPressed: _isLoading ? null : loginUser,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_isLoading)
                                      SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    else
                                      Icon(Icons.login_rounded, color: Colors.white, size: 22),
                                    const SizedBox(width: 10),
                                    Text("Đăng nhập", style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Nunito',
                                    )),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ForgotPasswordScreen()),
                                  );
                                },
                                child: Text(
                                  "Quên mật khẩu?",
                                  style: TextStyle(
                                      color: themeColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      fontFamily: 'Nunito'),
                                ),
                              ),
                            ),
                            Divider(
                              height: 30,
                              thickness: 1,
                              color: Colors.green[100],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => RegisterScreen()),
                                );
                              },
                              icon: Icon(Icons.app_registration_rounded,
                                  color: accentColor),
                              label: Text(
                                "Chưa có tài khoản? Đăng ký ngay",
                                style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    fontFamily: 'Nunito'),
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
          ],
        ),
      ),
    );
  }
}

// Custom text field for consistent style
class _CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color themeColor;
  final bool obscureText;
  final Widget? suffix;

  const _CustomTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.themeColor,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 16, fontFamily: 'Nunito'),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: themeColor.withOpacity(0.85),
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        prefixIcon: Icon(icon, color: themeColor),
        filled: true,
        fillColor: Colors.green[50],
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    );
  }
}