import 'dart:typed_data';

import 'models.dart';

class DetectedFile {
  final DetectedFileType type;
  final String? mimeType;
  final bool isEncrypted;

  const DetectedFile(this.type, {this.mimeType, this.isEncrypted = false});
}

class FileTypeDetector {
  static DetectedFile detect({
    required String filename,
    required Uint8List bytes,
    String? mimeType,
  }) {
    final lower = filename.toLowerCase();
    final ext = lower.contains('.') ? lower.substring(lower.lastIndexOf('.') + 1) : '';

    if (_has(bytes, [0x25, 0x50, 0x44, 0x46])) {
      return const DetectedFile(DetectedFileType.pdf, mimeType: 'application/pdf');
    }
    if (_has(bytes, [0x50, 0x4b, 0x03, 0x04])) {
      if (ext == 'docx') return const DetectedFile(DetectedFileType.docx);
      if (ext == 'xlsx') return const DetectedFile(DetectedFileType.xlsx);
      if (ext == 'pptx') return const DetectedFile(DetectedFileType.pptx);
      return const DetectedFile(DetectedFileType.zipArchive);
    }
    if (_has(bytes, [0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])) {
      return const DetectedFile(DetectedFileType.legacyOffice);
    }
    if (_has(bytes, [0x52, 0x54, 0x46, 0x5c, 0x31])) {
      return const DetectedFile(DetectedFileType.rtf, mimeType: 'application/rtf');
    }

    switch (ext) {
      case 'txt':
        return const DetectedFile(DetectedFileType.plainText, mimeType: 'text/plain');
      case 'md':
        return const DetectedFile(DetectedFileType.markdown, mimeType: 'text/markdown');
      case 'json':
        return const DetectedFile(DetectedFileType.json, mimeType: 'application/json');
      case 'xml':
        return const DetectedFile(DetectedFileType.xml, mimeType: 'application/xml');
      case 'csv':
        return const DetectedFile(DetectedFileType.csv, mimeType: 'text/csv');
      case 'html':
      case 'htm':
        return const DetectedFile(DetectedFileType.html, mimeType: 'text/html');
      case 'log':
        return const DetectedFile(DetectedFileType.log, mimeType: 'text/plain');
      case 'ics':
        return const DetectedFile(DetectedFileType.ics, mimeType: 'text/calendar');
      case 'vcs':
        return const DetectedFile(DetectedFileType.vcs, mimeType: 'text/x-vcalendar');
      case 'jpg':
      case 'jpeg':
        return const DetectedFile(DetectedFileType.image, mimeType: 'image/jpeg');
      case 'png':
        return const DetectedFile(DetectedFileType.image, mimeType: 'image/png');
      case 'doc':
      case 'xls':
      case 'ppt':
        return const DetectedFile(DetectedFileType.legacyOffice);
    }

    if (mimeType?.startsWith('image/') == true) {
      return DetectedFile(DetectedFileType.image, mimeType: mimeType);
    }
    return DetectedFile(DetectedFileType.unsupported, mimeType: mimeType);
  }

  static bool _has(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }
}