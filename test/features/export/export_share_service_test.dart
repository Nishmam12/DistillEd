import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/export/export_share_service.dart';

void main() {
  test('a notebook title cannot reach outside the export folder', () {
    expect(ExportShareService.safeFilename('../../etc/passwd_1.png'),
        isNot(contains('/')));
    expect(ExportShareService.safeFilename('../x.png'), isNot(contains('..')));
    expect(ExportShareService.safeFilename(r'a\b:c*?.pdf'), 'a_b_c__.pdf');
  });

  test('an ordinary title is kept', () {
    expect(ExportShareService.safeFilename('Organic Chemistry_17.pdf'),
        'Organic Chemistry_17.pdf');
    expect(ExportShareService.safeFilename('   '), 'export');
  });
}
