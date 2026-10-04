import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/app_state_provider.dart';
import 'repositories/app_repository.dart';
import 'models/user.dart';
import 'screens/video_feed_screen.dart';
import 'screens/explore_search_screen.dart';
import 'screens/video_creation_screen.dart';
import 'screens/creator_dashboard_screen.dart';
import 'screens/user_profile_screen.dart';
import 'screens/admin_management_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repository = LocalDemoRepository();
  final appStateProvider = AppStateProvider(repository: repository);
  await appStateProvider.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appStateProvider,
      child: const TrellLifestyleApp(),
    ),
  );
}

class TrellLifestyleApp extends StatelessWidget {
  const TrellLifestyleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trell Lifestyle Community',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const MainNavigationContainer(),
    );
  }
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key});

  @override
  State<MainNavigationContainer> createState() =>
      _MainNavigationContainerState();
}

class _MainNavigationContainerState extends State<MainNavigationContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    VideoFeedScreen(), // 0. Home Short Video Feed
    ExploreSearchScreen(), // 1. Explore & Search
    VideoCreationScreen(), // 2. Create & Edit Video
    CreatorDashboardScreen(), // 3. Creator Dashboard & Analytics
    UserProfileScreen(), // 4. Profile & Wallet
    AdminManagementScreen(), // 5. Admin Portal
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppStateProvider>();
    final user = provider.currentUser;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.grey.shade900,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.white60,
        selectedFontSize: 12,
        unselectedFontSize: 11,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),
            label: 'Home Feed',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_box, size: 30, color: Colors.pinkAccent),
            label: 'Create',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
          if (user?.role == UserRole.admin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings, color: Colors.amber),
              label: 'Admin',
            ),
        ],
      ),
    );
  }
}
