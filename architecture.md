# PourMetrics — System Architecture

## System Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                          PourMetrics System                           │
└──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────┐   HTTPS/REST   ┌─────────────────────┐   ┌──────┐
  │   Flutter App    │◀──────────────▶│  ASP.NET Core API   │──▶│  DB  │
  │  (iOS / Android) │   FCM push ▶   │  (.NET 9 + SQLite)  │   │      │
  └──────────────────┘                └─────────────────────┘   └──────┘
                                                ▲
                                                │ HTTP (Wi-Fi)
                                                │
                               ┌────────────────┴───────────────────┐
                               │        ESP32-C3 Smart Coaster       │
                               │                                     │
                               │  ┌──────────┐  ┌────────────────┐  │
                               │  │  HX711   │  │   RC522 RFID   │  │
                               │  │  Weight  │  │   Bottle ID    │  │
                               │  └──────────┘  └────────────────┘  │
                               │           ┌──────────┐              │
                               │           │ LiPo ADC │              │
                               │           │ Battery  │              │
                               │           └──────────┘              │
                               └─────────────────────────────────────┘
```

---

## 1. Mobile App (Flutter)

### Tech stack

| Concern | Package |
|---|---|
| State management | `flutter_riverpod ^2.6.1` |
| HTTP client | `dio ^5.7.0` |
| Navigation | `go_router ^14.6.2` |
| Secure storage | `flutter_secure_storage ^9.2.2` |
| Local DB | `sqflite ^2.4.1` |
| Connectivity | `connectivity_plus ^6.1.4` |
| Charts | `fl_chart ^0.69.0` |
| Push notifications | `firebase_messaging ^15`, `flutter_local_notifications ^18` |
| Barcode scanner | `mobile_scanner ^5` |
| Date formatting | `intl ^0.19.0` |

### Feature structure

```
lib/
├── core/
│   ├── constants/       api_constants, app_colors, app_text_styles
│   ├── db/              AppDatabase (SQLite — cache + offline queue)
│   ├── models/          UserProfile, shared domain types
│   ├── network/         MockInterceptor (dev only), DioProvider
│   ├── notifications/   NotificationService (FCM + local channels)
│   ├── providers/       dioProvider, authHeaderInterceptor
│   ├── router/          app_router (GoRouter + auth redirect guard)
│   ├── services/        CacheStore, OfflineQueue, MutationHelper,
│   │                    QueueStatusNotifier
│   ├── theme/           AppTheme (Material 3, amber seed, dark)
│   └── widgets/         ErrorView, MainShell (bottom nav)
│
└── features/
    ├── auth/            LoginScreen, AuthNotifier (JWT + refresh)
    ├── dashboard/       DashboardScreen (stats, hourly shots chart,
    │                    top products — admin only)
    ├── pours/           PoursScreen (date preset/custom filter,
    │                    oversize/after-hours flags, pagination)
    ├── inventory/       Bottles + Products (SWR cache + offline queue)
    ├── devices/         DevicesScreen, DeviceSetupScreen
    ├── alerts/          AlertsScreen, AlertConfigScreen
    ├── users/           UsersScreen (invite, role change, deactivate)
    └── profile/         ProfileScreen (admin tools section)
```

### Navigation

`go_router` with a `ShellRoute` for the 5 bottom-nav tabs:

| Tab | Route | Visible to |
|---|---|---|
| Dashboard | `/dashboard` | All roles |
| Pours | `/pours` | All roles |
| Alerts | `/alerts` | All roles |
| Inventory | `/inventory` | All roles |
| Profile | `/profile` | All roles |

Full-screen routes (outside shell, no bottom nav):

| Route | Screen |
|---|---|
| `/devices` | Smart Coasters list |
| `/devices/setup` | Coaster provisioning guide |
| `/alerts/config` | Alert config (thresholds, after-hours) |
| `/users` | Team management |
| `/inventory/bottle/:id` | Bottle detail |
| `/inventory/product/:id` | Product detail |
| `/inventory/register-bottle` | Register new bottle |
| `/inventory/add-product` | Add new product |

### Authentication

- JWT access + refresh tokens stored in `flutter_secure_storage`
- `QueuedInterceptorsWrapper` handles 401 → token refresh → retry (no stampede)
- Role cached in memory for synchronous router redirect checks

### State management

- `AsyncNotifier` (SWR) for mutable lists: `BottlesNotifier`, `ProductsNotifier`
- `FutureProvider.autoDispose.family` for paginated/filtered data (pours)
- `StateProvider` for UI state (filter, page number)
- `QueueStatusNotifier` — watches connectivity, drains offline queue on reconnect

### Offline queue

```
User mutation
     │
     ▼
