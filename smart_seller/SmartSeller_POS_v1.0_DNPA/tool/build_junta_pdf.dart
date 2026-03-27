// Genera PDF desde docs/DOCUMENTACION_TECNICA_JUNTA_SMART_SELLER.md
// Uso (desde la carpeta del proyecto): dart run tool/build_junta_pdf.dart

import 'dart:convert';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

String _clean(String s) {
  return s
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!)
      .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
}

bool _isTableSep(String line) {
  final t = line.replaceAll('|', '').replaceAll('-', '').replaceAll(' ', '');
  return t.isEmpty;
}

Future<void> main() async {
  final root = Directory.current.path;
  final mdPath = p.join(root, 'docs', 'DOCUMENTACION_TECNICA_JUNTA_SMART_SELLER.md');
  final outPath = p.join(root, 'docs', 'DOCUMENTACION_TECNICA_JUNTA_SMART_SELLER.pdf');

  final mdFile = File(mdPath);
  if (!await mdFile.exists()) {
    stderr.writeln('No se encuentra: $mdPath');
    exit(1);
  }

  final content = await mdFile.readAsString(encoding: utf8);
  final lines = content.split('\n');

  final widgets = <pw.Widget>[];
  var i = 0;
  var inCode = false;
  final codeBuf = StringBuffer();

  pw.Widget bulletLine(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('• ', style: pw.TextStyle(fontSize: 10)),
          pw.Expanded(
            child: pw.Text(_clean(text), style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  while (i < lines.length) {
    var line = lines[i];
    if (line.trim().startsWith('```')) {
      if (!inCode) {
        inCode = true;
        codeBuf.clear();
      } else {
        inCode = false;
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(8),
            margin: const pw.EdgeInsets.only(bottom: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Text(
              codeBuf.toString().trimRight(),
              style: pw.TextStyle(fontSize: 8, font: pw.Font.courier()),
            ),
          ),
        );
      }
      i++;
      continue;
    }
    if (inCode) {
      codeBuf.writeln(line);
      i++;
      continue;
    }

    if (line.startsWith('# ')) {
      widgets.add(pw.SizedBox(height: 8));
      widgets.add(
        pw.Text(
          _clean(line.substring(2)),
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 6));
      i++;
      continue;
    }
    if (line.startsWith('## ')) {
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(
        pw.Text(
          _clean(line.substring(3)),
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 4));
      i++;
      continue;
    }
    if (line.startsWith('### ')) {
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(
        pw.Text(
          _clean(line.substring(4)),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
      );
      widgets.add(pw.SizedBox(height: 3));
      i++;
      continue;
    }

    if (line.trim().startsWith('|') && line.contains('|')) {
      final tableLines = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          lines[i].trim().startsWith('|')) {
        final raw = lines[i];
        if (!_isTableSep(raw)) {
          tableLines.add(raw);
        }
        i++;
      }
      if (tableLines.isNotEmpty) {
        final rows = tableLines.map((l) {
          return l
              .split('|')
              .map((c) => _clean(c.trim()))
              .where((c) => c.isNotEmpty)
              .toList();
        }).toList();
        if (rows.isNotEmpty) {
          final headers = rows.first;
          final data = rows.length > 1 ? rows.sublist(1) : <List<String>>[];
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Table.fromTextArray(
                headers: headers,
                data: data,
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(4),
                border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
              ),
            ),
          );
        }
      }
      continue;
    }

    if (line.trim() == '---') {
      i++;
      continue;
    }
    if (line.trim().isEmpty) {
      i++;
      continue;
    }
    if (line.startsWith('> ')) {
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 6),
          padding: const pw.EdgeInsets.only(left: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: PdfColors.grey700, width: 3)),
          ),
          child: pw.Text(
            _clean(line.substring(2)),
            style: pw.TextStyle(
              fontSize: 9,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey800,
            ),
          ),
        ),
      );
      i++;
      continue;
    }
    if (line.startsWith('- ')) {
      widgets.add(bulletLine(line.substring(2)));
      i++;
      continue;
    }
    if (RegExp(r'^\d+\.\s').hasMatch(line)) {
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 4, bottom: 4),
          child: pw.Text(_clean(line), style: const pw.TextStyle(fontSize: 10)),
        ),
      );
      i++;
      continue;
    }

    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Text(_clean(line), style: const pw.TextStyle(fontSize: 10)),
      ),
    );
    i++;
  }

  final pdf = pw.Document(
    author: 'Smart Seller',
    title: 'Documentación técnica — Junta',
    creator: 'tool/build_junta_pdf.dart',
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(48),
      build: (context) => [
        pw.Header(
          level: 0,
          child: pw.Text(
            'Smart Seller POS — Documentación técnica (DNPA)',
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 12),
        ...widgets,
      ],
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generado: ${DateTime.now().toIso8601String().split('T').first}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Pág. ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    ),
  );

  final bytes = await pdf.save();
  await File(outPath).writeAsBytes(bytes);
  stdout.writeln('PDF generado: $outPath');
}
