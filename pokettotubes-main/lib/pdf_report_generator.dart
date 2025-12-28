import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:poketto/database/database_helper.dart';
import 'package:flutter/services.dart' show rootBundle;

class PdfReportGenerator {
  static Future<File> generateMonthlyReport({
    required int userId,
    required DateTime month,
  }) async {
    // Inisialisasi locale dulu
    await initializeDateFormatting('id_ID', null);
    
    final pdf = pw.Document();
    final db = DatabaseHelper.instance;

    // Get data
    final monthStr = DateFormat('yyyy-MM').format(month);
    final transactions = await db.getTransactionsByMonth(userId, monthStr);
    final stats = await db.getMonthlyStats(userId, monthStr);

    // Format data
    final monthName = _getMonthName(month);
    final balance = stats['balance'] ?? 0.0;
    final income = stats['income'] ?? 0.0;
    final expense = stats['expense'] ?? 0.0;

    // Process weekly data for chart
    final weeklyData = _processWeeklyData(transactions);

    // Load logo
    pw.ImageProvider? logoImage;
    try {
      print('🔍 Mencoba load logo dari: assets/cat_pixel.png');
      final logoData = await rootBundle.load('assets/cat_pixel.png');
      final logoBytes = logoData.buffer.asUint8List();
      logoImage = pw.MemoryImage(logoBytes);
      print('✅ Logo berhasil di-load! Size: ${logoBytes.length} bytes');
    } catch (e) {
      print('❌ Logo tidak ditemukan: $e');
      print('📝 Pastikan assets/cat_pixel.png ada di pubspec.yaml');
      logoImage = null;
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Row(
                children: [
                  // Logo
                  logoImage != null
                      ? pw.Container(
                          width: 40,
                          height: 40,
                          child: pw.Image(logoImage),
                        )
                      : pw.Container(
                          width: 40,
                          height: 40,
                          decoration: pw.BoxDecoration(
                            color: PdfColor.fromHex('#ED8A35'),
                            borderRadius: pw.BorderRadius.circular(8),
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              'P',
                              style: pw.TextStyle(
                                fontSize: 28,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                  pw.SizedBox(width: 12),
                  pw.Text(
                    'POKETTO',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#ED8A35'),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),

              // TITLE
              pw.Text(
                'Laporan Keuangan',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Periode: $monthName',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 24),

              // TABLE
              _buildTransactionTable(transactions),
              pw.SizedBox(height: 30),

              // CHART SECTION
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${balance >= 0 ? '+' : ''}${_formatCurrency(balance)}',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: balance >= 0
                            ? PdfColor.fromHex('#ED8A35')
                            : PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(height: 20),
                    _buildChart(weeklyData),
                    pw.SizedBox(height: 10),
                    // Chart labels
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: weeklyData.map((data) {
                        return pw.Text(
                          data['label'],
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // FOOTER
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Pemasukan: ${_formatCurrency(income)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Total Pengeluaran: ${_formatCurrency(expense)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Dibuat pada: ${_formatDateTime(DateTime.now())}',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          );
        },
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final fileName = 'Laporan_${monthName.replaceAll(' ', '_')}.pdf';
    final file = File('${output.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  static pw.Widget _buildTransactionTable(List<Map<String, dynamic>> transactions) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(0.8),
        1: const pw.FlexColumnWidth(1.5),
        2: const pw.FlexColumnWidth(2.5),
        3: const pw.FlexColumnWidth(2),
        4: const pw.FlexColumnWidth(2),
        5: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#ED8A35'),
          ),
          children: [
            _tableCell('No', isHeader: true),
            _tableCell('Tanggal', isHeader: true),
            _tableCell('Jenis Transaksi', isHeader: true),
            _tableCell('Pemasukan', isHeader: true),
            _tableCell('Pengeluaran', isHeader: true),
            _tableCell('Saldo', isHeader: true),
          ],
        ),
        // Rows
        ...transactions.asMap().entries.map((entry) {
          final index = entry.key;
          final tx = entry.value;
          final isIncome = tx['category_type'] == 'income';
          final amount = (tx['amount'] as num).toDouble();

          // Calculate running balance
          double runningBalance = 0;
          for (int i = 0; i <= index; i++) {
            final t = transactions[i];
            final amt = (t['amount'] as num).toDouble();
            if (t['category_type'] == 'income') {
              runningBalance += amt;
            } else {
              runningBalance -= amt;
            }
          }

          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
            ),
            children: [
              _tableCell('${index + 1}'),
              _tableCell(_formatDateShort(tx['date'])),
              _tableCell(tx['category_name'] ?? 'Unknown'),
              _tableCell(isIncome ? _formatCurrency(amount) : 'Rp -'),
              _tableCell(!isIncome ? _formatCurrency(amount) : 'Rp -'),
              _tableCell(_formatCurrency(runningBalance)),
            ],
          );
        }).toList(),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.black,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildChart(List<Map<String, dynamic>> weeklyData) {
    if (weeklyData.isEmpty) {
      return pw.Container(
        height: 120,
        child: pw.Center(
          child: pw.Text('Tidak ada data'),
        ),
      );
    }

    // Cari nilai ekstrem untuk scaling yang benar
    final balances = weeklyData.map((e) => e['balance'] as double).toList();
    final maxAbs = balances.map((e) => e.abs()).reduce((a, b) => a > b ? a : b);
    final maxValue = maxAbs * 1.2; // beri ruang ekstra

    const chartWidth = 500.0;
    const chartHeight = 120.0;
    final centerY = chartHeight / 2; // garis nol di tengah

    return pw.Container(
      height: chartHeight,
      width: chartWidth,
      child: pw.CustomPaint(
        size: const PdfPoint(chartWidth, chartHeight),
        painter: (PdfGraphics canvas, PdfPoint size) {
          final paint = PdfColor.fromHex('#ED8A35');
          final barWidth = size.x / weeklyData.length;

          // Garis tengah (nol) sebagai referensi
          canvas
            ..setColor(PdfColors.grey400)
            ..setLineWidth(1)
            ..drawLine(0, centerY, size.x, centerY)
            ..strokePath();

          // Gambar garis antar titik
          for (int i = 0; i < weeklyData.length - 1; i++) {
            final balance1 = weeklyData[i]['balance'] as double;
            final balance2 = weeklyData[i + 1]['balance'] as double;

            final x1 = (i * barWidth) + (barWidth / 2);
            final x2 = ((i + 1) * barWidth) + (barWidth / 2);

            // PERBAIKAN: pakai + agar saldo positif naik ke atas (karena Y PDF dari atas ke bawah)
            final y1 = centerY + (balance1 / maxValue) * (chartHeight / 2);
            final y2 = centerY + (balance2 / maxValue) * (chartHeight / 2);

            canvas
              ..setColor(paint)
              ..setLineWidth(3)
              ..drawLine(x1, y1, x2, y2)
              ..strokePath();
          }

          // Gambar titik-titik
          for (int i = 0; i < weeklyData.length; i++) {
            final balance = weeklyData[i]['balance'] as double;
            final x = (i * barWidth) + (barWidth / 2);
            final y = centerY + (balance / maxValue) * (chartHeight / 2);

            // Lingkaran oranye
            canvas
              ..setColor(paint)
              ..drawEllipse(x - 5, y - 5, 10, 10)
              ..fillPath();

            // Lingkaran putih di tengah agar lebih tebal dan mirip app
            canvas
              ..setColor(PdfColors.white)
              ..drawEllipse(x - 3, y - 3, 6, 6)
              ..fillPath();
          }
        },
      ),
    );
  }

  static List<Map<String, dynamic>> _processWeeklyData(
      List<Map<String, dynamic>> transactions) {

    // Sort transactions ASCENDING by date
    final sortedTransactions = List<Map<String, dynamic>>.from(transactions);
    sortedTransactions.sort((a, b) {
      try {
        return DateTime.parse(a['date'])
            .compareTo(DateTime.parse(b['date']));
      } catch (_) {
        return 0;
      }
    });

    Map<int, double> weeklyLastBalance = {};
    double runningBalance = 0;

    for (var tx in sortedTransactions) {
      try {
        final date = DateTime.parse(tx['date']);
        final week = ((date.day - 1) ~/ 7) + 1;
        final amount = (tx['amount'] as num).toDouble();
        final isIncome = tx['category_type'] == 'income';

        runningBalance += isIncome ? amount : -amount;

        if (week <= 5) {
          weeklyLastBalance[week] = runningBalance;
        }
      } catch (e) {
        print('Error processing transaction: $e');
      }
    }

    List<Map<String, dynamic>> result = [];
    double lastKnownBalance = 0;

    for (int i = 1; i <= 5; i++) {
      if (weeklyLastBalance.containsKey(i)) {
        lastKnownBalance = weeklyLastBalance[i]!;
      }

      String endDay = (i * 7 > 31) ? '31' : '${i * 7}';
      if (i == 5) endDay = '31'; // Desember punya 31 hari

      result.add({
        'week': i,
        'balance': lastKnownBalance,
        'label': '${(i - 1) * 7 + 1}-$endDay',
      });
    }

    print('📊 Weekly data for chart:');
    for (var d in result) {
      print('Week ${d['week']}: ${d['balance']} -> ${d['label']}');
    }

    return result;
  }

  static String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  static String _formatDateShort(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  static String _formatDateTime(DateTime date) {
    try {
      return DateFormat('dd MMMM yyyy HH:mm', 'id_ID').format(date);
    } catch (e) {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  static String _getMonthName(DateTime date) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}