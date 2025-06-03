import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'login_screen.dart';
import '../../data/store_data.dart'; // Thêm dòng này để import storeLocations

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  // final branchController = TextEditingController(); // Xóa dòng này
  String selectedRole = 'customer';
  PhoneNumber phoneNumber = PhoneNumber(isoCode: 'VN');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String roleCode = '';
  String? selectedBranchId; // Thêm biến này để lưu id chi nhánh

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 900));
    _fadeAnimation = CurvedAnimation(
        parent: _animationController, curve: Curves.easeInOutCubic);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCred.user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': selectedRole,
        'branch': (selectedRole != 'customer')
            ? (selectedRole == 'store' || selectedRole == 'shipper' || selectedRole == 'manager'
                ? selectedBranchId
                : null)
            : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Fluttertoast.showToast(msg: "Đăng ký thành công!");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } on FirebaseAuthException catch (e) {
      String msg = "Lỗi đăng ký";
      if (e.code == 'email-already-in-use') msg = "Email đã tồn tại.";
      else if (e.code == 'invalid-email') msg = "Email không hợp lệ.";
      else if (e.code == 'weak-password') msg = "Mật khẩu quá yếu.";
      Fluttertoast.showToast(msg: msg);
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = Color(0xFF388E3C);
    final accentColor = Color(0xFF43A047);
    final bgGradient = LinearGradient(
      colors: [Color(0xFFe0f7fa), Color(0xFFa5d6a7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: bgGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 420),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.98),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.13),
                        blurRadius: 32,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [themeColor, accentColor],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.withOpacity(0.18),
                                  blurRadius: 18,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor: Colors.transparent,
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/agri_logo.png',
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.agriculture,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 18),
                        Center(
                          child: Text(
                            "Đăng ký tài khoản",
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: themeColor,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        SizedBox(height: 28),
                        _buildLabel("Họ tên"),
                        _buildTextField(
                          controller: nameController,
                          hintText: "Nhập họ tên",
                          icon: Icons.person,
                          validator: (val) =>
                              val!.isEmpty ? 'Vui lòng nhập họ tên' : null,
                        ),
                        SizedBox(height: 16),
                        _buildLabel("Email"),
                        _buildTextField(
                          controller: emailController,
                          hintText: "Nhập email",
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              val!.isEmpty ? 'Nhập email' : null,
                        ),
                        SizedBox(height: 16),
                        _buildLabel("Số điện thoại"),
                        InternationalPhoneNumberInput(
                          onInputChanged: (PhoneNumber number) {
                            phoneNumber = number;
                            phoneController.text = number.phoneNumber ?? '';
                          },
                          initialValue: phoneNumber,
                          selectorConfig: SelectorConfig(
                            selectorType: PhoneInputSelectorType.DROPDOWN,
                          ),
                          inputDecoration: _inputDecoration(
                            hintText: "Nhập số điện thoại",
                            icon: Icons.phone,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 16),
                        _buildLabel("Mật khẩu"),
                        _buildTextField(
                          controller: passwordController,
                          hintText: "Nhập mật khẩu",
                          icon: Icons.lock,
                          obscureText: true,
                          validator: (val) =>
                              val!.length < 6 ? 'Ít nhất 6 ký tự' : null,
                        ),
                        SizedBox(height: 16),
                        _buildLabel("Chọn vai trò"),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: _inputDecoration(
                            hintText: "Chọn vai trò",
                            icon: Icons.account_circle,
                          ),
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w500,
                            color: themeColor,
                            fontSize: 16,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'customer',
                              child: Row(
                                children: [
                                  Icon(Icons.person, color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Khách hàng'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'store',
                              child: Row(
                                children: [
                                  Icon(Icons.store, color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Nhân viên cửa hàng'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'manager',
                              child: Row(
                                children: [
                                  Icon(Icons.store, color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Quản lý cửa hàng'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'warehouse',
                              child: Row(
                                children: [
                                  Icon(Icons.warehouse, color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Nhân viên kho'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'shipper',
                              child: Row(
                                children: [
                                  Icon(Icons.delivery_dining,
                                      color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Nhân viên giao hàng'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'farm',
                              child: Row(
                                children: [
                                  Icon(Icons.agriculture, color: themeColor),
                                  SizedBox(width: 8),
                                  Text('Nhân viên nông trại'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              selectedRole = val!;
                              if (selectedRole != 'store' &&
                                  selectedRole != 'shipper' && selectedRole != 'manager') {
                                selectedBranchId = null;
                              }
                            });
                          },
                        ),
                        if (selectedRole == 'store' || selectedRole == 'shipper' || selectedRole == 'manager')
                          ...[
                            SizedBox(height: 16),
                            _buildLabel("Chi nhánh làm việc"),
                            DropdownButtonFormField<String>(
                              value: selectedBranchId,
                              decoration: _inputDecoration(
                                hintText: "Chọn chi nhánh",
                                icon: Icons.location_city,
                              ),
                              items: storeLocations
                                  .map((store) => DropdownMenuItem<String>(
                                        value: store['id'],
                                        child: Text(store['name']),
                                      ))
                                  .toList(),
                              onChanged: (val) {
                                setState(() {
                                  selectedBranchId = val;
                                });
                              },
                              validator: (val) => val == null || val.isEmpty
                                  ? 'Vui lòng chọn chi nhánh'
                                  : null,
                            ),
                          ],
                        if (selectedRole != 'customer') ...[
                          SizedBox(height: 16),
                          _buildLabel("Mã xác thực"),
                          _buildTextField(
                            hintText: "Nhập mã xác thực",
                            icon: Icons.verified_user,
                            onChanged: (val) => roleCode = val.trim(),
                            validator: (val) {
                              if (selectedRole == 'store' && val != 'ST2025') {
                                return 'Sai mã xác thực cho nhân viên cửa hàng';
                              }
                             if (selectedRole == 'manager' && val != 'MN2025') {
                                return 'Sai mã xác thực cho quản lý cửa hàng';
                              }
                              if (selectedRole == 'warehouse' &&
                                  val != 'WH2025') {
                                return 'Sai mã xác thực cho nhân viên kho';
                              }
                              if (selectedRole == 'shipper' &&
                                  val != 'SP2025') {
                                return 'Sai mã xác thực cho nhân viên giao hàng';
                              }
                              if (selectedRole == 'farm' && val != 'FM2025') {
                                return 'Sai mã xác thực cho nhân viên cửa hàng';
                              }
                              return null;
                            },
                          ),
                        ],
                        SizedBox(height: 28),
                        AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 0.98 + 0.02 * _fadeAnimation.value,
                              child: child,
                            );
                          },
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              elevation: 5,
                              shadowColor: themeColor.withOpacity(0.18),
                              textStyle: TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            onPressed: registerUser,
                            icon: Icon(Icons.eco, color: Colors.white),
                            label: Text(
                              "Đăng ký",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Đã có tài khoản?",
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => LoginScreen()),
                                );
                              },
                              child: Text(
                                "Đăng nhập",
                                style: TextStyle(
                                  color: themeColor,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Montserrat',
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
          color: Color(0xFF388E3C),
          fontSize: 15.5,
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    String? hintText,
    IconData? icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontWeight: FontWeight.w500,
        fontSize: 16,
        color: Color(0xFF222222),
      ),
      decoration: _inputDecoration(
        hintText: hintText,
        icon: icon,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration({String? hintText, IconData? icon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon, color: Color(0xFF43A047)) : null,
      filled: true,
      fillColor: Color(0xFFF1F8E9),
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Color(0xFFB2DFDB), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Color(0xFFB2DFDB), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Color(0xFF388E3C), width: 1.7),
      ),
    );
  }
}