optimisticApply() — update UI immediately
     │
     ▼
 HTTP call ───────────────────────────┐
     │ success                        │ offline (no network)
     ▼                                ▼
update cache                  enqueue to SQLite
                               keep optimistic state
                                      │
                              connectivity restored
                                      │
                              QueueStatusNotifier drains queue
                              retries ≤ 3 · 4xx = permanent drop
```

Pending count shown as a badge on the Inventory screen app bar.

---

## 2. Backend (ASP.NET Core)

### Tech stack
- .NET 9, minimal hosting model (`WebApplication.CreateBuilder`)
- Entity Framework Core 9 + SQLite
- JWT bearer authentication (access 15 min / refresh 7 day)
- Service-layer pattern: thin controllers + `IXxxService` interfaces

### API surface (abridged)

| Area | Base path |
|---|---|
| Auth | `POST /api/auth/login`, `/refresh`, `/logout` |
| Organisation | `GET/PUT /api/organisation` |
| Venues | `CRUD /api/venues` |
| Devices | `CRUD /api/devices`, `POST /:id/readings`, `POST /:id/heartbeat`, `POST /:id/rfid-placement`, `POST /:id/rfid-removal` |
| Products | `CRUD /api/products`, `GET /barcode/:code` |
| Bottles | `CRUD /api/bottles`, `GET /:id/pours`, `POST /:id/retire` |
| Pour events | `GET /api/pour-events`, `/summary`, `/after-hours`, `/oversize` |
| Alerts | `GET/PUT /api/alerts/config`, `POST /:id/acknowledge` |
| Users | `GET /api/users`, `POST /invite`, `PATCH /:id` |
| Analytics | `GET /api/analytics/summary`, `/compare-venues` |
| Reports | `GET /api/reports/pdf` |
| Device registration | `POST /api/devices/register` (used by firmware on first boot) |

---

## 3. Firmware (ESP32-C3)

### Hardware — GPIO map

| GPIO | Signal | Component |
|---|---|---|
| 4 | HX711 DOUT | Load cell (data) |
| 5 | HX711 SCK | Load cell (clock) |
| 2 | RFID MISO | RC522 (SPI2) |
| 6 | RFID CLK | RC522 (SPI2) |
| 7 | RFID MOSI | RC522 (SPI2) |
| 8 | RFID RST | RC522 reset |
| 10 | RFID CS | RC522 chip select |
| 3 | ADC1_CH3 | LiPo via 100k/100k divider |
| 9 | BOOT button | Factory reset trigger |

### Source layout

```
src/
├── main.c          Entry point, task creation, boot sequence
├── hx711.c         Load-cell driver (GPIO bit-bang, NVS calibration)
├── battery.c       LiPo ADC (3.2–4.2 V range, ADC1_CH3)
├── rfid.c          RC522 SPI driver (UID read, 4/7-byte anticollision)
├── wifi.c          Wi-Fi STA mode (credentials from NVS)
├── http_client.c   Device registration, readings, RFID events, heartbeat
└── provisioning.c  SoftAP + DNS spoofer + captive-portal HTTP server

