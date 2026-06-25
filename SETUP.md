# Two Hearts — Setup Guide

## Before you can run the app

### 1. Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project named `two-hearts`
3. Enable **Authentication** → Email/Password sign-in
4. Enable **Firestore** (start in test mode)
5. Enable **Firebase Storage**
6. Enable **Firebase Cloud Messaging** (for push notifications)

### 2. Add Android app to Firebase

1. In your Firebase project, click **Add app → Android**
2. Package name: `com.twohearts.two_hearts`
3. Download `google-services.json`
4. Place it at: `android/app/google-services.json`

### 3. Run the app

```bash
export PATH="$PATH:/home/xxorks/flutter-sdk/flutter/bin"
cd "two_hearts"
flutter run
```

## Firestore Security Rules (paste in Firebase console)

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
    match /couples/{coupleId} {
      allow read, write: if request.auth.uid in resource.data.members
                         || request.auth.uid in request.resource.data.members;
      match /{subcollection}/{docId} {
        allow read, write: if request.auth.uid in get(/databases/$(database)/documents/couples/$(coupleId)).data.members;
      }
    }
  }
}
```

## Architecture Overview

```
lib/
├── main.dart                    # App entry + ProviderScope + routing
├── core/
│   ├── theme/app_theme.dart     # Warm palette, Material3 theme
│   ├── firebase/
│   │   ├── models.dart          # All Firestore models
│   │   └── firestore_service.dart # DB read/write layer
│   ├── providers/providers.dart # Riverpod stream providers
│   ├── router/app_router.dart   # GoRouter + auth redirect
│   └── shell/main_shell.dart    # 5-tab bottom nav shell
└── features/
    ├── auth/                    # Login, register, pairing (invite codes)
    ├── room/                    # Home screen with stats + "Thinking Of You"
    ├── chat/                    # Real-time messaging
    ├── memory/                  # Photo wall + detail view
    ├── together/                # Journal, letters, bucket list
    └── you_and_me/              # Mood check-in + profile
```

## Phase roadmap

- **Phase 0** ✅ — Auth, pairing, chat
- **Phase 1** ✅ — Mood, Thinking Of You, Letters  
- **Phase 2** ✅ — Memory Wall, Journal, Bucket List
- **Phase 3** 🔜 — 3D Room with Ready Player Me avatars
- **Phase 4** 🔜 — Scribble game, avatar progression
- **Phase 5** 🔜 — Drive backup, monetization, Play Store
