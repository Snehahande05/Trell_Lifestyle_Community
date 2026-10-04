import '../repositories/app_repository.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../models/post.dart';

class ReferralAttribution {
  final String productId;
  final String creatorId;
  final String postId;

  ReferralAttribution({
    required this.productId,
    required this.creatorId,
    required this.postId,
  });

  String toUrl() {
    return 'https://trell.app/ref?productId=$productId&creatorId=$creatorId&postId=$postId';
  }
}

class AttributionService {
  /// Builds a shareable affiliate referral URL containing Product ID, Creator ID, and Post ID.
  static String buildReferralUrl({
    required String productId,
    required String creatorId,
    required String postId,
  }) {
    return ReferralAttribution(
      productId: productId,
      creatorId: creatorId,
      postId: postId,
    ).toUrl();
  }

  /// Parses a referral link or deep link string into product, creator, and post IDs.
  static ReferralAttribution? parseReferralUrl(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl.trim());
      String? productId = uri.queryParameters['productId'];
      String? creatorId = uri.queryParameters['creatorId'];
      String? postId = uri.queryParameters['postId'];

      // Fallback custom pattern matching if simple path
      if (productId == null || creatorId == null || postId == null) {
        final regExp = RegExp(
          r'productId=([^&]+)&creatorId=([^&]+)&postId=([^&]+)',
        );
        final match = regExp.firstMatch(rawUrl);
        if (match != null && match.groupCount >= 3) {
          productId = match.group(1);
          creatorId = match.group(2);
          postId = match.group(3);
        }
      }

      if (productId != null && creatorId != null && postId != null) {
        return ReferralAttribution(
          productId: productId.trim(),
          creatorId: creatorId.trim(),
          postId: postId.trim(),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Validates attribution against the repository data.
  /// Verification rules:
  /// 1. Product exists.
  /// 2. Creator exists.
  /// 3. Post exists, belongs to the creator, AND the product is actually tagged in that post.
  static bool validateAttribution(
    AppRepositoryInterface repository, {
    required String productId,
    required String creatorId,
    required String postId,
  }) {
    final Product? product = repository.getProductById(productId);
    if (product == null) return false;

    final User? creator = repository.getUserById(creatorId);
    if (creator == null) return false;

    final Post? post = repository.getPostById(postId);
    if (post == null) return false;

    if (post.creatorId != creatorId) return false;

    if (!post.taggedProductIds.contains(productId)) return false;

    return true;
  }
}
