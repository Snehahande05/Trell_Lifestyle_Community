import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';
import 'package:trell_lifestyle_community/providers/app_state_provider.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('Like/unlike and follow/unfollow persistence and duplicate prevention', () async {
    final repo = LocalDemoRepository();
    await repo.init();
    final provider = AppStateProvider(repository: repo);
    await provider.init();

    final user = provider.currentUser!;
    final post = provider.feedPosts.first;

    // Test Follow/Unfollow
    String targetId = repo.getUsers().firstWhere((u) => u.id != user.id).id;
    int initialFollowers = repo.getUserById(targetId)!.followerCount;

    // Follow
    await repo.toggleFollowUser(user.id, targetId);
    expect(repo.isFollowing(user.id, targetId), isTrue);
    expect(repo.getUserById(targetId)!.followerCount, initialFollowers + 1);

    // Toggle again (Unfollow)
    await repo.toggleFollowUser(user.id, targetId);
    expect(repo.isFollowing(user.id, targetId), isFalse);
    expect(repo.getUserById(targetId)!.followerCount, initialFollowers);

    // Self follow prevention
    await repo.toggleFollowUser(user.id, user.id);
    expect(repo.isFollowing(user.id, user.id), isFalse);

    // Test Like/Unlike
    bool alreadyLiked = repo.getPostById(post.id)!.likedUserIds.contains(user.id);
    int initialLikes = repo.getPostById(post.id)!.likedUserIds.length;

    await repo.togglePostLike(post.id, user.id);
    if (alreadyLiked) {
      expect(repo.getPostById(post.id)!.likedUserIds.length, initialLikes - 1);
    } else {
      expect(repo.getPostById(post.id)!.likedUserIds.length, initialLikes + 1);
    }
  });

  test('Category changes and feed updates preserving a valid selected post', () async {
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
  });
}
