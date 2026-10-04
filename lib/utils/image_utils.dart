import 'dart:io';
import 'package:flutter/material.dart';

ImageProvider getAdaptiveImageProvider(String path) {
  if (path.startsWith('assets/')) {
    return AssetImage(path);
  } else if (path.startsWith('http')) {
    return NetworkImage(path);
  } else {
    final file = File(path);
    if (file.existsSync()) {
      return FileImage(file);
    }
    // Fallback placeholder
    return const AssetImage('assets/images/viewer_aanya.png');
  }
}
