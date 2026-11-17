import 'package:flutter_test/flutter_test.dart';
import 'package:margo/features/share/share_intake.dart';

void main() {
  test('nothing shared is null', () {
    expect(SharedPayload.fromMap(null), isNull);
    expect(SharedPayload.fromMap({'text': '  ', 'files': []}), isNull);
  });

  test('files are sorted by MIME type or, failing that, extension', () {
    final share = SharedPayload.fromMap({
      'files': [
        {'path': '/c/0/a.pdf', 'mimeType': '*/*', 'name': 'Lecture 3.pdf'},
        {'path': '/c/1/b', 'mimeType': 'image/jpeg', 'name': 'b'},
        {'path': '/c/2/c.docx', 'mimeType': '', 'name': 'c.docx'},
        {'mimeType': 'image/png'}, // no path: dropped
      ],
    })!;
    expect(share.files.map((f) => (f.isPdf, f.isImage)),
        [(true, false), (false, true), (false, false)]);
    expect(share.suggestedTitle, 'Lecture 3');
  });

  test('text title prefers the subject, else the first line, shortened', () {
    expect(SharedPayload.fromMap({'text': 'x', 'subject': 'Article'})!
        .suggestedTitle, 'Article');
    final long = SharedPayload.fromMap({'text': '${'a' * 50}\nrest'})!;
    expect(long.suggestedTitle, '${'a' * 40}…');
  });
}
