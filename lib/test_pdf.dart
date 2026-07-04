import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  try {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) {
      return pw.TableHelper.fromTextArray(
        headers: ['1', '2'],
        data: [['A', 'B']],
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerRight},
      );
    }));
    pdf.save();
    print('Success');
  } catch (e) {
    print('Error: $e');
  }
}
