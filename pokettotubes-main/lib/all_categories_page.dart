import 'package:flutter/material.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/folder_detail_page.dart';
import 'package:poketto/providers/user_provider.dart';
import 'package:poketto/manage_categories_page.dart';
import 'package:provider/provider.dart';

/// Halaman untuk menampilkan daftar semua kategori yang telah dibuat oleh pengguna.
class AllCategoriesPage extends StatefulWidget {
  const AllCategoriesPage({super.key});

  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
  List<Map<String, dynamic>> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Mengambil semua data kategori (folder) dari database untuk pengguna yang sedang login.
  Future<void> _loadCategories() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    if (userId == null) return;

    setState(() => _isLoading = true);
    
    try {
      final db = DatabaseHelper.instance;
      final folderList = await db.getFoldersByUser(userId);

      // FIXED: Check mounted before setState
      if (!mounted) return;
      
      setState(() {
        _folders = folderList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading categories: $e');
      
      // FIXED: Check mounted before setState
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      // FIXED: Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading categories: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Semua Kategori'),
        backgroundColor: const Color(0xFFED8A35),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageCategoriesPage(),
                ),
              );
              // Reload after returning from manage categories
              if (!mounted) return;
              _loadCategories();
            },
            tooltip: 'Kelola Kategori Transaksi',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: _folders.isEmpty
                  ? _buildEmptyState()
                  : _buildCategoryList(),
            ),
    );
  }

  /// Membangun tampilan daftar (ListView) untuk semua kategori.
  Widget _buildCategoryList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _folders.length,
      itemBuilder: (context, index) {
        final folder = _folders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            leading: const Icon(Icons.folder_open_rounded, color: Color(0xFFED8A35)),
            title: Text(folder['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${folder['transaction_count']} items'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              // FIXED: Await navigation and check mounted
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FolderDetailPage(
                    folderId: folder['folder_id'] as int,
                    folderName: folder['name'] as String,
                  ),
                ),
              );
              
              // FIXED: Check mounted before reload
              if (!mounted) return;
              
              // Muat ulang data saat kembali dari halaman detail
              _loadCategories();
            },
          ),
        );
      },
    );
  }

  /// Membangun widget yang akan ditampilkan saat tidak ada kategori yang dibuat.
  Widget _buildEmptyState() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.create_new_folder_outlined, size: 64, color: Colors.black26),
              SizedBox(height: 16),
              Text(
                'Belum ada kategori yang dibuat',
                style: TextStyle(fontSize: 16, color: Colors.black45),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Buat kategori untuk mengelompokkan transaksi Anda',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}