import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:offline_document_viewer/offline_document_viewer.dart';

class ActivityDocumentViewer extends StatelessWidget {
  final String fileName;
  final Uint8List bytes;

  const ActivityDocumentViewer({
    super.key,
    required this.fileName,
    required this.bytes,
  });

  @override
  Widget build(BuildContext context) {
    final extension = fileName.split('.').last.toLowerCase();
    final Widget document;
    if (const {'jpg', 'jpeg', 'png'}.contains(extension)) {
      document = InteractiveViewer(
        child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
      );
    } else if (extension == 'txt') {
      document = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(utf8.decode(bytes, allowMalformed: true)),
      );
    } else {
      document = DocumentView(
        source: DocumentSource.bytes(bytes, name: fileName),
      );
    }
    final isTextOnlyLegacyFormat = extension == 'doc' || extension == 'ppt';

    return Scaffold(
      appBar: AppBar(title: Text(fileName, maxLines: 1)),
      body: SafeArea(
        child: Column(
          children: [
            if (isTextOnlyLegacyFormat)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Legacy Office preview is text-only; formatting may be missing.',
                ),
              ),
            Expanded(child: document),
          ],
        ),
      ),
    );
  }
}
