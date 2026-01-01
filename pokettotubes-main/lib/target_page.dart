import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';

class TargetPage extends StatefulWidget {
  const TargetPage({super.key});

  @override
  State<TargetPage> createState() => _TargetPageState();
}

class _TargetPageState extends State<TargetPage> {
  List<Map<String, dynamic>> targets = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoading = true;
  int? activeTargetId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;
    
    if (userId == null) return;
    
    try {
      final db = DatabaseHelper.instance;
      final targetList = await db.getAllTargets(userId);
      final categoryList = await db.getCategoriesByType('expense');
      
      // Get active target ID
      final activeTarget = await db.getActiveTarget(userId);
      
      setState(() {
        targets = targetList;
        categories = categoryList;
        activeTargetId = activeTarget?['budget_id'] as int?;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading targets: $e');
      setState(() => isLoading = false);
    }
  }

  // BARU: Method untuk set target aktif
  Future<void> _setActiveTarget(int budgetId) async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final db = DatabaseHelper.instance;
      
      await db.setActiveTarget(userProvider.userId!, budgetId);
      
      if (!mounted) return;
      
      setState(() {
        activeTargetId = budgetId;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Target aktif berhasil diubah'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAddTargetDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    int? selectedCategoryId;
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tambah Target Baru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Target',
                      hintText: 'Contoh: Target Liburan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<int>(
                    value: selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: 'Kategori Pengeluaran',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: categories.map((cat) {
                      return DropdownMenuItem<int>(
                        value: cat['category_id'] as int,
                        child: Text(cat['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) => setDialogState(() => selectedCategoryId = value),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Total Harga Target',
                      hintText: '5.000.000',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        final formatted = NumberFormat('#,###', 'id_ID').format(int.parse(value));
                        amountController.value = TextEditingValue(
                          text: formatted.replaceAll(',', '.'),
                          selection: TextSelection.collapsed(offset: formatted.replaceAll(',', '.').length),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tanggal Target: ${DateFormat('dd MMMM yyyy').format(endDate)}'),
                          const Icon(Icons.calendar_today),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nama target tidak boleh kosong!')),
                              );
                              return;
                            }
                            
                            if (selectedCategoryId == null || amountController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Lengkapi semua field!')),
                              );
                              return;
                            }
                            
                            final userProvider = Provider.of<UserProvider>(context, listen: false);
                            final db = DatabaseHelper.instance;
                            
                            final amount = double.parse(amountController.text.replaceAll('.', ''));
                            final startDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
                            final endDateStr = DateFormat('yyyy-MM-dd').format(endDate);
                            
                            await db.createBudget(
                              userId: userProvider.userId!,
                              name: nameController.text.trim(),
                              categoryId: selectedCategoryId!,
                              targetAmount: amount,
                              startDate: startDate,
                              endDate: endDateStr,
                            );
                            
                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Target berhasil ditambahkan!')),
                            );
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED8A35),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Simpan Target', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(int budgetId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Target?'),
        content: Text('Yakin ingin menghapus target "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              final db = DatabaseHelper.instance;
              await db.deleteTarget(budgetId);
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Target berhasil dihapus!')),
              );
              _loadData();
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
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
                  const Text('Target Keuangan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
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
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : targets.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flag_outlined, size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text('Belum ada target', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                                const SizedBox(height: 8),
                                Text('Buat target pertamamu!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: targets.length,
                            itemBuilder: (context, index) {
                              final target = targets[index];
                              final isActive = activeTargetId == target['budget_id'];
                              
                              return FutureBuilder<Map<String, dynamic>>(
                                future: DatabaseHelper.instance.getTargetProgress(
                                  Provider.of<UserProvider>(context, listen: false).userId!,
                                  target['budget_id'] as int,
                                ),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox();
                                  }
                                  
                                  final progress = snapshot.data!;
                                  final percentage = progress['percentage'] as double;
                                  final spent = progress['spent'] as double;
                                  final targetAmount = progress['target'] as double;
                                  
                                  return GestureDetector(
                                    onTap: () => _setActiveTarget(target['budget_id'] as int),
                                    child: Card(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      elevation: isActive ? 4 : 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                        side: isActive 
                                          ? const BorderSide(color: Color(0xFFED8A35), width: 2)
                                          : BorderSide.none,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Row(
                                                    children: [
                                                      if (isActive)
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFED8A35),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: const Text(
                                                            'AKTIF',
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w700,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      if (isActive) const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              target['name'] ?? 'Target',
                                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              'Kategori: ${target['category_name'] ?? '-'}',
                                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () => _showDeleteDialog(
                                                    target['budget_id'] as int,
                                                    target['name'] as String,
                                                  ),
                                                  child: const Icon(Icons.delete_outline, color: Colors.red),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  formatCurrency(spent),
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                                ),
                                                Text(
                                                  formatCurrency(targetAmount),
                                                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: percentage / 100,
                                                minHeight: 12,
                                                backgroundColor: Colors.grey[300],
                                                color: percentage >= 100 ? Colors.red : const Color(0xFFED8A35),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${percentage.toStringAsFixed(0)}% tercapai',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Sampai ${DateFormat('dd MMM yyyy').format(DateTime.parse(target['end_date'] as String))}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                            if (!isActive)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 12),
                                                child: Text(
                                                  'Tap untuk set sebagai target aktif',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ),
            
            // Add Button
            Container(
              color: const Color(0xFFF4F4F2),
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showAddTargetDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFED8A35),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('+ Tambah Target', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}