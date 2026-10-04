import 'dart:io';

void main() {
  final file = File('lib/repositories/app_repository.dart');
  var content = file.readAsStringSync();
  content = content.replaceAll('https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150', 'assets/images/viewer_aanya.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150', 'assets/images/creator_priya.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150', 'assets/images/creator_rohan.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=150', 'assets/images/creator_rohan.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1586495777744-4413f21062fa?w=400', 'assets/images/product_lipstick.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1544441893-675973e31985?w=400', 'assets/images/product_jacket.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=400', 'assets/images/product_duffle.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=400', 'assets/images/product_duffle.png');
  content = content.replaceAll('https://images.unsplash.com/photo-1513519245088-0e12902e5a38?w=400', 'assets/images/product_jacket.png');
  file.writeAsStringSync(content);
}
