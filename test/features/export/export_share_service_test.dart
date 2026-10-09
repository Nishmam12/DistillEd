import 'package:flutter_test/flutter_test.dart';
import 'package:distill_ed/features/export/export_share_service.dart';

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

  group('export file names', () {
    test('a long title is shortened so the name fits a file system', () {
      final name = ExportShareService.fileName('x' * 400, 1234, 'png');

      expect(name.length, lessThan(120));
      expect(name, endsWith('_1234.png'),
          reason: 'the extension is what the share target needs, so it stays');
    });

    test('a short title is kept whole', () {
      expect(ExportShareService.fileName('Biology', 7, 'pdf'), 'Biology_7.pdf');
    });

    test('a title cannot put the file outside the export folder', () {
      final name = ExportShareService.fileName('../../etc/passwd', 1, 'png');

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains('..')));
    });

    test('an empty title still gives a usable name', () {
      expect(ExportShareService.fileName('', 1, 'png'), 'export_1.png');
    });
  });
}
