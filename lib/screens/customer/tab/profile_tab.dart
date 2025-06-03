import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:argri_chain_app/screens/auth/login_screen.dart';

class ProfileTab extends StatefulWidget {
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  String email = '';
  String avatarUrl = '';
  bool isLoading = true;
  bool isSaving = false;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeInOutCubic);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    loadUserData();
  }

  @override
  void dispose() {
    _animController.dispose();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> loadUserData() async {
    if (user == null) return;
    final snap = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    final data = snap.data();
    if (data != null) {
      setState(() {
        nameController.text = data['name'] ?? '';
        phoneController.text = data['phone'] ?? '';
        email = data['email'] ?? '';
        avatarUrl = data['avatar'] ?? '';
        isLoading = false;
      });
      _animController.forward();
    }
  }

  Future<void> updateProfile() async {
    if (nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập tên");
      return;
    }
    setState(() => isSaving = true);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
    });
    setState(() => isSaving = false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text("Đã cập nhật hồ sơ!", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
    Future.delayed(const Duration(milliseconds: 900), () => Navigator.pop(context));
  }

  Future<void> pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() {
        avatarUrl = picked.path;
      });
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'avatar': picked.path,
      });
    }
  }

  void logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> changePassword() async {
    TextEditingController passController = TextEditingController();
    TextEditingController confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool loading = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text("Đổi mật khẩu"),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Mật khẩu mới"),
                  validator: (v) => v == null || v.length < 6 ? "Tối thiểu 6 ký tự" : null,
                ),
                TextFormField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Nhập lại mật khẩu"),
                  validator: (v) => v != passController.text ? "Không khớp" : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setState(() => loading = true);
                      try {
                        await user?.updatePassword(passController.text.trim());
                        Fluttertoast.showToast(msg: "Đã đổi mật khẩu");
                        Navigator.pop(ctx);
                      } catch (e) {
                        Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}");
                      }
                      setState(() => loading = false);
                    },
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Xác nhận"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> sendEmailVerification() async {
    try {
      await user?.sendEmailVerification();
      Fluttertoast.showToast(msg: "Đã gửi email xác thực");
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}");
    }
  }



  void showActivityHistory() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("Lịch sử hoạt động"),
        content: const Text("Tính năng này đang được phát triển."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Đóng"),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Colors.white,
        leading: CircleAvatar(
          backgroundColor: (iconColor ?? Colors.green).withOpacity(0.13),
          child: Icon(icon, color: iconColor ?? Colors.green),
        ),
        title: Text(title, style: TextStyle(color: textColor ?? Colors.black87, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                color: Colors.white,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Article "Cá nhân"
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 19, 127, 55),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.13),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Cá nhân",
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 22,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  GestureDetector(
                                    onTap: pickAvatar,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.13),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 44,
                                        backgroundColor: Colors.white,
                                        backgroundImage: avatarUrl.isNotEmpty
                                            ? (avatarUrl.startsWith('http')
                                                ? NetworkImage(avatarUrl)
                                                : AssetImage(avatarUrl)) as ImageProvider
                                            : const AssetImage('assets/images/default_avatar.png'),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 4,
                                    right: 4,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 15,
                                      child: Icon(Icons.edit, size: 16, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              nameController.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phoneController.text,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Profile fields
                      Material(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(18),
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Column(
                            children: [
                              TextField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.person),
                                  labelText: "Tên",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.phone),
                                  labelText: "Số điện thoại",
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                enabled: false,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.email),
                                  labelText: "Email",
                                  hintText: email,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                ),
                              ),
                              const SizedBox(height: 14),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: isSaving
                                    ? const SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      )
                                    : SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                            backgroundColor: const Color.fromARGB(255, 19, 127, 55),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                          ),
                                          icon: const Icon(Icons.save),
                                          label: const Text(
                                            "Lưu thay đổi",
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          onPressed: updateProfile,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Action tiles
                      _buildActionTile(
                        icon: Icons.lock,
                        title: "Đổi mật khẩu",
                        onTap: changePassword,
                      ),
                      _buildActionTile(
                        icon: Icons.email,
                        title: "Gửi lại email xác thực",
                        onTap: sendEmailVerification,
                      ),
                      _buildActionTile(
                        icon: Icons.history,
                        title: "Lịch sử hoạt động",
                        onTap: showActivityHistory,
                      ),
                      _buildActionTile(
                        icon: Icons.logout,
                        title: "Đăng xuất",
                        iconColor: Colors.grey[700],
                        onTap: () => logout(context),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}