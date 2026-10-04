# Trell Lifestyle Community - University Project Documentation & Verification Matrix

## Project Overview
- **App Name**: Trell Lifestyle Community
- **Industry**: Social Commerce Platform
- **Framework**: Flutter (Dart)
- **Dart SDK Constraint**: `^3.13.0` (Targeting Dart SDK versions 3.13.0 to 3.x)
- **Primary Supported Platform**: Android (Emulator & Physical Devices)
- **Secondary Platform Support**: iOS (Architecturally configured with `Info.plist` usage descriptions)

---

## 1. Requirement Verification Matrix

| Requirement | Screen | Implementation / Service | Verification Performed | Status | Limitation |
|---|---|---|---|---|---|
| **1. Real Video Editing & Export** | `VideoCreationScreen` | Gallery/Camera picker, native Kotlin `MediaCodec`/`MediaMuxer` video pipeline, frame trimming, visual color matrix filter, PCM audio mixing, royalty-free audio tracks. | Unit tests for trim ranges and music selection; native plugin compilation via `flutter build apk --release`. | Implemented and verified | iOS compilation not configured for native video processing engine (Android primary). |
| **2. Local Video Storage & Playback** | `ShortVideoPlayerItem` | Separate playback streams for bundled assets (`asset`), persistent file paths (`file`), and HTTP URLs (`networkUrl`). Copying to app storage. | Local video files survive simulated app restart and playback initializes correctly | Implemented and verified | Web platform blob storage handles local files differently; Android is primary target. |
| **3. Tagged Product Preservation** | `VideoCreationScreen`, `AppStateProvider` | Cloned `List<String>.from(_selectedProductIds)` on post creation; isolated state reset | Unit test verifying post tagged products remain intact after creation form clear & user switch | Implemented and verified | None. |
| **4. Video Feed Lifecycle** | `VideoFeedScreen`, `ShortVideoPlayerItem` | `WidgetsBindingObserver` for app state, returning `bool` on view increments to prevent infinite rebuild loops, stable `ValueKey(post.id)`, reset `_currentIndex` on category switch | Active tab/route pause verified; view count loop eliminated | Implemented and verified | Backgrounding app pauses controller automatically. |
| **5. Usable Affiliate Links** | `AttributionService`, `ProductDetailScreen`, `ExploreSearchScreen` | Referral URL generator (`https://trell.app/ref?productId=...`), deep-link parsing, `AttributionService.validateAttribution()`, Demo Link Import UI | Unit tests for valid link generation, parsing, validation, and demo import dialog | Implemented and verified | Automatic external deep-link launching requires domain digital asset links setup on production server. |
| **6. Cart Item Identity** | `CartItem`, `AppStateProvider`, `LocalDemoRepository` | Stable `cartItemId` (`productId_creatorId_postId`), updated `updateCartQuantity` & `removeFromCart` to match all three identifiers | Unit test verifying independent quantity updates for identical products from different posts | Implemented and verified | None. |
| **7. Strengthen Checkout & Orders** | `CartScreen`, `OrdersScreen` | Simulated payment dialog ("Demo payment — no real money charged"), duplicate submission guard, status transitions (`paid`, `completed`, `refunded`, `cancelled`) | Unit tests verifying organic vs attributed sales and status transition ledger updates | Implemented and verified | Simulated payment gateway (no real monetary transactions processed). |
| **8. Financial Ledger Accounting** | `LocalDemoRepository`, `WalletScreen` | Separate `pending`, `available`, `reserved`, `paidOut`, `reversed` statuses. Minimum ₹100 limit, fund reservation on pending withdrawal | Unit tests for minimum limit, double-spend reservation, and paidOut status | Implemented and verified | None. |
| **9. Creator Analytics & Potential** | `CreatorDashboardScreen`, `ProductDetailScreen` | Formula: Engagement Rate = `(likes + comments + shares) / views * 100`, conversion rate, units sold, spendable balance, potential earnings card (`price * commission%`) | Formula rendering in dashboard UI and potential earnings breakdown card on product detail | Implemented and verified | Zero denominators yield `0.0%` safely without division by zero errors. |
| **10. Featured Promotions** | `PromotionsScreen`, `VideoFeedScreen` | Post selection, ₹499 package (7-day duration), simulated payment confirmation, active promotion feed prioritization, duplicate promotion guard | Unit test for 7-day expiry logic and active promotion feed sorting | Implemented and verified | 7-day package duration retained as documented project assumption. |
| **11. Verified Creator & Review Badges** | `ProductDetailScreen`, `CreatorVerificationScreen` | Purchase verification check (`hasUserPurchasedProduct`), verified creator badge dynamic lookup | Unit test for verified purchase review badge requirement | Implemented and verified | Review badge confirms purchase evidence in database, not subjective review veracity. |
| **12. Verified Creator Revenue Share** | `AdminManagementScreen`, `LocalDemoRepository` | Platform revenue share allocation capped at 30% (`clampedRate`), distinct from product sale commission | Unit test verifying 30% rate cap enforcement | Implemented and verified | Admin-recorded demo platform revenue allocation. |
| **13. Setup & Offline Assets** | `Info.plist`, `AndroidManifest.xml`, `README.md` | Added iOS camera/mic/photo library usage descriptions, Android permissions, bundled video assets, fixed SDK documentation | Clean `flutter analyze` and `flutter test` execution | Implemented and verified | Demo account switching simulates local multi-user testing without remote OAuth. |
| **14. Automated Test Verification** | `test/business_rules_test.dart` | Comprehensive test suite validating attribution, cart identity, ledger states, withdrawal reservations, analytics math, review eligibility, and promotion expiry | Executed `flutter test` with 100% passing tests | Implemented and verified | None. |
| **15. Feed Playback Lifecycle & Correct Media** | `ShortVideoPlayerItem`, `AppStateProvider`, `VideoFeedScreen` | `RouteAware` visibility tracking, tab tracking, distinct assets for each category, handling Missing File Exception. | MD5 Hash checks for correct distinct video assets; AppTab Index tests | Implemented and verified | Android device checks remain unverified. |
| **16. Interactions & Consistency** | `AppRepository`, `AppStateProvider` | Likes and Comments updating correctly; Self-Follow prevention implemented; Sharing exported local video uses `SharePlus.shareXFiles`. | Test for Like/Follow Persistence | Implemented and verified | None. |

