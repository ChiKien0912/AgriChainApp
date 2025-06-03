import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final inputController = TextEditingController();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _iconAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    );
    _iconAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.elasticOut,
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    inputController.dispose();
    super.dispose();
  }

  void handleReset() async {
    final input = inputController.text.trim();

    if (input.isEmpty || !input.contains('@')) {
      Fluttertoast.showToast(msg: "Chỉ hỗ trợ khôi phục qua email");
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: input);
      Fluttertoast.showToast(msg: "Đã gửi email đặt lại mật khẩu!");
      Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi gửi email: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF256029); // darker green
    final accentColor = const Color(0xFFFFD600); // vivid yellow
    final bgGradient = LinearGradient(
      colors: [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: bgGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 410),
                  child: Card(
                    elevation: 18,
                    shadowColor: themeColor.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Animated agriculture image
                          Center(
                            child: AnimatedBuilder(
                              animation: _iconAnim,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 0.85 + 0.15 * _iconAnim.value,
                                  child: Opacity(
                                    opacity: _iconAnim.value,
                                    child: child,
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [themeColor, themeColor.withOpacity(0.7)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: themeColor.withOpacity(0.13),
                                      blurRadius: 22,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20),
                                child: Image.asset(
                                  'assets/images/forgot_password_agri.png',
                                  width: 68,
                                  height: 68,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.agriculture_rounded,
                                    color: accentColor,
                                    size: 60,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            "Khôi phục mật khẩu",
                            style: GoogleFonts.montserrat(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: themeColor,
                              letterSpacing: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Nhập email đã đăng ký để nhận hướng dẫn đặt lại mật khẩu.",
                            style: GoogleFonts.roboto(
                              fontSize: 16,
                              color: Colors.grey[800],
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 30),
                          TextField(
                            controller: inputController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              labelText: "Email",
                              labelStyle: GoogleFonts.roboto(
                                color: themeColor.withOpacity(0.85),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8BC34A)),
                              filled: true,
                              fillColor: const Color(0xFFF4FCE3),
                              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: themeColor.withOpacity(0.4)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: accentColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                                shadowColor: themeColor.withOpacity(0.18),
                                textStyle: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onPressed: handleReset,
                              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                              label: const Text(
                                "Gửi OTP",
                                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Divider(
                            color: Colors.grey[300],
                            thickness: 1,
                            height: 24,
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.login_rounded, color: themeColor, size: 22),
                              label: Text(
                                "Quay lại đăng nhập",
                                style: GoogleFonts.roboto(
                                  color: themeColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: themeColor,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
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
        ),
      ),
    );
  }
}
