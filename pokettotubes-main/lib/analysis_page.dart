import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:poketto/providers/user_provider.dart';
import 'package:poketto/pdf_report_generator.dart';
import 'package:open_file/open_file.dart';

class AnalysisPage extends StatefulWidget {
  final DateTime? initialMonth;
  
  const AnalysisPage({super.key, this.initialMonth});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  late DateTime selectedMonth;
  bool isLoading = true;
  double balance = 0.0;
  List<Map<String, dynamic>> weeklyData = [];
  int? selectedPointIndex; // Track selected point

  @override
  void initState() {
    super.initState();
    selectedMonth = widget.initialMonth ?? DateTime.now();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    await initializeDateFormatting('id_ID', null);
    _loadFinancialData();
  }

  Future<void> _loadFinancialData() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final db = DatabaseHelper.instance;
      final monthStr = DateFormat('yyyy-MM').format(selectedMonth);

      // Get monthly stats
      final stats = await db.getMonthlyStats(userId, monthStr);
      
      // Get transactions untuk chart
      final transactions = await db.getTransactionsByMonth(userId, monthStr);
      
      // Process data untuk chart (per minggu)
      final weekly = _processWeeklyData(transactions);

      setState(() {
        balance = stats['balance'] ?? 0.0;
        weeklyData = weekly;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading financial data: $e');
      setState(() => isLoading = false);
    }
  }

  List<Map<String, dynamic>> _processWeeklyData(List<Map<String, dynamic>> transactions) {
    // Group transactions by week
    Map<int, double> weeklyBalance = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    
    for (var tx in transactions) {
      try {
        final date = DateTime.parse(tx['date']);
        final day = date.day;
        final week = ((day - 1) ~/ 7) + 1;
        final amount = (tx['amount'] as num).toDouble();
        final isIncome = tx['category_type'] == 'income';
        
        if (week <= 5) {
          weeklyBalance[week] = (weeklyBalance[week] ?? 0) + (isIncome ? amount : -amount);
        }
      } catch (e) {
        print('Error processing transaction: $e');
      }
    }

    // Convert to list with cumulative balance
    double cumulative = 0;
    List<Map<String, dynamic>> result = [];
    
    for (int i = 1; i <= 5; i++) {
      cumulative += weeklyBalance[i] ?? 0;
      
      // Calculate date range for this week
      final startDay = (i - 1) * 7 + 1;
      final endDay = i * 7;
      final lastDayOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
      final actualEndDay = endDay > lastDayOfMonth ? lastDayOfMonth : endDay;
      
      result.add({
        'week': i,
        'balance': cumulative,
        'label': '$startDay-$actualEndDay',
        'date': '${selectedMonth.day}/${selectedMonth.month}/${selectedMonth.year}', // For display
        'dateRange': '$startDay-$actualEndDay/${selectedMonth.month}/${selectedMonth.year}',
      });
    }
    
    return result;
  }

