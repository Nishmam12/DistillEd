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

  test('a shared web address becomes a card; other text stays as it is', () {
    final link = SharedPayload.fromMap({
      'text': 'https://www.example.com/cells',
      'subject': 'How cells divide',
    })!;
    expect(link.noteText,
        'How cells divide\nexample.com\nhttps://www.example.com/cells');
    expect(SharedPayload.fromMap({'text': 'https://example.com/a'})!.suggestedTitle,
        'example.com');
    final prose = SharedPayload.fromMap({'text': 'read https://example.com'})!;
    expect(prose.link, isNull);
    expect(prose.noteText, 'read https://example.com');
    expect(SharedPayload.fromMap({'text': 'javascript:alert(1)'})!.link, isNull);
  });

  test('text and Markdown files are recognised', () {
    final share = SharedPayload.fromMap({
      'files': [
        {'path': '/a', 'mimeType': 'text/plain', 'name': 'a.txt'},
        {'path': '/b', 'mimeType': 'application/octet-stream', 'name': 'b.md'},
        {'path': '/c', 'mimeType': 'image/png', 'name': 'c.png'},
      ],
    })!;
    expect(share.files.map((f) => f.isText), [true, true, false]);
  });
}