---

## 2. Platform Setup & Dependencies

### Permissions & Privacy Configuration
- **iOS (`ios/Runner/Info.plist`)**:
  - `NSCameraUsageDescription`: Required for video recording in post creation.
  - `NSMicrophoneUsageDescription`: Required for audio recording during video creation.
  - `NSPhotoLibraryUsageDescription`: Required for selecting local videos from photo gallery.
- **Android (`android/app/src/main/AndroidManifest.xml`)**:
  - `android.permission.CAMERA`
  - `android.permission.RECORD_AUDIO`
  - `android.permission.INTERNET`
  - `android.permission.READ_MEDIA_VIDEO` / `READ_EXTERNAL_STORAGE`

---

## 3. Run & Build Instructions

### Running Locally
1. Fetch packages:
   ```bash
   flutter pub get
   ```
2. Run static code analyzer:
   ```bash
   flutter analyze
   ```
3. Run unit & integration test suite:
   ```bash
   flutter test
   ```
4. Launch on Android Emulator or connected device:
   ```bash
   flutter run
   ```

### Building APK (Android)
To build a release APK for deployment or evaluation:
```bash
flutter build apk --release
```

---

## 4. Demo Accounts & Account Switcher
The application includes a persistent top **Demo Account Switcher Bar** on the main feed screen:
1. **Aanya Sharma (Viewer/Shopper)**: Can view short videos, tap tagged products, import referral links, add to cart, rate products, and complete checkout.
2. **Priya Fashionista (Verified Creator)**: Verified creator with video posts, creator dashboard analytics, wallet balance, and withdrawal requests.
3. **Rohan Traveler (Creator)**: Creator with travel vlogs, analytics, and affiliate earnings.
4. **Trell Admin (Administrator)**: Access to Admin Panel for completing orders, processing creator verification applications, handling withdrawal payouts, and allocating platform revenue share.
