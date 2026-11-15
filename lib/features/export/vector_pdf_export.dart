// Turns a notebook (or a selection) into a vector PDF with searchable text.
//
// Here, on the UI isolate: what needs the Flutter engine or the device. Pages
// are sized, text boxes laid out (and Bangla ones drawn, since the PDF fonts
// cannot shape it), picture files read, the stored words of page pictures and
// (if asked) the handwriting placed as invisible text. Then the document is put
// together off the UI isolate by `vector_pdf_writer.dart`.

import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import '../../core/constants/storage_paths.dart';
import '../../domain/geometry/word_geometry.dart';
import '../../domain/model/page_size.dart';
import '../../domain/model/page_words.dart';
import '../../domain/model/scene_element.dart';
import '../../domain/model/template_type.dart';
import '../../editor/render/pdf_export_plan.dart';
import '../../editor/render/scene_exporter.dart';
import '../../editor/render/vector_pdf_writer.dart';
import '../../editor/state/page_notifier.dart' show templateForPage;
import '../home/domain/models/note_page.dart';
import '../home/domain/models/notebook.dart';
import '../import/page_words_service.dart';

/// A line of handwriting as the on-device reader saw it.
typedef ReadInkLine = ({String text, Rect bounds});

/// Reads the handwriting of a page's elements, one entry per written line.
typedef HandwritingReader = Future<List<ReadInkLine>> Function(
    List<SceneElement> elements);

/// The three fonts the PDF embeds.
typedef PdfFonts = ({Uint8List regular, Uint8List bold, Uint8List bengali});

class VectorPdfExport {
  VectorPdfExport({
    required this.docsDir,
    this.words,
    this.fonts,
    this.background = true,
    this.compress = true,
  });

  /// Where relative picture paths point.
  final String docsDir;

  /// The kept words of page pictures; never used to read a picture.
  final PageWordsService? words;

  /// Off the UI isolate (false in widget tests, which have no real isolates).
  final bool background;
  final bool compress;

  /// Loaded from the app's assets on first use when not given.
  PdfFonts? fonts;

  static Future<PdfFonts> loadFonts() async {
    Future<Uint8List> load(String name) async =>
        (await rootBundle.load('assets/fonts/pdf/$name')).buffer.asUint8List();
    return (
      regular: await load('NotoSans-Regular.ttf'),
      bold: await load('NotoSans-Bold.ttf'),
      bengali: await load('NotoSansBengali-Regular.ttf'),
    );
  }

  /// Every page of a notebook, in order. Empty pages stay as blank pages so
  /// the numbering matches. Null when every page is empty and there is no
  /// paper size to keep them at.
  ///
  /// [readHandwriting], when given, makes the handwriting searchable.
  /// [onStatus] hears what is happening, for a progress line.
  Future<Uint8List?> notebook({
    required List<NotePage> pages,
    required List<List<SceneElement>> scenes,
    required Notebook? notebook,
    HandwritingReader? readHandwriting,
    void Function(String status)? onStatus,
  }) async {
    if (pages.isEmpty || scenes.length != pages.length) return null;
    final sheets = notebookSheets(scenes, notebook);
    if (sheets == null) return null;

    final notebookTemplate = _template(notebook?.templateIndex ?? 0);
    final background = notebook?.backgroundColor ?? 0xFFFFFFFF;
    final plans = <PdfPagePlan>[];
    for (var i = 0; i < pages.length; i++) {
      final hidden = <PdfHiddenText>[];
      if (readHandwriting != null &&
          scenes[i].any((e) => e is FreehandElement && !e.isEraser)) {
        onStatus?.call(
            'Reading handwriting on page ${i + 1} of ${pages.length}…');
        try {
          for (final line in await readHandwriting(scenes[i])) {
            if (line.text.trim().isNotEmpty) {
              hidden.add(PdfHiddenText(line.text, line.bounds));
            }
          }
        } catch (_) {
          // A page the reader cannot read is still exported, just not
          // searchable by its handwriting.
        }
      }
      plans.add(await _plan(
        scenes[i],
        sheet: sheets.rects[i],
        bounded: sheets.bounded,
        background: background,
        template: templateForPage(pages[i], notebookTemplate),
        hidden: hidden,
      ));
    }
    onStatus?.call('Building the PDF…');
    return _write(plans, scenes);
  }

  /// [elements] (a selection, or one page) on a page sized to them.
  Future<Uint8List?> selection(
    List<SceneElement> elements, {
    int background = 0xFFFFFFFF,
  }) async {
    final box = SceneExporter.contentBounds(elements);
    if (box == null) return null;
    final plan = await _plan(elements,
        sheet: box,
        bounded: false,
        background: background,
        template: TemplateType.blank,
        hidden: const []);
    return _write([plan], [elements]);
  }

