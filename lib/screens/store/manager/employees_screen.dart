import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmployeesScreen extends StatefulWidget {
  final String branchId;

  const EmployeesScreen({Key? key, required this.branchId}) : super(key: key);

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String _selectedRole = 'store';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _addEmployee() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final newEmployee = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'branch': widget.branchId,
        'createdAt': FieldValue.serverTimestamp(),
      };

      try {
        await FirebaseFirestore.instance.collection('users').add(newEmployee);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thêm nhân viên thành công')),
        );
        _nameController.clear();
        _emailController.clear();
        setState(() {
          _selectedRole = 'store';
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Stream<QuerySnapshot> _employeesStream() {
    return FirebaseFirestore.instance
        .collection('users')
        .where('branch', isEqualTo: widget.branchId)
        .where('role', whereIn: ['store', 'manager'])
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Widget _buildEmployeeCard(Map<String, dynamic> employee, Animation<double> animation, int index) {
    final roleLabel = employee['role'] == 'manager'
        ? 'Quản lý chi nhánh'
        : 'Nhân viên cửa hàng';
    final color = employee['role'] == 'manager'
        ? const Color(0xFF1976D2)
        : const Color(0xFF388E3C);

    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 0.15 + 0.05 * (index % 3)),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(0.05 * index, 0.7, curve: Curves.easeOutCubic),
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: Card(
          elevation: 8,
          margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          shadowColor: color.withOpacity(0.18),
          child: ListTile(
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.13),
              child: Icon(
                employee['role'] == 'manager' ? Icons.workspace_premium_rounded : Icons.person_rounded,
                color: color,
                size: 28,
              ),
            ),
            title: Text(
              employee['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            subtitle: Text(
              employee['email'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: color.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                roleLabel,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddEmployeeForm(Color themeColor) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(22),
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Text(
                  'Thêm nhân viên mới',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: themeColor,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Tên nhân viên',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Nhập tên' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.email),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Nhập email' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  items: const [
                    DropdownMenuItem(
                      value: 'store',
                      child: Text('Nhân viên cửa hàng'),
                    ),
                    DropdownMenuItem(
                      value: 'manager',
                      child: Text('Quản lý chi nhánh'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedRole = value!);
                  },
                  decoration: InputDecoration(
                    labelText: 'Vai trò',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _isLoading ? 'Đang thêm...' : 'Thêm nhân viên',
                        style: const TextStyle(fontSize: 17),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                    onPressed: _isLoading ? null : _addEmployee,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF388E3C);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        backgroundColor: themeColor,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE8F5E9), Color(0xFFFFFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              _buildAddEmployeeForm(themeColor),
              const Divider(height: 1, thickness: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _employeesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Đã xảy ra lỗi'));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final employees = snapshot.data!.docs;

                    if (employees.isEmpty) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group_off, size: 70, color: Colors.grey[350]),
                            const SizedBox(height: 14),
                            const Text(
                              'Chưa có nhân viên nào',
                              style: TextStyle(fontSize: 17, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(top: 12, bottom: 18),
                      itemCount: employees.length,
                      itemBuilder: (context, index) {
                        final employee =
                            employees[index].data() as Map<String, dynamic>;
                        final animation = Tween<double>(begin: 0, end: 1).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: Interval(
                              0.06 * index,
                              1.0,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                        );
                        return _buildEmployeeCard(employee, animation, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
