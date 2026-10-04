import 'package:flutter_test/flutter_test.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';

void main() {
  group('Step 4 & 5 Tests', () {
    test('Idempotent seeding does not duplicate posts', () async {
      final repo = LocalDemoRepository();
      await repo.init(); // Seeds data
      final postsCount = repo.getPosts().length;
      await repo.init(); // Try seed again
      expect(repo.getPosts().length, equals(postsCount));
    });

    test('Self clicks are excluded', () async {
      final repo = LocalDemoRepository();
      await repo.init();
      final post = repo.getPosts().first;
      final initialClicks = post.productClicksCount;
      
      await repo.recordProductClick(post.id, 'some_product', post.creatorId);
      final updatedPost = repo.getPostById(post.id);
      expect(updatedPost?.productClicksCount, equals(initialClicks));
    });
  });
}