include/
├── config.h        GPIO pins, NVS keys, timing constants, compile defaults
├── hx711.h
├── battery.h
├── rfid.h
├── wifi.h
├── http_client.h
└── provisioning.h
```

### FreeRTOS task architecture

```
app_main()
    │
    ├── scale_task     (prio 5)  — HX711 read every 1 s
    │                              POST /api/devices/{guid}/readings
    │
    ├── rfid_task      (prio 4)  — RC522 poll every 200 ms
    │                              3× debounce → POST rfid-placement / rfid-removal
    │
    └── heartbeat_task (prio 3)  — every 30 s
                                   POST /api/devices/{guid}/heartbeat
                                   { batteryMv, rssi }
```

### NVS key map (namespace: `pm_device`)

| Key | Type | Content |
|---|---|---|
| `device_guid` | str | UUID from backend (survives factory reset) |
| `wifi_ssid` | str | Venue Wi-Fi SSID |
| `wifi_pass` | str | Venue Wi-Fi password |
| `backend_url` | str | Backend base URL |
| `hx711_cal/tare` | i32 | Tare offset |
| `hx711_cal/scale` | u32 | Scale factor (raw float bits) |

---

## 4. Provisioning Flow

On first boot (no `wifi_ssid` in NVS) or after factory reset:

```
Power on
    │
    ▼
NVS has wifi_ssid? ──YES──▶ Normal boot (§3 tasks)
    │ NO
    ▼
Start SoftAP  "PourMetrics-XXXX"  (open, XXXX = MAC last 4)
    │
    ├── DNS spoofer task (UDP :53)
    │     all queries → 192.168.4.1
    │     triggers iOS / Android captive-portal browser prompt
    │
    └── HTTP server (TCP :80)
          GET  /              → HTML setup form
          POST /save          → parse ssid+pass+url, write NVS, success page
          GET  /*             → 302 → /  (catch-all for captive portal probes)
    │
    ▼
Admin fills form & submits
    │
    ▼
NVS write → esp_restart()
    │
    ▼
Normal boot → STA mode → register device → start tasks
```

### Factory reset

Hold BOOT (GPIO 9) for **3 seconds** at power-on.  
Clears `wifi_ssid`, `wifi_pass`, `backend_url`.  
**Device GUID is preserved** — backend retains the device record.

### Flutter setup guide (`/devices/setup`)

Step-by-step screen accessible via **+** on the Smart Coasters list (admin only):

1. Power on coaster — LED pulses blue
2. Connect phone Wi-Fi to `PourMetrics-XXXX`
3. Browser auto-opens (captive portal) or navigate to `192.168.4.1`
4. Enter SSID, password, backend URL → Save & Connect
5. Reconnect phone to normal Wi-Fi — device appears in list within ~1 min

---

## 5. RFID Bottle Tracking Flow

```
Bottle (with embedded RFID tag) placed on coaster
    │
    ▼
rfid_task reads UID — 3 consecutive hits required (debounce)
    │
    ▼
POST /api/devices/{guid}/rfid-placement  { tagId: "A1B2C3D4" }
    │
    ▼
Backend: look up Bottle by rfidTag → open pour session on this device
    │
Weight readings (every 1 s) are now attributed to this bottle
    │
    ▼
Bottle lifted — 3 consecutive misses (debounce)
    │
    ▼
POST /api/devices/{guid}/rfid-removal  { tagId: "A1B2C3D4" }
    │
    ▼
Backend: close pour session → compute volume from weight delta
         → PourEvent created → alert rules evaluated (oversize / after-hours)
```

---

## 6. Data Flow Summary

### Normal operation (online)

```
Coaster ──POST /readings──▶ Backend ──▶ DB
                                  └──▶ alert engine
Mobile app ──GET /summary──▶ Backend ──▶ Dashboard, Pours, Alerts
```

### Offline (mobile app)

```
Mutation ──▶ optimistic UI update
         └──▶ SQLite pending_mutations
                    │
           connectivity restored
                    │
              drain queue ──▶ Backend
              (retry ≤ 3, drop on 4xx)
```

### Stale-While-Revalidate (mobile cache)

```
Fetch request
    │
    ▼
SQLite cache hit? ──YES──▶ return immediately
                           + background refresh → update cache
    │ NO
    ▼
blocking fetch ──▶ write cache ──▶ return
```
