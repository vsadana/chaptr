# ChaptrAssignment

## Overview

This is a TikTok-style vertical video feed iOS app built with SwiftUI. It demonstrates smooth video playback, thumbnail caching, and a modern, responsive UI. The feed loads video metadata from a local JSON file and streams videos from remote URLs.

## How to Build and Run

1. **Requirements:**
   - Xcode 15 or later
   - iOS 17+ Simulator or device

2. **Steps:**
   1. Clone this repository:
      ```sh
      git clone <YOUR_REPO_URL>
      ```
   2. Open `ChaptrAssignment.xcodeproj` in Xcode.
   3. Select a simulator (e.g., iPhone 15 Pro) or your device.
   4. Press **Run** (⌘R).

   The app will launch and display a vertical video feed. Scroll to navigate between videos. Tap the video to play/pause. Like, share, and send actions are available on the right.

## What Was Built vs Skipped

### Built:
- Vertical, paged video feed (like TikTok/Reels)
- Smooth AVPlayer-based playback with thumbnail preloading
- Memory-cached thumbnails and player items
- Like, share, and send action bar (UI only)
- Progress bar with scrubbing
- Error handling and loading states
- Local JSON-based video catalog

### Skipped:
- User authentication and profiles
- Real backend (all data is local/static)
- Persistent like/share/send state
- Comments, following, or social features
- Push notifications
- Analytics and crash reporting
- Accessibility polish (basic VoiceOver support only)

**Why:** Focus was on core feed, playback, and performance. Social and backend features were out of scope for a short assignment.

## Tradeoffs and Future Revisions
- **Memory vs. Performance:** Aggressive caching for smooth UX, but cache limits are conservative to avoid memory pressure. Would tune with real analytics.
- **No persistent state:** Likes/shares are UI-only. Would add CoreData or backend sync for real app.
- **No offline support:** All videos stream from remote URLs. Would add download/caching for offline use.
- **Minimal error UI:** Only basic error/retry for loading. Would add richer error handling and user feedback.

## With Another Week
- Add real backend (Firebase or custom API)
- User accounts, persistent likes/shares
- Infinite scroll/pagination
- Video upload and creation
- Advanced analytics and crash reporting
- Accessibility and localization polish
- Automated UI and performance tests

## Biggest Scaling Risk
**Video streaming and caching at scale.**
- Thousands of users and videos would stress CDN, cache, and memory. Need adaptive prefetch, smarter cache eviction, and CDN edge tuning.
- Would need to monitor memory, bandwidth, and user engagement to tune cache and prefetching.

## Walkthrough Video
- **GITHUB**: https://github.com/vsadana/chaptr
- **INSTAGRAM**: https://www.instagram.com/reel/DYrpJ0hy9C1/?igsh=MWw3ZjBoNHJoczV2Mw==

