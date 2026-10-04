// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';
import 'package:trell_lifestyle_community/providers/app_state_provider.dart';

const _kNewVideoRoot = 'assets/videos/categories/';
const _kOldFallbacks = [
  'assets/videos/fashion_trend.mp4',
  'assets/videos/beauty_routine.mp4',
  'assets/videos/travel_vlog.mp4',
  'assets/videos/food_recipe.mp4',
  'assets/videos/diy_craft.mp4',
];
const _kCategories = ['Fashion', 'Beauty', 'Travel', 'Food', 'DIY'];
const _kExpectedPostsPerCategory = 5;
const _kTotalExpectedPosts = 25;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'REGRESSION: all 25 seeded feed posts use assets/videos/categories/ path',
    () async {
      final repo = LocalDemoRepository();
      await repo.init();
      final posts = repo.getPosts();

      expect(
        posts.length,
        greaterThanOrEqualTo(_kTotalExpectedPosts),
        reason: 'Expected at least $_kTotalExpectedPosts seeded posts',
      );

      for (final post in posts) {
        expect(
          post.videoPath.startsWith(_kNewVideoRoot),
          isTrue,
          reason:
              'Post ${post.id} has invalid videoPath: "${post.videoPath}". '
              'All feed posts MUST use $_kNewVideoRoot',
        );
      }
    },
  );

  test('REGRESSION: no feed post uses any old demo video path', () async {
    final repo = LocalDemoRepository();
    await repo.init();
    final posts = repo.getPosts();

    for (final post in posts) {
      for (final oldPath in _kOldFallbacks) {
        expect(
          post.videoPath,
          isNot(equals(oldPath)),
          reason: 'Post ${post.id} must NOT use old demo path "$oldPath".',
        );
      }
    }
  });

  test('REGRESSION: no feed post uses fashion_trend.mp4 fallback', () async {
    final repo = LocalDemoRepository();
    await repo.init();
    final posts = repo.getPosts();

    final offenders = posts
        .where((p) => p.videoPath.contains('fashion_trend.mp4'))
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'Found ${offenders.length} post(s) still using fashion_trend.mp4: '
          '${offenders.map((p) => p.id).join(', ')}',
    );
  });

  test('REGRESSION: exactly $_kExpectedPostsPerCategory posts per category', () async {
    final repo = LocalDemoRepository();
    await repo.init();
    final posts = repo.getPosts();

    for (final category in _kCategories) {
      final categoryPosts = posts.where((p) => p.category == category).toList();
      expect(
        categoryPosts.length,
        equals(_kExpectedPostsPerCategory),
        reason:
            'Category "$category" should have exactly $_kExpectedPostsPerCategory posts, '
            'but found ${categoryPosts.length}',
      );
    }
  });

  test('REGRESSION: total seeded posts equals $_kTotalExpectedPosts', () async {
    final repo = LocalDemoRepository();
    await repo.init();
    final posts = repo.getPosts();

    final categoryPosts = posts
        .where((p) => p.videoPath.startsWith(_kNewVideoRoot))
        .toList();
    expect(
      categoryPosts.length,
      equals(_kTotalExpectedPosts),
      reason:
          'Expected exactly $_kTotalExpectedPosts category posts, found ${categoryPosts.length}',
    );
  });

  test(
    'REGRESSION: each category video path matches expected filename pattern',
    () async {
      final repo = LocalDemoRepository();
      await repo.init();
      final posts = repo.getPosts();

      for (final category in _kCategories) {
        final catLower = category.toLowerCase();
        final catPosts = posts.where((p) => p.category == category).toList()
          ..sort((a, b) => a.id.compareTo(b.id));

        for (int i = 0; i < catPosts.length; i++) {
          final expectedNum = (i + 1).toString().padLeft(2, '0');
          final expectedPath =
              '$_kNewVideoRoot$catLower/${catLower}_$expectedNum.mp4';
          expect(
            catPosts[i].videoPath,
            equals(expectedPath),
            reason:
                'Post ${catPosts[i].id} has path "${catPosts[i].videoPath}", '
                'expected "$expectedPath"',
          );
        }
      }
    },
  );

  test('REGRESSION: migration from seed v0 replaces all old posts with new category posts', () async {
    SharedPreferences.setMockInitialValues({
      'trell_users': '[]',
      'trell_posts':
          '[{"id":"post_old_1","creatorId":"u_creator1",'
          '"creatorName":"Old","creatorAvatarUrl":"assets/images/creator_priya.png",'
          '"isVerifiedCreator":false,'
          '"videoPath":"assets/videos/fashion_trend.mp4",'
          '"caption":"Old demo","category":"Fashion","taggedProductIds":[],'
          '"viewsCount":10,"likedUserIds":[],"comments":[],"sharesCount":0,'
          '"productClicksCount":0,"filterName":"Normal","musicTitle":null,'
          '"createdAt":"2024-01-01T00:00:00.000Z",'
          '"isPromoted":false,"promotionExpiry":null}]',
    });

    final repo = LocalDemoRepository();
    await repo.init();
    final posts = repo.getPosts();

    final oldPost = posts.where((p) => p.id == 'post_old_1').toList();
    expect(
      oldPost,
      isEmpty,
      reason: 'Old demo post "post_old_1" with fashion_trend.mp4 should have been removed by migration',
    );

    final newPosts = posts
        .where((p) => p.videoPath.startsWith(_kNewVideoRoot))
        .toList();
    expect(
      newPosts.length,
      equals(_kTotalExpectedPosts),
      reason:
          'After migration, expected $_kTotalExpectedPosts new posts, got ${newPosts.length}',
    );
  });

  test('REGRESSION: migration does NOT wipe orders or commissions', () async {
    const ordersJson =
        '[{"id":"ord_1","buyerUserId":"u_viewer","buyerName":"Aanya",'
        '"items":[],"shippingAddress":"123 Test St","totalPaise":99900,'
        '"status":"delivered","createdAt":"2024-01-01T00:00:00.000Z",'
        '"idempotencyKey":"test-idem-key-1"}]';

    const commissionsJson =
        '[{"id":"comm_1","creatorId":"u_creator1","postId":"p1",'
        '"productId":"pr1","buyerUserId":"u_viewer","salePricePaise":99900,'
        '"commissionPaise":9990,"createdAt":"2024-01-01T00:00:00.000Z"}]';

    SharedPreferences.setMockInitialValues({
      'trell_users': '[]',
      'trell_posts': '[]',
      'trell_orders': ordersJson,
      'trell_commissions': commissionsJson,
    });

    final repo = LocalDemoRepository();
    await repo.init();

    final orders = repo.getOrders();
    expect(
      orders.isNotEmpty,
      isTrue,
      reason: 'Orders must NOT be wiped by seed migration',
    );

    final commissions = repo.getCommissionsForCreator('u_creator1');
    expect(
      commissions.isNotEmpty,
      isTrue,
      reason: 'Commissions must NOT be wiped by seed migration',
    );
  });

  test(
    'Like/unlike and follow/unfollow persistence and duplicate prevention',
    () async {
      final repo = LocalDemoRepository();
      await repo.init();
      final provider = AppStateProvider(repository: repo);
      await provider.init();
      await provider.switchDemoUser('u_viewer');

      final user = provider.currentUser!;
      final post = provider.feedPosts.first;

      final String targetId = repo
          .getUsers()
          .firstWhere((u) => u.id != user.id)
          .id;
      final int initialFollowers = repo.getUserById(targetId)!.followerCount;

      await repo.toggleFollowUser(user.id, targetId);
      expect(repo.isFollowing(user.id, targetId), isTrue);
      expect(repo.getUserById(targetId)!.followerCount, initialFollowers + 1);

      await repo.toggleFollowUser(user.id, targetId);
      expect(repo.isFollowing(user.id, targetId), isFalse);
      expect(repo.getUserById(targetId)!.followerCount, initialFollowers);

      await repo.toggleFollowUser(user.id, user.id);
      expect(repo.isFollowing(user.id, user.id), isFalse);

      final bool alreadyLiked = repo
          .getPostById(post.id)!
          .likedUserIds
          .contains(user.id);
      final int initialLikes = repo.getPostById(post.id)!.likedUserIds.length;

      await repo.togglePostLike(post.id, user.id);
      if (alreadyLiked) {
        expect(
          repo.getPostById(post.id)!.likedUserIds.length,
          initialLikes - 1,
        );
      } else {
        expect(
          repo.getPostById(post.id)!.likedUserIds.length,
          initialLikes + 1,
        );
      }
    },
  );

  test(
    'Category changes and feed updates preserving a valid selected post',
    () async {
      final repo = LocalDemoRepository();
      await repo.init();
      final provider = AppStateProvider(repository: repo);
      await provider.init();

      expect(provider.selectedCategory, 'All');
      expect(provider.feedPosts.isNotEmpty, isTrue);

      provider.setCategory('Fashion');
      expect(provider.selectedCategory, 'Fashion');
      expect(provider.feedPosts.every((p) => p.category == 'Fashion'), isTrue);

      provider.setCategory('EmptyCategory');
      expect(provider.feedPosts.isEmpty, isTrue);
    },
  );
}
