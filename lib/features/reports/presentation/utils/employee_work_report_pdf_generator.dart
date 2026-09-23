import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../employee/domain/models/employee_model.dart';
import '../../../tasks/domain/models/task_model.dart';

class EmployeeWorkReportPdfGenerator {
  static String formatMinutes(int minutes) {
    if (minutes <= 0) return '0 min';
    final hrs = minutes ~/ 60;
    final mins = minutes % 60;
    if (hrs == 0) return '$mins min';
    if (mins == 0) return '$hrs ${hrs == 1 ? "hr" : "hrs"}';
    return '$hrs ${hrs == 1 ? "hr" : "hrs"} $mins min';
  }

  static String formatTimestamp(DateTime? dt) {
    if (dt == null) return 'N/A';
    return DateFormat('HH:mm').format(dt);
  }

  static int calculateTaskDurationMinutes(TaskModel task) {
    if (task.totalTimeTakenMinutes != null && task.totalTimeTakenMinutes! > 0) {
      return task.totalTimeTakenMinutes!;
    }
    final start = task.taskStartTime;
    final end = task.actualCompletionTime ?? task.completedDate;
    if (start != null && end != null) {
      final diff = end.difference(start).inMinutes;
      return diff > 0 ? diff : 1;
    }
    return 0;
  }

  static Future<Uint8List> generatePdf({
    required String companyId,
    required EmployeeModel employee,
    required DateTime selectedMonth,
    required List<TaskModel> tasks,
  }) async {
    // 1. Fetch Company details from Firestore
    Map<String, dynamic>? companyData;
    try {
      if (companyId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('companies')
            .doc(companyId)
            .get();
        if (doc.exists) {
          companyData = doc.data();
        }
      }
    } catch (_) {}

    final companyName = (companyData?['name'] ?? companyData?['companyName'] ?? 'Company').toString();
    final companyPhone = (companyData?['phone'] ?? '').toString();
    final companyEmail = (companyData?['email'] ?? '').toString();
    final companyAddress = (companyData?['address'] ?? companyData?['fullAddress'] ?? '').toString();

    // 2. Filter completed tasks for selected month
    final completedTasks = tasks.where((t) {
      if (t.status != 'Completed') return false;
      final compDate = t.actualCompletionTime ?? t.completedDate;
      if (compDate == null) return false;
      return compDate.year == selectedMonth.year && compDate.month == selectedMonth.month;
    }).toList();

    // Sort by completion timestamp ascending
    completedTasks.sort((a, b) {
      final dateA = a.actualCompletionTime ?? a.completedDate ?? a.startDate;
      final dateB = b.actualCompletionTime ?? b.completedDate ?? b.startDate;
      return dateA.compareTo(dateB);
    });

    // 3. Group by Day
    final Map<String, List<TaskModel>> groupedByDay = {};
    final Map<String, int> dailyTotalsMinutes = {};
    int monthlyTotalMinutes = 0;

    for (final task in completedTasks) {
      final compDate = task.actualCompletionTime ?? task.completedDate ?? task.startDate;
      final dayKey = DateFormat('yyyy-MM-dd').format(compDate);
      
      groupedByDay.putIfAbsent(dayKey, () => []).add(task);
      final duration = calculateTaskDurationMinutes(task);
      dailyTotalsMinutes[dayKey] = (dailyTotalsMinutes[dayKey] ?? 0) + duration;
      monthlyTotalMinutes += duration;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          final List<pw.Widget> content = [];

          // Company Header
          content.add(
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      companyName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    if (companyAddress.isNotEmpty)
                      pw.Text(companyAddress, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    if (companyPhone.isNotEmpty || companyEmail.isNotEmpty)
                      pw.Text(
                        'Phone: $companyPhone | Email: $companyEmail',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TASK WORK REPORT',
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                    ),
                    pw.Text(
                      'Month: ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          );

          content.add(pw.SizedBox(height: 12));
          content.add(pw.Divider(thickness: 1, color: PdfColors.grey400));
          content.add(pw.SizedBox(height: 12));

          // Employee Details Card
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Employee Name: ${employee.name}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                      pw.Text('Employee ID: ${employee.employeeId}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Department: ${employee.department}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Role: ${employee.role}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Completed Tasks: ${completedTasks.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                      pw.Text('Monthly Task Working Time: ${formatMinutes(monthlyTotalMinutes)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.green800)),
                    ],
                  ),
                ],
              ),
            ),
          );

          content.add(pw.SizedBox(height: 16));

          // Task Work Breakdown Table
          if (completedTasks.isEmpty) {
            content.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                alignment: pw.Alignment.center,
                child: pw.Text(
                  'No completed task working history recorded for this month.',
                  style: pw.TextStyle(fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                ),
              ),
            );
          } else {
            // Build Table Rows
            final List<pw.TableRow> tableRows = [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue800),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Date', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Task Title', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Start Time', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Completion Time', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Time Spent', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text('Status', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
            ];

            groupedByDay.forEach((dayKey, dayTasks) {
              final dateFormatted = DateFormat('dd MMM yyyy').format(DateTime.parse(dayKey));
              final dailyTotal = dailyTotalsMinutes[dayKey] ?? 0;

              for (var i = 0; i < dayTasks.length; i++) {
                final task = dayTasks[i];
                final duration = calculateTaskDurationMinutes(task);
                final startTimeStr = formatTimestamp(task.taskStartTime);
                final compTimeStr = formatTimestamp(task.actualCompletionTime ?? task.completedDate);

                tableRows.add(
                  pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? PdfColors.white : PdfColors.grey50,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(i == 0 ? dateFormatted : '', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(task.title, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(startTimeStr, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(compTimeStr, style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(formatMinutes(duration), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.blue900)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(task.status, style: const pw.TextStyle(fontSize: 9, color: PdfColors.green800)),
                      ),
                    ],
                  ),
                );
              }

              // Subtotal Row for the day
              tableRows.add(
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('$dateFormatted Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(formatMinutes(dailyTotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.black)),
                    ),
                    pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('')),
                  ],
                ),
              );
            });

            content.add(
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: tableRows,
              ),
            );
          }

          content.add(pw.SizedBox(height: 16));

          // Monthly Total Summary Box
          content.add(
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                border: pw.Border.all(color: PdfColors.blue300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MONTHLY TOTAL WORK DURATION',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.blue900),
                  ),
                  pw.Text(
                    formatMinutes(monthlyTotalMinutes),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.blue900),
                  ),
                ],
              ),
            ),
          );

          // Disclaimer Footer
          content.add(pw.SizedBox(height: 20));
          content.add(
            pw.Text(
              'Note: Task Working Hours are calculated strictly from actual task start and completion timestamps and are independent of attendance records.',
              style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
            ),
          );

          return content;
        },
      ),
    );

    return pdf.save();
  }
}
