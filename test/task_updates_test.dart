import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trell_lifestyle_community/repositories/app_repository.dart';
import 'package:trell_lifestyle_community/providers/app_state_provider.dart';
import 'package:trell_lifestyle_community/models/user.dart';
import 'package:trell_lifestyle_community/main.dart';
import 'package:trell_lifestyle_community/screens/login_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('New Task Requirements Tests', () {
    late LocalDemoRepository repository;
    late AppStateProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = LocalDemoRepository();
      provider = AppStateProvider(repository: repository);
      await provider.init();
    });

    test('exactly 5 app categories', () {
      final posts = repository.getPosts();
      final categories = posts.map((p) => p.category).toSet();
      expect(categories.length, 5);
      expect(categories.contains('Fashion'), true);
      expect(categories.contains('Beauty'), true);
      expect(categories.contains('Travel'), true);
      expect(categories.contains('Food'), true);
      expect(categories.contains('DIY'), true);
    });

    test(
      'Fashion posts >= 5, Beauty >= 5, Travel >= 5, Food >= 5, DIY >= 5',
      () {
        final posts = repository.getPosts();
        for (final cat in ['Fashion', 'Beauty', 'Travel', 'Food', 'DIY']) {
          final catPosts = posts.where((p) => p.category == cat).toList();
          expect(
            catPosts.length >= 5,
            true,
            reason: '$cat has ${catPosts.length} posts',
          );
        }
      },
    );

    test('creator count >= 10', () {
      final users = repository.getUsers();
      final creators = users.where((u) => u.role == UserRole.creator).toList();
      expect(creators.length >= 10, true);
    });

    test('every post references an existing creator', () {
      final posts = repository.getPosts();
      final users = repository.getUsers();
      final userIds = users.map((u) => u.id).toSet();
      for (final p in posts) {
        expect(userIds.contains(p.creatorId), true);
      }
    });

    test('every seeded product reference is valid', () {
      final posts = repository.getPosts();
      final products = repository.getProducts();
      final prodIds = products.map((p) => p.id).toSet();
      for (final p in posts) {
        for (final tag in p.taggedProductIds) {
          expect(prodIds.contains(tag), true);
        }
      }
    });

    test('Login success, Logout, Session Behavior', () async {
      // initially no user logged in
      expect(provider.currentUser, isNull);

      // login
      await provider.switchDemoUser('u_viewer');
      expect(provider.currentUser, isNotNull);
      expect(provider.currentUser!.id, 'u_viewer');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('loggedInUserId'), 'u_viewer');

      // logout
      await provider.logout();
      expect(provider.currentUser, isNull);
      expect(prefs.getString('loggedInUserId'), isNull);
    });

    testWidgets('Login screen existence and demo-role switching', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repo = LocalDemoRepository();
      final appState = AppStateProvider(repository: repo);
      await appState.init();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppStateProvider>.value(
          value: appState,
          child: const TrellLifestyleApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Select a Demo Account to Login'), findsOneWidget);
    });
  });

  group('Asset checks', () {
    test('all generated video asset paths exist and >= 25', () {
      int videoCount = 0;
      for (final cat in ['fashion', 'beauty', 'travel', 'food', 'diy']) {
        for (int i = 1; i <= 5; i++) {
          final path =
              'assets/videos/categories/$cat/${cat}_${i.toString().padLeft(2, '0')}.mp4';
          final file = File(path);
          expect(file.existsSync(), true, reason: 'File $path should exist');
          videoCount++;
        }
      }
      expect(videoCount >= 25, true);
    });

    test('all seeded local category image paths exist', () {
      for (final cat in ['fashion', 'beauty', 'travel', 'food', 'diy']) {
        for (int i = 1; i <= 5; i++) {
          final catCap = cat[0].toUpperCase() + cat.substring(1);
          final path =
              'assets/images/categories/$cat/${catCap}_${i.toString().padLeft(2, '0')}.png';
          final file = File(path);
          expect(file.existsSync(), true, reason: 'Image $path should exist');
        }
      }
    });
  });
}