  String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp. ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  String getMonthName(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[date.month - 1];
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
                    "Target Keuangan",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
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
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ===== MONTH DISPLAY =====
                              Container(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${getMonthName(selectedMonth)} ${selectedMonth.year}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 25),

                              // ===== FINANCIAL ANALYSIS CARD =====
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Analisis Finansial",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "${balance >= 0 ? '+' : ''}${formatCurrency(balance)}",
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: balance >= 0 
                                            ? const Color(0xFFED8A35)
                                            : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(height: 25),

                                    // ===== CHART WITH GESTURE DETECTOR =====
                                    SizedBox(
                                      height: 160,
                                      child: weeklyData.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'Tidak ada data',
                                                style: TextStyle(
                                                  color: Colors.black38,
                                                ),
                                              ),
                                            )
                                          : GestureDetector(
                                              onTapDown: (details) {
                                                _handleChartTap(details.localPosition);
                                              },
                                              child: Stack(
                                                children: [
                                                  CustomPaint(
                                                    painter: BarChartPainter(
                                                      data: weeklyData,
                                                      maxValue: _getMaxValue(),
                                                      selectedIndex: selectedPointIndex,
                                                    ),
                                                    size: const Size(double.infinity, 160),
                                                  ),
                                                  // Tooltip overlay
                                                  if (selectedPointIndex != null)
                                                    _buildTooltip(),
                                                ],
                                              ),
                                            ),
                                    ),

                                    const SizedBox(height: 15),

                                    // ===== CHART LABELS =====
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: weeklyData.map((data) {
                                        return Text(
                                          data['label'],
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.black54,
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 30),

                              // ===== LAPORAN KEUANGAN CARD =====
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    )
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Laporan Keuangan",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      "Unduh laporan keuangan bulan ini dalam format PDF",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: _downloadReport,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFED8A35),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        child: const Text(
                                          "Unduh Laporan Bulan Ini",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleChartTap(Offset localPosition) {
    if (weeklyData.isEmpty) return;

    // Calculate which point was tapped
    final chartWidth = MediaQuery.of(context).size.width - 88; // Padding consideration
    final barWidth = chartWidth / weeklyData.length;

    for (int i = 0; i < weeklyData.length; i++) {
      final pointX = (i * barWidth) + (barWidth / 2);
      final tapX = localPosition.dx;

      // Check if tap is within range of this point
      if ((tapX - pointX).abs() < barWidth / 2) {
        setState(() {
          selectedPointIndex = selectedPointIndex == i ? null : i;
        });
        return;
      }
    }

    // If tapped outside any point, deselect
    setState(() {
      selectedPointIndex = null;
    });
  }

  Widget _buildTooltip() {
    if (selectedPointIndex == null || selectedPointIndex! >= weeklyData.length) {
      return const SizedBox.shrink();
    }

    final data = weeklyData[selectedPointIndex!];
    final balance = data['balance'] as double;
    final dateRange = data['dateRange'] as String;

    // Calculate position
    final chartWidth = MediaQuery.of(context).size.width - 88;
    final barWidth = chartWidth / weeklyData.length;
    final pointX = (selectedPointIndex! * barWidth) + (barWidth / 2);
    
    // Tooltip width
    const tooltipWidth = 120.0;
    
    // Auto-adjust horizontal position to prevent overflow
    double leftPosition;
    if (pointX < tooltipWidth / 2) {
      // Too far left - align to left edge
      leftPosition = 0;
    } else if (pointX > chartWidth - tooltipWidth / 2) {
      // Too far right - align to right edge
      leftPosition = chartWidth - tooltipWidth;
    } else {
      // Center normally
      leftPosition = pointX - (tooltipWidth / 2);
    }

    return Positioned(
      left: leftPosition,
      top: 10,
      child: Container(
        width: tooltipWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dateRange,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatCurrency(balance),
              style: const TextStyle(
                color: Color(0xFFED8A35),
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  double _getMaxValue() {
    if (weeklyData.isEmpty) return 1000000;
    
    double max = weeklyData
        .map((e) => (e['balance'] as double).abs())
        .reduce((a, b) => a > b ? a : b);
    
    return max * 1.2; // Add 20% padding
  }

  Future<void> _downloadReport() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.userId;

    if (userId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFED8A35)),
        ),
      ),
    );

    try {
      final pdfFile = await PdfReportGenerator.generateMonthlyReport(
        userId: userId,
        month: selectedMonth,
      );

      if (!mounted) return;

      // Close loading dialog
      Navigator.pop(context);

      // Open PDF
      final result = await OpenFile.open(pdfFile.path);
      
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error membuka PDF: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil dibuat! 📄'),
            backgroundColor: Color(0xFFED8A35),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat laporan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ===== CUSTOM BAR CHART PAINTER (UPDATED) =====
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final int? selectedIndex;

  BarChartPainter({
    required this.data,
    required this.maxValue,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFED8A35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    if (data.isEmpty) return;

    final barWidth = size.width / data.length;
    final chartHeight = size.height - 10;

    // Draw line chart
    final path = Path();
    bool firstPoint = true;

    for (int i = 0; i < data.length; i++) {
      final balance = data[i]['balance'] as double;
      final x = (i * barWidth) + (barWidth / 2);
      final normalizedHeight = (balance.abs() / maxValue) * chartHeight;
      final y = chartHeight - normalizedHeight;

      if (firstPoint) {
        path.moveTo(x, y);
        firstPoint = false;
      } else {
        path.lineTo(x, y);
      }

      // Draw point (larger if selected)
      final isSelected = selectedIndex == i;
      canvas.drawCircle(
        Offset(x, y),
        isSelected ? 6 : 4,
        Paint()
          ..color = const Color(0xFFED8A35)
          ..style = PaintingStyle.fill,
      );

      // Draw white border for selected point
      if (isSelected) {
        canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(BarChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex;
  }
}