// Asked before a notebook is exported as a PDF: whether to make the
// handwriting searchable, which reads it on the device and takes a little
// longer.

import 'package:flutter/material.dart';

/// Shows the sheet. Returns whether to include searchable handwriting, or null
/// when it was dismissed without exporting.
Future<bool?> showPdfExportSheet(
  BuildContext context, {
  required bool handwriting,
  required int pageCount,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (_) =>
          _PdfExportSheet(handwriting: handwriting, pageCount: pageCount),
    );

class _PdfExportSheet extends StatefulWidget {
  final bool handwriting;
  final int pageCount;
  const _PdfExportSheet({required this.handwriting, required this.pageCount});

  @override
  State<_PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<_PdfExportSheet> {
  late bool _handwriting = widget.handwriting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = widget.pageCount == 1 ? '1 page' : '${widget.pageCount} pages';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export as PDF', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$pages, sharp at any zoom. Typed text and the text of PDF '
              'pages can be searched and copied.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('pdfExportHandwriting'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Include searchable handwriting'),
              subtitle: const Text(
                  'Reads your writing on this device so it can be found in '
                  'the PDF. Takes a little longer.'),
              value: _handwriting,
              onChanged: (v) => setState(() => _handwriting = v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('pdfExportGo'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export'),
                onPressed: () => Navigator.pop(context, _handwriting),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
