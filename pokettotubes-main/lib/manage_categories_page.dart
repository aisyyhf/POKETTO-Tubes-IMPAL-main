import 'package:flutter/material.dart';
import 'package:poketto/database/database_helper.dart';

class ManageCategoriesPage extends StatefulWidget {
  const ManageCategoriesPage({super.key});

  @override
  State<ManageCategoriesPage> createState() => _ManageCategoriesPageState();
}

class _ManageCategoriesPageState extends State<ManageCategoriesPage> {
  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    
    try {
      final db = DatabaseHelper.instance;
      final income = await db.getCategoriesByType('income');
      final expense = await db.getCategoriesByType('expense');
      
      if (!mounted) return;
      
      setState(() {
        _incomeCategories = income;
        _expenseCategories = expense;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showAddCategoryDialog(String type) {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Tambah Kategori ${type == 'income' ? 'Pemasukan' : 'Pengeluaran'}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nama Kategori',
              hintText: type == 'income' ? 'Contoh: Freelance' : 'Contoh: Kopi',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama kategori tidak boleh kosong';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = DatabaseHelper.instance;
                final result = await db.createCategory(
                  controller.text.trim(),
                  type,
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                
                if (result > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Kategori berhasil ditambahkan'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadCategories();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Gagal menambahkan kategori'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED8A35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(Map<String, dynamic> category) {
    final controller = TextEditingController(text: category['name'] as String);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Kategori'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nama Kategori',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama kategori tidak boleh kosong';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final db = DatabaseHelper.instance;
                final result = await db.updateCategory(
                  category['category_id'] as int,
                  controller.text.trim(),
                );
                
                if (!mounted) return;
                Navigator.pop(context);
                
                if (result > 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Kategori berhasil diupdate'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadCategories();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Gagal mengupdate kategori'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFED8A35),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog(Map<String, dynamic> category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Kategori?'),
        content: Text(
          'Yakin ingin menghapus kategori "${category['name']}"?\n\n'
          'Kategori yang masih digunakan dalam transaksi tidak dapat dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final db = DatabaseHelper.instance;
              final result = await db.deleteCategory(category['category_id'] as int);
              
              if (!mounted) return;
              Navigator.pop(context);
              
              if (result > 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✓ Kategori berhasil dihapus'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadCategories();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('❌ Kategori masih digunakan dalam transaksi'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFED8A35),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Kelola Kategori',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Income Categories
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kategori Pemasukan',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showAddCategoryDialog('income'),
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: const Color(0xFFED8A35),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._incomeCategories.map((category) => _buildCategoryItem(category)),
                            
                            const SizedBox(height: 32),
                            
                            // Expense Categories
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Kategori Pengeluaran',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _showAddCategoryDialog('expense'),
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: const Color(0xFFED8A35),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ..._expenseCategories.map((category) => _buildCategoryItem(category)),
                            
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFFDEED9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.category_outlined,
            color: Color(0xFFED8A35),
            size: 24,
          ),
        ),
        title: Text(
          category['name'] as String,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          category['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _showEditCategoryDialog(category),
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: const Color(0xFFED8A35),
            ),
            IconButton(
              onPressed: () => _showDeleteCategoryDialog(category),
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}