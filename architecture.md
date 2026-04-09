# PourMetrics Mobile App — Architecture

## Overview

Flutter mobile app for the PourMetrics Smart Coaster analytics platform. Consumes the PourMetrics REST API (`/api/v1`).

**Theme:** Material 3 dark mode with amber seed color (`#F59E0B` — yellowish-orange).

---

## Tech Stack

| Concern | Package |
|---|---|
| State management | `flutter_riverpod ^2.6.1` |
| HTTP client | `dio ^5.7.0` |
| Navigation | `go_router ^14.6.2` |
| Secure storage | `flutter_secure_storage ^9.2.2` |
| Charts | `fl_chart ^0.69.0` |
| Date formatting | `intl ^0.19.0` |

---

## Folder Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── api_constants.dart        # All API endpoint paths
│   ├── models/
│   │   └── user_profile.dart         # Shared domain model
│   ├── network/
│   │   └── dio_client.dart           # Dio factory + auth interceptor
│   ├── providers/
│   │   └── dio_provider.dart         # Riverpod Provider<Dio>
│   ├── router/
│   │   └── app_router.dart           # go_router config + auth redirect guard
│   ├── storage/
│   │   └── secure_storage.dart       # JWT + role storage (flutter_secure_storage)
│   ├── theme/
│   │   └── app_theme.dart            # Material 3 dark theme, amber seed
│   └── widgets/
│       ├── error_view.dart           # Shared error/retry widget
│       └── main_shell.dart           # ShellRoute — persistent bottom NavigationBar
│
└── features/
    ├── auth/
    │   ├── data/auth_repository.dart
    │   ├── domain/auth_state.dart
    │   ├── providers/auth_provider.dart   # AsyncNotifier<AuthState>
    │   └── presentation/login_screen.dart
    ├── dashboard/
    │   ├── providers/dashboard_provider.dart
    │   └── presentation/dashboard_screen.dart
    ├── pours/
    │   ├── providers/pours_provider.dart
    │   └── presentation/pours_screen.dart
    ├── alerts/
    │   ├── providers/alerts_provider.dart
    │   └── presentation/alerts_screen.dart
    ├── inventory/
    │   ├── providers/inventory_provider.dart
    │   └── presentation/inventory_screen.dart   # Bottles + Products tabs
    └── profile/
        ├── providers/profile_provider.dart
        └── presentation/profile_screen.dart
```

---

## Authentication

### Token storage (`SecureStorage`)

- `access_token`, `refresh_token`, `role` — all stored in `flutter_secure_storage`.
- Role is also kept in a synchronous in-memory cache (`_cachedRole`) so the go_router redirect guard can run without awaiting storage.

### Dio auth interceptor (`_AuthInterceptor`)

Implemented as `QueuedInterceptorsWrapper` — queues concurrent requests while a token refresh is in flight, preventing stampede:

1. **onRequest** — injects `Authorization: Bearer <access_token>` header.
2. **onError (401)** — uses a separate plain `Dio` instance to call `POST /auth/refresh`.
   - On success: writes new tokens, retries the original request.
   - On failure (refresh expired): clears storage, lets the error propagate → router redirect triggers `/login`.

### Router guard (`app_router.dart`)

```dart
redirect: (context, state) {
  if (authAsync.isLoading) return null; // Wait for auth init
  if (!isAuthenticated && !isGoingToLogin) return '/login';
  if (isAuthenticated && isGoingToLogin) return '/dashboard';
  return null;
}
```

---

## Navigation

`go_router` with a single `ShellRoute` wrapping all authenticated screens. The shell renders `MainShell` which contains the persistent `NavigationBar`.

**5 tabs:**

| Tab | Route | Icon |
|---|---|---|
| Dashboard | `/dashboard` | bar_chart |
| Pours | `/pours` | local_drink |
| Alerts | `/alerts` | notifications |
| Inventory | `/inventory` | inventory_2 |
| Profile | `/profile` | person |

---

## State Management (Riverpod)

- `authProvider` — `AsyncNotifierProvider<AuthNotifier, AuthState>`. Initialises by reading stored role. Drives router redirect.
- `dioProvider` — `Provider<Dio>`. Single Dio instance with auth interceptor.
- Feature providers — `FutureProvider.autoDispose` for data fetching. Invalidation triggers re-fetch (used for refresh).
- `StateProvider` for simple local UI state (e.g. current pagination page).

---

## Theme

```dart
ColorScheme.fromSeed(
  seedColor: Color(0xFFF59E0B), // amber-500
  brightness: Brightness.dark,
)
```

- Scaffold background: `#0F0F0F`
- Card / surface: `#1E1E1E`
- App bar / nav bar: `#1A1A1A`
- Primary accent (labels, icons, buttons): `#F59E0B`
- Success / revenue: `#4CAF50`
- Alert / error: `#F44336`

---

## API Base URL

Configured in `lib/core/constants/api_constants.dart`:

```dart
static const String baseUrl = 'http://localhost:5000/api/v1';
```

Update this to the production URL before release.
