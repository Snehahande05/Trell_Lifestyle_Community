import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('image_utils.dart') || file.path.contains('adaptive_image.dart')) continue;
    
    String content = file.readAsStringSync();
    bool changed = false;

    if (content.contains('NetworkImage(')) {
      content = content.replaceAll(RegExp(r'NetworkImage\((.*?)\)'), r'getAdaptiveImageProvider(\1)');
      changed = true;
    }

    if (content.contains('Image.network(')) {
      content = content.replaceAll(RegExp(r'Image\.network\((.*?)\,?'), r'AdaptiveImage(imagePath: \1, ');
      changed = true;
    }

    if (changed) {
      if (!content.contains("import '../utils/image_utils.dart';") && 
          !content.contains("import 'utils/image_utils.dart';") &&
          !content.contains("import '../../utils/image_utils.dart';")) {
        // Just use a relative path that works or we can dynamically figure it out.
        // Actually, just add it at the top.
        final depth = file.path.split('/').length - 2;
        final prefix = List.filled(depth, '../').join();
        final importStr = "import '${prefix}utils/image_utils.dart';\nimport '${prefix}widgets/adaptive_image.dart';";
        content = importStr + '\n' + content;
      }
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
