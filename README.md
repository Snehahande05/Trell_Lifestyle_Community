# Trell Lifestyle Community - University Project Documentation & Verification Matrix

## Project Overview
- **App Name**: Trell Lifestyle Community
- **Industry**: Social Commerce Platform
- **Frontend Framework**: Flutter (Dart)
- **Dart SDK Constraint**: `^3.13.0` (Targeting Dart SDK versions 3.13.0 to 3.x)
- **State & Architecture**: Provider + Repository Pattern (`LocalDemoRepository`) + Service Layer (`AttributionService`, `NativeVideoProcessor`)
- **Local Persistence**: `SharedPreferences` (used for session persistence `loggedInUserId`, likes, follows, cart, orders, wallet, commissions, withdrawals, creator verification applications, promotions, and revenue-share records)
- **Android Native Video Processing**: Kotlin / native platform bridge (`MediaCodec`, `MediaMuxer`) for real video export
- **Authentication**: Local demo authentication supporting Customer, Creator, and Admin roles with persistent session and full Logout flow
- **Payments & Payouts**: Simulated demo financial transaction and payout flow
- **Promotions & Revenue Share**: Simulated ₹499/7-day promotion package and Verified Creator revenue share capped at 30%

---

## 1. Media Attribution & Asset Declarations

- **User-Provided Category Images**: User-provided demo category images (25 category photos: 5 Fashion, 5 Beauty, 5 Travel, 5 Food, 5 DIY in `assets/images/categories/`).
- **Generated Category Feed Videos**: 25 short MP4 feed videos generated from user-provided category images using Ken Burns zoom/pan animations and 720p mobile H.264 compression (`assets/videos/categories/`).
- **Royalty-Free Audio Tracks**: Bundled demo-safe background audio tracks (`assets/audio/lofi_chill.wav`, `assets/audio/upbeat_pop.wav`, `assets/audio/acoustic_travel.wav`, `assets/audio/bossa_nova.wav`).
- **Creator Profile Photos**: Generated demo profile images and bundled local assets (`assets/images/creator_priya.png`, `assets/images/creator_rohan.png`, `assets/images/viewer_aanya.png`).

---

## 2. Requirement Verification Matrix

| Task / Feature | Implementation / Screen | Technical Strategy & Verification | Status |
|---|---|---|---|
| **1. Demo Authentication & Session** | `LoginScreen`, `UserProfileScreen`, `AppStateProvider` | `SharedPreferences` key `loggedInUserId`. Unauthenticated state renders `LoginScreen`. Logout clears session key without deleting seeded data/wallets. | Verified via automated unit & widget tests (`test/task_updates_test.dart`). |
| **2. 25 Category Feed Videos** | `gen_videos.sh`, `assets/videos/categories/` | Generated 25 720p 9:16 Ken Burns MP4 videos from the 25 user-provided images across Fashion, Beauty, Travel, Food, DIY. | Verified file existence and video stream structure via `ffprobe` & test suite. |
| **3. Feed Audio & Player Lifecycle** | `ShortVideoPlayerItem`, `VideoFeedScreen`, `MainNavigationContainer` | Valid AAC audio streams in MP4 files. `VideoFeedScreen(isActive: _currentIndex == 0)` ensures background tab switching silences audio; lifecycle observer pauses on app background. | Verified in player logic and tab navigation. Physical device audio check recommended. |
| **4. Offline Category Media** | `AdaptiveImage`, `image_utils.dart`, `pubspec.yaml` | `getAdaptiveImageProvider` handles `assets/`, file paths, and fallback gracefully offline without broken image icons. | Verified offline asset loading and pubspec entries. |
| **5. 5 Coherent Posts Per Category** | `LocalDemoRepository`, `Post` model | 25 seed posts (5 per category) with matching 4-way alignment: Image, Video, Title/Description, and Category. | Verified via automated test `test/task_updates_test.dart`. |
| **6. Explore & Global Search** | `ExploreSearchScreen` | 10+ items immediately visible. Tapping creator opens Creator Profile modal. Global search searches full dataset across all categories. | Verified via automated tests and UI components. |
| **7 & 8. Demo Creators & Post Binding** | `User`, `Post`, `ExploreSearchScreen` | 10 demo creators with distinct bios and roles. All 25 posts reference existing creators and navigate to Creator Profiles. | Verified creator count >= 10 and relationship integrity in tests. |
| **9. Business Logic Rules (Steps 2-11)** | `AttributionService`, `LocalDemoRepository` | Preserved all affiliate attribution, product tagging, 30% rev share cap, ₹499 promotions, withdrawal accounting, and review badge eligibility. | Verified via 125/125 passing automated tests. |
| **10. APK Size & Performance** | `gen_videos.sh`, `flutter build apk --release` | Compressed 25 videos using H.264 CRF 28 & 1Mbps target bitrate. Total video assets = 7.4 MB. Final APK size = 137.6 MB. | Verified release APK build size (reduced from 215.1 MB to 137.6 MB). |
| **11. Real Video Creator Export** | `VideoCreationScreen`, `NativeVideoProcessor` | Retained native Kotlin `MediaCodec`/`MediaMuxer` video editing, trimming, filters, and real export. | Verified compilation and preserved native bridge. |

---

## 3. Run & Build Instructions

### Fetch Packages & Run Analyzer
```bash
flutter pub get
flutter analyze
```

### Run Full Automated Test Suite
```bash
flutter test
```

### Build Android Release APK
```bash
flutter build apk --release
```

---

## 4. Demo Accounts
- **Aanya Sharma (Viewer/Customer)**: `@aanya_shopper`
- **Priya Fashionista (Verified Creator)**: `@priya_style`
- **Rahul Style (Creator)**: `@rahul_fashion`
- **Simran Glow (Verified Creator)**: `@simran_beauty`
- **Kavya Looks (Creator)**: `@kavya_makeup`
- **Rohan Traveler (Verified Creator)**: `@rohan_explores`
- **Aryan Nomad (Creator)**: `@aryan_travels`
- **Megha Bites (Verified Creator)**: `@megha_foodie`
- **Chef Karan (Creator)**: `@karan_cooks`
- **Diya Crafts (Verified Creator)**: `@diya_diy`
- **Lifestyle With Sam (Verified Creator)**: `@sam_lifestyle`
- **Trell Admin (Administrator)**: `@admin_portal`
