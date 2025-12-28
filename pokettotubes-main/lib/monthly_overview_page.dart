import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';
import 'package:poketto/analysis_page.dart';

class MonthlyOverviewPage extends StatefulWidget {
  const MonthlyOverviewPage({super.key});

  @override
  State<MonthlyOverviewPage> createState() => _MonthlyOverviewPageState();
}

class _MonthlyOverviewPageState extends State<MonthlyOverviewPage> {
  bool isLoading = true;
  List<MonthData> monthsData = [];
  final Set<String> _expandedMonths = {};

  @override
  void initState() {
    super.initState();
    _loadMonthlyData();
  }

  Future<void> _loadMonthlyData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      
      // Get transaksi dari 6 bulan terakhir
      final now = DateTime.now();
      List<MonthData> tempMonths = [];

      for (int i = 0; i < 6; i++) {
        final monthDate = DateTime(now.year, now.month - i, 1);
        final monthStr = DateFormat('yyyy-MM').format(monthDate);
        
        final transactions = await db.getTransactionsByMonth(userId, monthStr);
        
        if (transactions.isNotEmpty || i < 2) {
          // Tampilkan bulan ini dan bulan lalu meskipun kosong
          tempMonths.add(MonthData(
            date: monthDate,
            monthStr: monthStr,
            transactions: transactions,
          ));
        }
      }

      setState(() {
        monthsData = tempMonths;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading monthly data: $e');
      setState(() => isLoading = false);
    }
  }

  String getMonthName(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  IconData getCategoryIcon(String? categoryName) {
    if (categoryName == null) return Icons.help_outline;
    switch (categoryName.toLowerCase()) {
      case 'gaji':
      case 'bonus':
        return Icons.attach_money_rounded;
      case 'makanan':
        return Icons.restaurant_outlined;
      case 'transport':
      case 'bensin':
        return Icons.directions_car_outlined;
      case 'hiburan':
        return Icons.movie_outlined;
      case 'belanja':
        return Icons.shopping_bag_outlined;
      case 'tagihan':
        return Icons.receipt_long_outlined;
      default:
        return Icons.attach_money_rounded;
    }
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Transaksi Bulanan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            // ===== CONTENT =====
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F4F2),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(35),
                    topRight: Radius.circular(35),
                  ),
                ),
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadMonthlyData,
                        child: monthsData.isEmpty
                            ? const Center(
                                child: Text(
                                  'Belum ada transaksi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black45,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                itemCount: monthsData.length,
                                itemBuilder: (context, index) {
                                  final monthData = monthsData[index];
                                  final isExpanded = _expandedMonths.contains(monthData.monthStr);
                                  
                                  return _buildMonthItem(monthData, isExpanded);
                                },
                              ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthItem(MonthData monthData, bool isExpanded) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          // HEADER BULAN
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedMonths.remove(monthData.monthStr);
                } else {
                  _expandedMonths.add(monthData.monthStr);
                }
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                    color: Colors.black87,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      getMonthName(monthData.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // Navigate ke halaman grafik dengan bulan ini
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AnalysisPage(
                            initialMonth: monthData.date,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDEED9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Color(0xFFED8A35),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // LIST TRANSAKSI (kalau expanded)
          if (isExpanded) ...[
            const Divider(height: 1),
            monthData.transactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada transaksi',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: monthData.transactions.length,
                    itemBuilder: (context, txIndex) {
                      final tx = monthData.transactions[txIndex];
                      final isIncome = tx['category_type'] == 'income';
                      
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDEED9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                getCategoryIcon(tx['category_name']),
                                color: const Color(0xFFED8A35),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tx['category_name'] ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _formatDate(tx['date']),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFED8A35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              isIncome
                                  ? formatCurrency((tx['amount'] as num).toDouble())
                                  : "-${formatCurrency((tx['amount'] as num).toDouble())}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isIncome ? Colors.black87 : const Color(0xFFED8A35),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ],
        ],
      ),
    );
  }
}

// MODEL DATA
class MonthData {
  final DateTime date;
  final String monthStr;
  final List<Map<String, dynamic>> transactions;

  MonthData({
    required this.date,
    required this.monthStr,
    required this.transactions,
  });
}
