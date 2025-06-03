import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AddProductScreen extends StatefulWidget {
  final String branchId;

  const AddProductScreen({super.key, required this.branchId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _unitController = TextEditingController();
  final _imageUrlController = TextEditingController();
  String? _selectedCategory;
  bool _isSubmitting = false;

  final List<String> _categories = ['Rau củ', 'Trái cây', 'Khác'];

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));
    _scaleAnimation = Tween<double>(begin: 0.93, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _unitController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final productRef =
          await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'unit': _unitController.text.trim(),
        'image': _imageUrlController.text.trim(),
        'category': _selectedCategory,
        'price': double.tryParse(_priceController.text.trim()) ?? 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final branchProductId = '${widget.branchId}_${productRef.id}';
      final branchProductRef = FirebaseFirestore.instance
          .collection('branch_products')
          .doc(branchProductId);

      final branchProductSnap = await branchProductRef.get();
      if (!branchProductSnap.exists) {
        await branchProductRef.set({
          'branchId': widget.branchId,
          'productId': productRef.id,
          'quantity': 0,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      }

      Fluttertoast.showToast(
        msg: 'Thêm sản phẩm thành công!',
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Lỗi: ${e.toString()}',
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF388E3C);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: const Text('Thêm sản phẩm'),
        centerTitle: true,
        backgroundColor: themeColor,
        elevation: 6,
        shadowColor: themeColor.withOpacity(0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width < 600 ? size.width * 0.98 : 480,
                ),
                child: Card(
                  elevation: 18,
                  margin: const EdgeInsets.all(22),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 36),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          _buildSectionTitle('Thông tin sản phẩm'),
                          const SizedBox(height: 10),
                          _buildTextField(_nameController, 'Tên sản phẩm',
                              Icons.eco_outlined,
                              hintText: 'Ví dụ: Dưa hấu, Xoài cát...'),
                          const SizedBox(height: 18),
                          _buildDropdownCategory(),
                          const SizedBox(height: 18),
                          _buildTextField(_descController, 'Mô tả chi tiết',
                              Icons.text_snippet_outlined,
                              hintText: 'Mô tả về xuất xứ, chất lượng...',
                              maxLines: 3),
                          const SizedBox(height: 18),
                          _buildTextField(_priceController, 'Giá (VNĐ)',
                              Icons.attach_money_rounded,
                              hintText: 'VD: 15000'),
                          const SizedBox(height: 18),
                          _buildTextField(_unitController, 'Đơn vị tính',
                              Icons.scale_rounded,
                              hintText: 'kg, bó, túi, lít...'),
                          const SizedBox(height: 18),
                          _buildTextField(_imageUrlController, 'URL Hình ảnh',
                              Icons.image_outlined,
                              hintText: 'https://...'),
                          const SizedBox(height: 32),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            child: _isSubmitting
                                ? Center(
                                    key: const ValueKey('loading'),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 8),
                                        CircularProgressIndicator(
                                          color: themeColor,
                                          strokeWidth: 3.5,
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          "Đang thêm sản phẩm...",
                                          style: TextStyle(
                                              color: Colors.black54,
                                              fontSize: 15),
                                        ),
                                      ],
                                    ),
                                  )
                                : SizedBox(
                                    key: const ValueKey('button'),
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: _submitProduct,
                                      label: const Text('Thêm sản phẩm'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: themeColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        elevation: 6,
                                        textStyle: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                        shadowColor: themeColor.withOpacity(0.2),
                                      ),
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Color(0xFF388E3C),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownCategory() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: DropdownButtonFormField<String>(
        value: _selectedCategory,
        items: _categories
            .map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat, style: const TextStyle(color: Colors.black87)),
                ))
            .toList(),
        onChanged: (val) => setState(() => _selectedCategory = val),
        validator: (val) =>
            val == null ? 'Vui lòng chọn loại nông sản' : null,
        decoration: InputDecoration(
          labelText: 'Loại nông sản',
          prefixIcon: const Icon(Icons.category_outlined),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          filled: true,
          fillColor: Colors.green[50],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        ),
        style: const TextStyle(fontSize: 17),
        dropdownColor: Colors.green[50],
        icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF388E3C)),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    String? hintText,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (val) =>
            val == null || val.trim().isEmpty ? 'Không được để trống' : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          prefixIcon: Icon(icon, color: const Color(0xFF388E3C)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB2DFDB), width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF388E3C), width: 2),
          ),
          filled: true,
          fillColor: Colors.green[50],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        ),
        style: const TextStyle(fontSize: 17),
      ),
    );
  }
}
