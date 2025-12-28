import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';

class AddTransactionPage extends StatefulWidget {
  final Map<String, dynamic>? transaction; // null = mode tambah, ada data = mode edit
  
  const AddTransactionPage({
    super.key,
    this.transaction,
  });

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  bool isIncome = true;
  int? selectedCategoryId;
  DateTime selectedDate = DateTime.now();
  bool isLoading = false;

  List<Map<String, dynamic>> incomeCategories = [];
  List<Map<String, dynamic>> expenseCategories = [];
  
  // Mode edit atau tambah
  bool get isEditMode => widget.transaction != null;
  
  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (isEditMode) {
      _initializeEditData();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // Inisialisasi data untuk mode edit
  void _initializeEditData() {
    final transaction = widget.transaction!;
    
    // Set amount
    final amount = transaction['amount'] as double;
    final formatter = NumberFormat('#,###', 'id_ID');
    final formatted = formatter.format(amount.toInt());
    _amountController.text = 'Rp. ${formatted.replaceAll(',', '.')}';
    
    // Set note
    _noteController.text = transaction['description'] as String? ?? '';
    
    // Set date
    final dateStr = transaction['date'] as String;
    selectedDate = DateTime.parse(dateStr);
    
    // Set category
    selectedCategoryId = transaction['category_id'] as int;
    
    // Set income/expense type
    final categoryType = transaction['category_type'] as String?;
    isIncome = categoryType == 'income';
  }

  Future<void> _loadCategories() async {
    try {
      final db = DatabaseHelper.instance;
      
      final income = await db.getCategoriesByType('income');
      final expense = await db.getCategoriesByType('expense');
      
      setState(() {
        incomeCategories = income;
        expenseCategories = expense;
        
        // Set kategori default untuk mode tambah
        if (!isEditMode) {
          if (incomeCategories.isNotEmpty) {
            selectedCategoryId = incomeCategories.first['category_id'] as int;
          }
        }
      });
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  // Simpan atau update transaksi
  Future<void> _saveTransaction() async {
    if (_amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jumlah tidak boleh kosong!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih kategori terlebih dahulu!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final amountStr = _amountController.text
          .replaceAll('Rp. ', '')
          .replaceAll('.', '')
          .trim();
      final amount = double.parse(amountStr);

      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final description = _noteController.text.isEmpty 
          ? 'Transaksi ${isIncome ? "pemasukan" : "pengeluaran"}'
          : _noteController.text;

      final db = DatabaseHelper.instance;
      int result;

      if (isEditMode) {
        // Mode edit - update transaksi
        final transactionId = widget.transaction!['transaction_id'] as int;
        result = await db.updateTransaction(
          transactionId: transactionId,
          categoryId: selectedCategoryId!,
          amount: amount,
          description: description,
          date: dateStr,
        );
      } else {
        // Mode tambah - create transaksi baru
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final userId = userProvider.userId;

        if (userId == null) {
          throw Exception('User tidak ditemukan');
        }

        result = await db.createTransaction(
          userId: userId,
          categoryId: selectedCategoryId!,
          amount: amount,
          description: description,
          date: dateStr,
        );
      }

      if (!mounted) return;

      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditMode 
                ? 'Transaksi berhasil diupdate!' 
                : 'Transaksi berhasil disimpan!'
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true untuk refresh
      } else {
        throw Exception('Gagal menyimpan transaksi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Hapus transaksi
  Future<void> _deleteTransaction() async {
    // Konfirmasi hapus
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Transaksi'),
        content: const Text('Apakah Anda yakin ingin menghapus transaksi ini?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final transactionId = widget.transaction!['transaction_id'] as int;
      
      final result = await db.deleteTransaction(transactionId);

      if (!mounted) return;

      if (result > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi berhasil dihapus!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true untuk refresh
      } else {
        throw Exception('Gagal menghapus transaksi');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _formatAmount(String value) {
    if (value.isEmpty) return;
    
    final numericValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (numericValue.isEmpty) {
      _amountController.text = '';
      return;
    }
    
    final formatter = NumberFormat('#,###', 'id_ID');
    final formatted = formatter.format(int.parse(numericValue));
    
    _amountController.value = TextEditingValue(
      text: 'Rp. ${formatted.replaceAll(',', '.')}',
      selection: TextSelection.collapsed(
        offset: 'Rp. ${formatted.replaceAll(',', '.')}'.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentCategories = isIncome ? incomeCategories : expenseCategories;

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFED8A35),
        body: SafeArea(
        child: Column(
          children: [
            // ===== HEADER =====
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 25),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditMode ? "Edit Transaksi" : "Tambah Transaksi",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  // Tombol hapus (hanya muncul di mode edit)
                  if (isEditMode)
                    GestureDetector(
                      onTap: isLoading ? null : _deleteTransaction,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ===== CONTENT CARD =====
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
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== TAB PEMASUKAN & PENGELUARAN =====
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isIncome = true;
                                if (incomeCategories.isNotEmpty) {
                                  selectedCategoryId = incomeCategories.first['category_id'] as int;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: isIncome
                                    ? const Color(0xFFED8A35)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Pemasukan",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isIncome
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                isIncome = false;
                                if (expenseCategories.isNotEmpty) {
                                  selectedCategoryId = expenseCategories.first['category_id'] as int;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 10),
                              decoration: BoxDecoration(
                                color: !isIncome
                                    ? const Color(0xFFED8A35)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "Pengeluaran",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: !isIncome
                                      ? Colors.white
                                      : Colors.black54,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 25),

                      // ===== LABEL JUMLAH =====
                      const Text(
                        "Jumlah",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ===== INPUT JUMLAH =====
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Rp. 0',
                            hintStyle: TextStyle(
                              color: Colors.black26,
                            ),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: _formatAmount,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==== DROPDOWN KATEGORI ====
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: currentCategories.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(14.0),
                                child: Text('Loading kategori...'),
                              )
                            : DropdownButtonFormField<int>(
                                value: selectedCategoryId,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.category_outlined),
                                ),
                                items: currentCategories
                                    .map(
                                      (category) => DropdownMenuItem<int>(
                                        value: category['category_id'] as int,
                                        child: Text(category['name'] as String),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => selectedCategoryId = value);
                                },
                              ),
                      ),

                      const SizedBox(height: 22),

                      // ===== INPUT TANGGAL =====
                      GestureDetector(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDate: selectedDate,
                          );
                          if (picked != null) {
                            setState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 20,
                                    color: Colors.black54,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    DateFormat('d MMMM yyyy')
                                        .format(selectedDate),
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ===== INPUT CATATAN =====
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: TextField(
                          controller: _noteController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: "Catatan (Optional)",
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ===== SIMPAN BUTTON =====
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _saveTransaction,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED8A35),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isEditMode ? "Update Transaksi" : "Simpan Transaksi",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}