  /// The part of the scene each page of the PDF shows. A notebook laid out on
  /// real paper (A4, Letter…) uses that paper for every page. Otherwise every
  /// page is the largest content box in the notebook, centred on its own
  /// content, so a document of differing pages still prints evenly and nothing
  /// is scaled. Null when there is no paper size and every page is empty.
  static ({List<Rect> rects, bool bounded})? notebookSheets(
    List<List<SceneElement>> scenes,
    Notebook? notebook,
  ) {
    final paper = (notebook?.layoutMode ?? 0) == 0
        ? null
        : PageSizeKind.fromIndex(notebook?.pageSize ?? 0).size;
    if (paper != null) {
      return (
        rects: [for (final _ in scenes) Offset.zero & paper],
        bounded: true,
      );
    }
    final boxes = [for (final s in scenes) SceneExporter.contentBounds(s)];
    var w = 0.0, h = 0.0;
    for (final b in boxes) {
      if (b == null) continue;
      w = math.max(w, b.width);
      h = math.max(h, b.height);
    }
    if (w <= 0 || h <= 0) return null;
    return (
      rects: [
        for (final b in boxes)
          b == null
              ? Offset.zero & Size(w, h)
              : Rect.fromCenter(center: b.center, width: w, height: h),
      ],
      bounded: false,
    );
  }

  Future<PdfPagePlan> _plan(
    List<SceneElement> elements, {
    required Rect sheet,
    required bool bounded,
    required int background,
    required TemplateType template,
    required List<PdfHiddenText> hidden,
  }) async {
    final byId = {for (final e in elements) e.id: e};
    final texts = <String, PdfTextBlock>{};
    final raster = <String, PdfRasterText>{};
    final invisible = <PdfHiddenText>[...hidden];
    for (final e in elements) {
      switch (e) {
        case TextElement() when e.text.isNotEmpty:
          if (needsShaping(e.text)) {
            final drawn = await _drawText(e);
            if (drawn != null) raster[e.id] = drawn;
          } else if (planTextBlock(e, byId) case final block?) {
            texts[e.id] = block;
          }
        case ImageElement():
          final kept = await words?.storedWordsFor(e.relativeImagePath);
          for (final PageWord w in kept?.words ?? const <PageWord>[]) {
            final corners = cornersOnPage(w.box, e);
            var box = Rect.fromPoints(corners[0], corners[2]);
            for (final c in corners) {
              box = box.expandToInclude(Rect.fromPoints(c, c));
            }
            invisible.add(PdfHiddenText(w.text, box));
          }
        default:
          break;
      }
    }
    return PdfPagePlan(
      sheet: sheet,
      bounded: bounded,
      background: background,
      template: template,
      elements: elements,
      texts: texts,
      rasterTexts: raster,
      hidden: invisible,
    );
  }

  /// A text box the PDF fonts cannot shape, drawn by Flutter at three times
  /// its size so it stays sharp when zoomed.
  Future<PdfRasterText?> _drawText(TextElement e) async {
    final rect = SceneExporter.contentBounds([e], padding: 0);
    if (rect == null) return null;
    final png = await SceneExporter.toPng([e],
        background: const Color(0x00000000), scale: 3, padding: 0);
    return png == null ? null : PdfRasterText(png, rect);
  }

  Future<Uint8List> _write(
      List<PdfPagePlan> plans, List<List<SceneElement>> scenes) async {
    final images = <String, Uint8List>{};
    for (final scene in scenes) {
      for (final e in scene) {
        if (e is! ImageElement || images.containsKey(e.relativeImagePath)) {
          continue;
        }
        final bytes = await _readImage(e.relativeImagePath);
        if (bytes != null) images[e.relativeImagePath] = bytes;
      }
    }
    final fonts = this.fonts ??= await loadFonts();
    final job = PdfExportJob(
      pages: plans,
      images: images,
      regularFont: fonts.regular,
      boldFont: fonts.bold,
      bengaliFont: fonts.bengali,
      compress: compress,
    );
    return background
        ? Isolate.run(() => writeVectorPdf(job))
        : writeVectorPdf(job);
  }

  Future<Uint8List?> _readImage(String rel) async {
    if (!StoragePaths.isSafeRelativePath(rel)) return null;
    final file = File('$docsDir/$rel');
    try {
      return await file.exists() ? await file.readAsBytes() : null;
    } catch (_) {
      return null;
    }
  }

  static TemplateType _template(int i) =>
      i >= 0 && i < TemplateType.values.length
          ? TemplateType.values[i]
          : TemplateType.blank;
}
