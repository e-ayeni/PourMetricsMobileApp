import 'package:dio/dio.dart';

/// Returns fake data for every API endpoint so the UI can be developed
/// without a running backend. Only active when _bypassAuth = true.
class MockInterceptor extends Interceptor {
  final List<Map<String, dynamic>> _products = List.from(_seedProducts);
  final List<Map<String, dynamic>> _bottles = List.from(_seedBottles);
  final List<Map<String, dynamic>> _calibrationSessions = [];
  final List<Map<String, dynamic>> _users = [
    {
      'id': 'usr-001',
      'email': 'admin@pourmetrics.com',
      'role': 'Admin',
      'firstName': 'Alex',
      'lastName': 'Barker',
      'isActive': true,
    },
    {
      'id': 'usr-002',
      'email': 'manager@pourmetrics.com',
      'role': 'Manager',
      'firstName': 'Sam',
      'lastName': 'Okafor',
      'isActive': true,
    },
    {
      'id': 'usr-003',
      'email': 'bartender1@pourmetrics.com',
      'role': 'Bartender',
      'firstName': 'Jess',
      'lastName': 'Adeyemi',
      'isActive': true,
    },
    {
      'id': 'usr-004',
      'email': 'exstaff@pourmetrics.com',
      'role': 'Bartender',
      'firstName': 'Dan',
      'lastName': 'Mills',
      'isActive': false,
    },
  ];

  Map<String, dynamic> _alertConfig = {
    'oversizeThresholdMl': 50,
    'afterHoursStart': '23:00',
    'afterHoursEnd': '06:00',
    'enabled': true,
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final result = _resolve(options);
    handler.resolve(Response(
      requestOptions: options,
      statusCode: result.$1,
      data: result.$2,
    ));
  }

  (int, dynamic) _resolve(RequestOptions options) {
    final path = options.path;
    final method = options.method;
    final body = options.data;

    if (path.contains('/auth/')) {
      return (200, {'accessToken': 'mock', 'refreshToken': 'mock'});
    }

    if (path.endsWith('/users/me')) {
      return (
        200,
        {
          'id': 'usr-001',
          'email': 'admin@pourmetrics.com',
          'role': 'Admin',
          'firstName': 'Alex',
          'lastName': 'Barker',
        }
      );
    }

    if (path.contains('/pour-events/summary')) {
      final now = DateTime.now();
      final currentHour = now.hour;
      final hourlyPours = <Map<String, dynamic>>[];
      for (int h = 10; h <= currentHour; h++) {
        final isEveningRush = h >= 20 && h <= 23;
        final isLunchRush = h >= 12 && h <= 14;
        final base = isEveningRush
            ? 18
            : isLunchRush
                ? 12
                : 5;
        final count = base + (h * 3) % 7;
        hourlyPours.add({
          'hour': h,
          'count': count,
          'revenue': count * 8.50,
        });
      }
      return (
        200,
        {
          'totalPours': 142,
          'totalRevenue': 3840.50,
          'averageVolumeMl': 38.2,
          'oversizeCount': 7,
          'afterHoursCount': 3,
          'hourlyPours': hourlyPours,
          'topProducts': [
            {'name': 'Jack Daniels', 'pourCount': 38, 'revenue': 323.0},
            {'name': 'Johnnie Walker Black', 'pourCount': 29, 'revenue': 275.5},
            {'name': 'Grey Goose', 'pourCount': 26, 'revenue': 273.0},
            {'name': 'Patron Silver', 'pourCount': 21, 'revenue': 241.5},
            {'name': 'Hendricks Gin', 'pourCount': 18, 'revenue': 189.0},
          ],
        }
      );
    }

    if (path.contains('/pour-events') && method == 'GET') {
      final pool = List.generate(
          60,
          (i) => {
                'id': 'pe-$i',
                'productName': _staticProducts[i % _staticProducts.length],
                'venueName': _venues[i % _venues.length],
                'volumeMl': 30.0 + (i % 6) * 5.0,
                'estimatedRevenue': 7.50 + (i % 8) * 1.25,
                'isOversize': i % 7 == 0,
                'isAfterHours': i % 9 == 0,
                'timestamp': DateTime.now()
                    .subtract(Duration(hours: i * 3))
                    .toIso8601String(),
              });

      final fromStr = options.queryParameters['from'] as String?;
      final toStr = options.queryParameters['to'] as String?;
      final oversizeOnly = options.queryParameters['isOversize'] == 'true';
      final afterHoursOnly = options.queryParameters['isAfterHours'] == 'true';
      final page =
          int.tryParse(options.queryParameters['page']?.toString() ?? '1') ?? 1;
      const pageSize = 20;

      final filtered = pool.where((e) {
        final ts = DateTime.parse(e['timestamp'] as String);
        if (fromStr != null && ts.isBefore(DateTime.parse(fromStr))) {
          return false;
        }
        if (toStr != null && ts.isAfter(DateTime.parse(toStr))) return false;
        if (oversizeOnly && e['isOversize'] != true) return false;
        if (afterHoursOnly && e['isAfterHours'] != true) return false;
        return true;
      }).toList();

      final start = ((page - 1) * pageSize).clamp(0, filtered.length);
      final end = (start + pageSize).clamp(0, filtered.length);
      return (200, filtered.sublist(start, end));
    }

    if (path.endsWith('/alerts') && method == 'GET') {
      return (
        200,
        [
          {
            'id': 'al-001',
            'type': 'Oversize Pour',
            'message': 'Jack Daniels — 65 ml detected (threshold 50 ml)',
            'isAcknowledged': false,
            'triggeredAt': DateTime.now()
                .subtract(const Duration(minutes: 23))
                .toIso8601String(),
          },
          {
            'id': 'al-002',
            'type': 'Battery Low',
            'message': 'Coaster 3 — battery at 12%',
            'isAcknowledged': false,
            'triggeredAt': DateTime.now()
                .subtract(const Duration(hours: 1))
                .toIso8601String(),
          },
          {
            'id': 'al-003',
            'type': 'After Hours',
            'message': 'Grey Goose poured at 02:14',
            'isAcknowledged': true,
            'triggeredAt': DateTime.now()
                .subtract(const Duration(hours: 6))
                .toIso8601String(),
          },
        ]
      );
    }

    if (path.contains('/alerts/') && path.contains('/acknowledge')) {
      return (200, {});
    }

    if (path.contains('/alerts/config')) {
      if (method == 'PUT') {
        _alertConfig = {
          ..._alertConfig,
          ...(body as Map<String, dynamic>? ?? {}),
        };
        return (200, _alertConfig);
      }
      return (200, _alertConfig);
    }

    if (path.contains('/products/barcode/') && method == 'GET') {
      final barcode = path.split('/products/barcode/').last;
      final match = _products.firstWhere((p) => p['barcode'] == barcode,
          orElse: () => {});
      return match.isEmpty
          ? (404, {'message': 'Product not found'})
          : (200, match);
    }

    if (path.endsWith('/products/calibration-sessions') && method == 'POST') {
      final data = body as Map<String, dynamic>? ?? {};
      final id = 'cal-${_calibrationSessions.length}';
      final session = {
        'id': id,
        'deviceId': data['deviceId'],
        'productId': null,
        'name': data['name'] ?? 'New Product',
        'category': data['category'] ?? '',
        'barcode': data['barcode'],
        'bottleVolumeMl': (data['bottleVolumeMl'] as num?)?.toDouble() ?? 700.0,
        'liquidDensityGPerMl':
            (data['liquidDensityGPerMl'] as num?)?.toDouble() ?? 0.789,
        'referenceTemperatureC':
            (data['referenceTemperatureC'] as num?)?.toDouble(),
        'standardPourMl': (data['standardPourMl'] as num?)?.toDouble() ?? 25.0,
        'pourToleranceMode': _toleranceModeName(data['pourToleranceMode']),
        'pourToleranceMl': (data['pourToleranceMl'] as num?)?.toDouble() ?? 3.0,
        'pourTolerancePercent':
            (data['pourTolerancePercent'] as num?)?.toDouble() ?? 0.1,
        'sellingPricePerShot':
            (data['sellingPricePerShot'] as num?)?.toDouble() ?? 8.5,
        'costPricePerBottle': (data['costPricePerBottle'] as num?)?.toDouble(),
        'currency': data['currency'] ?? 'NGN',
        'emptyWeightG': null,
        'emptyCapturedAt': null,
        'fullWeightG': null,
        'fullCapturedAt': null,
        'status': 'Started',
        'createdAt': DateTime.now().toIso8601String(),
        'completedAt': null,
      };
      _calibrationSessions.add(session);
      return (200, session);
    }

    if (RegExp(r'/products/calibration-sessions/[^/]+$').hasMatch(path) &&
        method == 'GET') {
      final id = path.split('/').last;
      final session = _calibrationSessions.firstWhere((s) => s['id'] == id,
          orElse: () => {});
      return session.isEmpty ? (404, {}) : (200, session);
    }

    if (path.contains('/products/calibration-sessions/') &&
        path.endsWith('/capture-empty') &&
        method == 'POST') {
      final id = path.split('/')[path.split('/').length - 2];
      final idx = _calibrationSessions.indexWhere((s) => s['id'] == id);
      if (idx == -1) return (404, {});
      _calibrationSessions[idx] = {
        ..._calibrationSessions[idx],
        'emptyWeightG': 420.0 + idx * 5,
        'emptyCapturedAt': DateTime.now().toIso8601String(),
        'status': 'EmptyCaptured',
      };
      return (200, _calibrationSessions[idx]);
    }

    if (path.contains('/products/calibration-sessions/') &&
        path.endsWith('/capture-full') &&
        method == 'POST') {
      final id = path.split('/')[path.split('/').length - 2];
      final idx = _calibrationSessions.indexWhere((s) => s['id'] == id);
      if (idx == -1) return (404, {});
      if (_calibrationSessions[idx]['emptyWeightG'] == null) {
        return (409, {'message': 'Capture the empty bottle first.'});
      }
      _calibrationSessions[idx] = {
        ..._calibrationSessions[idx],
        'fullWeightG': 1180.0 + idx * 8,
        'fullCapturedAt': DateTime.now().toIso8601String(),
        'status': 'FullCaptured',
      };
      return (200, _calibrationSessions[idx]);
    }

    if (path.contains('/products/calibration-sessions/') &&
        path.endsWith('/complete') &&
        method == 'POST') {
      final id = path.split('/')[path.split('/').length - 2];
      final idx = _calibrationSessions.indexWhere((s) => s['id'] == id);
      if (idx == -1) return (404, {});
      final session = _calibrationSessions[idx];
      if (session['status'] != 'FullCaptured') {
        return (400, {'message': 'Calibration session is incomplete.'});
      }
      final product = _buildProduct(
        {
          ...session,
          'id': 'prod-${_products.length}',
          'isActive': true,
        },
      );
      _products.add(product);
      _calibrationSessions[idx] = {
        ...session,
        'productId': product['id'],
        'status': 'Completed',
        'completedAt': DateTime.now().toIso8601String(),
      };
      return (200, product);
    }

    if (path.contains('/products/calibration-sessions/') &&
        path.endsWith('/cancel') &&
        method == 'POST') {
      final id = path.split('/')[path.split('/').length - 2];
      final idx = _calibrationSessions.indexWhere((s) => s['id'] == id);
      if (idx == -1) return (404, {});
      _calibrationSessions[idx] = {
        ..._calibrationSessions[idx],
        'status': 'Cancelled',
      };
      return (200, _calibrationSessions[idx]);
    }

    if (path.endsWith('/products') && method == 'POST') {
      final data = body as Map<String, dynamic>? ?? {};
      final product = _buildProduct({
        ...data,
        'id': 'prod-${_products.length}',
        'isActive': true,
      });
      _products.add(product);
      return (201, product);
    }

    if (RegExp(r'/products/[^/]+$').hasMatch(path) && method == 'PUT') {
      final id = path.split('/').last;
      final idx = _products.indexWhere((x) => x['id'] == id);
      if (idx == -1) return (404, {});
      final data = body as Map<String, dynamic>? ?? {};
      _products[idx] = _buildProduct({..._products[idx], ...data});
      return (200, _products[idx]);
    }

    if (path.endsWith('/products') && method == 'GET') {
      return (200, _products);
    }

    if (RegExp(r'/products/[^/]+$').hasMatch(path) && method == 'GET') {
      final id = path.split('/').last;
      final product =
          _products.firstWhere((x) => x['id'] == id, orElse: () => {});
      return product.isEmpty ? (404, {}) : (200, product);
    }

    if (path.endsWith('/bottles') && method == 'POST') {
      final data = body as Map<String, dynamic>? ?? {};
      final productId = data['productId'] as String? ?? '';
      final product = _products.firstWhere(
        (p) => p['id'] == productId,
        orElse: () => _buildProduct({
          'name': 'Unknown',
          'emptyWeightG': 420,
          'fullWeightG': 1200,
          'bottleVolumeMl': 700,
          'liquidDensityGPerMl': 0.789,
        }),
      );
      final bottle = {
        'id': 'bot-${_bottles.length}',
        'rfidTag': data['rfidTag'] ?? 'RF${_bottles.length + 1000}',
        'productId': productId,
        'productName': product['name'],
        'venueId': data['venueId'],
        'venueName': _venues[_bottles.length % _venues.length],
        'currentWeightG': (product['fullWeightG'] as num).toDouble(),
        'fullWeightG': (product['fullWeightG'] as num).toDouble(),
        'emptyWeightG': (product['emptyWeightG'] as num).toDouble(),
        'coasterName': null,
        'barLocation': null,
        'isRetired': false,
      };
      _bottles.add(bottle);
      return (201, bottle);
    }

    if (RegExp(r'/bottles/[^/]+$').hasMatch(path) && method == 'PUT') {
      final id = path.split('/').last;
      final idx = _bottles.indexWhere((x) => x['id'] == id);
      if (idx == -1) return (404, {});
      final data = body as Map<String, dynamic>? ?? {};
      _bottles[idx] = {..._bottles[idx], ...data};
      return (200, _bottles[idx]);
    }

    if (RegExp(r'/bottles/[^/]+$').hasMatch(path) && method == 'DELETE') {
      final id = path.split('/').last;
      final idx = _bottles.indexWhere((x) => x['id'] == id);
      if (idx == -1) return (404, {});
      _bottles[idx] = {..._bottles[idx], 'isRetired': true};
      return (204, null);
    }

    if (path.endsWith('/bottles') && method == 'GET') {
      return (200, _bottles);
    }

    if (RegExp(r'/bottles/[^/]+$').hasMatch(path) && method == 'GET') {
      final id = path.split('/').last;
      final bottle =
          _bottles.firstWhere((x) => x['id'] == id, orElse: () => {});
      return bottle.isEmpty ? (404, {}) : (200, bottle);
    }

    if (path.endsWith('/devices') && method == 'GET') {
      final now = DateTime.now();
      return (
        200,
        [
          {
            'id': 'dev-0',
            'macAddress': '00:1A:2B:3C:4D:01',
            'coasterName': 'Coaster 1',
            'barLocation': 'Bar 1',
            'venueName': 'Skybar Rooftop',
            'firmwareVersion': '1.4.4',
            'batteryVoltage': 3.68,
            'lastSeenAt':
                now.subtract(const Duration(minutes: 2)).toIso8601String(),
            'isActive': true,
          },
          {
            'id': 'dev-1',
            'macAddress': '00:1A:2B:3C:4D:02',
            'coasterName': 'Coaster 2',
            'barLocation': 'Bar 2',
            'venueName': 'The Grand Lounge',
            'firmwareVersion': '1.4.4',
            'batteryVoltage': 3.42,
            'lastSeenAt':
                now.subtract(const Duration(minutes: 4)).toIso8601String(),
            'isActive': true,
          },
          {
            'id': 'dev-2',
            'macAddress': '00:1A:2B:3C:4D:03',
            'coasterName': 'Coaster 3',
            'barLocation': 'Bar 1',
            'venueName': 'Skybar Rooftop',
            'firmwareVersion': '1.4.3',
            'batteryVoltage': 3.08,
            'lastSeenAt':
                now.subtract(const Duration(minutes: 8)).toIso8601String(),
            'isActive': true,
          },
          {
            'id': 'dev-3',
            'macAddress': '00:1A:2B:3C:4D:04',
            'coasterName': 'Coaster 4',
            'barLocation': 'Bar 4',
            'venueName': 'Lobby Bar',
            'firmwareVersion': '1.4.2',
            'batteryVoltage': 3.55,
            'lastSeenAt':
                now.subtract(const Duration(hours: 2)).toIso8601String(),
            'isActive': true,
          },
        ]
      );
    }

    if (path.contains('/organisation')) {
      return (
        200,
        {
          'id': 'org-001',
          'name': 'The Grand Hotel Group',
          'contactEmail': 'ops@grandhotel.com',
        }
      );
    }

    if (path.endsWith('/venues') && method == 'GET') {
      return (
        200,
        List.generate(
            _venues.length,
            (i) => {
                  'id': 'ven-$i',
                  'name': _venues[i],
                  'address': '$i Main St, City',
                  'isActive': true,
                })
      );
    }

    if (path.contains('/analytics')) {
      return (
        200,
        {
          'totalRevenue': 18420.75,
          'totalPours': 612,
          'averageVolumeMl': 37.4,
          'accuracyScore': 94.2,
        }
      );
    }

    if (path.endsWith('/users/invite') && method == 'POST') {
      final data = body as Map<String, dynamic>? ?? {};
      final newUser = {
        'id': 'usr-${_users.length + 1}',
        'email': data['email'] ?? 'new@example.com',
        'role': data['role'] ?? 'Bartender',
        'firstName': '',
        'lastName': '',
        'isActive': true,
      };
      _users.add(newUser);
      return (201, newUser);
    }

    if (RegExp(r'/users/[^/]+$').hasMatch(path) && method == 'PATCH') {
      final id = path.split('/').last;
      final idx = _users.indexWhere((u) => u['id'] == id);
      if (idx == -1) return (404, {});
      final data = body as Map<String, dynamic>? ?? {};
      _users[idx] = {..._users[idx], ...data};
      return (200, _users[idx]);
    }

    if (path.endsWith('/users') && method == 'GET') {
      return (200, _users);
    }

    return (200, {});
  }

  Map<String, dynamic> _buildProduct(Map<String, dynamic> data) {
    final standardPourMl = (data['standardPourMl'] as num?)?.toDouble() ?? 25.0;
    final sellingPrice =
        (data['sellingPricePerShot'] as num?)?.toDouble() ?? 8.50;
    final toleranceMode = _toleranceModeName(data['pourToleranceMode']);

    return {
      'id': data['id'] ?? 'prod-${_products.length}',
      'name': data['name'] ?? 'New Product',
      'category': data['category'] ?? '',
      'barcode': data['barcode'],
      'imageUrl': data['imageUrl'],
      'emptyWeightG': (data['emptyWeightG'] as num?)?.toDouble() ?? 420.0,
      'fullWeightG': (data['fullWeightG'] as num?)?.toDouble() ?? 1200.0,
      'bottleVolumeMl': (data['bottleVolumeMl'] as num?)?.toDouble() ?? 700.0,
      'liquidDensityGPerMl':
          (data['liquidDensityGPerMl'] as num?)?.toDouble() ?? 0.789,
      'referenceTemperatureC':
          (data['referenceTemperatureC'] as num?)?.toDouble(),
      'standardPourMl': standardPourMl,
      'pourToleranceMode': toleranceMode,
      'pourToleranceMl': (data['pourToleranceMl'] as num?)?.toDouble() ?? 3.0,
      'pourTolerancePercent':
          (data['pourTolerancePercent'] as num?)?.toDouble() ?? 0.1,
      'pricePerMl': standardPourMl == 0 ? 0 : sellingPrice / standardPourMl,
      'sellingPricePerShot': sellingPrice,
      'costPricePerBottle': (data['costPricePerBottle'] as num?)?.toDouble(),
      'currency': data['currency'] ?? 'NGN',
      'isActive': data['isActive'] ?? true,
    };
  }

  String _toleranceModeName(dynamic value) {
    if (value is String &&
        (value == 'FixedMl' || value == 'Percentage' || value == 'Hybrid')) {
      return value;
    }
    if (value is num) {
      switch (value.toInt()) {
        case 0:
          return 'FixedMl';
        case 1:
          return 'Percentage';
        default:
          return 'Hybrid';
      }
    }
    return 'Hybrid';
  }

  static const _staticProducts = [
    'Jack Daniels',
    'Grey Goose',
    'Hendricks Gin',
    'Johnnie Walker Black',
    'Patron Silver',
    'Absolut Vodka',
  ];

  static const _venues = [
    'Skybar Rooftop',
    'The Grand Lounge',
    'Pool Bar',
    'Lobby Bar',
  ];

  static final _seedProducts = <Map<String, dynamic>>[
    {
      'id': 'prod-0',
      'name': 'Jack Daniels',
      'category': 'Whiskey',
      'barcode': '5012345000001',
      'standardPourMl': 25.0,
      'sellingPricePerShot': 8.50,
      'emptyWeightG': 420.0,
      'fullWeightG': 1200.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.942,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 3.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
    {
      'id': 'prod-1',
      'name': 'Grey Goose',
      'category': 'Vodka',
      'barcode': '5012345000002',
      'standardPourMl': 25.0,
      'sellingPricePerShot': 10.50,
      'emptyWeightG': 380.0,
      'fullWeightG': 1100.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.953,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 3.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
    {
      'id': 'prod-2',
      'name': 'Hendricks Gin',
      'category': 'Gin',
      'barcode': '5012345000003',
      'standardPourMl': 35.0,
      'sellingPricePerShot': 10.50,
      'emptyWeightG': 400.0,
      'fullWeightG': 1150.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.948,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 4.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
    {
      'id': 'prod-3',
      'name': 'Johnnie Walker Black',
      'category': 'Whiskey',
      'barcode': '5012345000004',
      'standardPourMl': 25.0,
      'sellingPricePerShot': 9.50,
      'emptyWeightG': 430.0,
      'fullWeightG': 1220.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.941,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 3.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
    {
      'id': 'prod-4',
      'name': 'Patron Silver',
      'category': 'Tequila',
      'barcode': '5012345000005',
      'standardPourMl': 25.0,
      'sellingPricePerShot': 11.50,
      'emptyWeightG': 360.0,
      'fullWeightG': 1080.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.947,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 3.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
    {
      'id': 'prod-5',
      'name': 'Absolut Vodka',
      'category': 'Vodka',
      'barcode': '5012345000006',
      'standardPourMl': 25.0,
      'sellingPricePerShot': 6.50,
      'emptyWeightG': 390.0,
      'fullWeightG': 1100.0,
      'bottleVolumeMl': 700.0,
      'liquidDensityGPerMl': 0.952,
      'referenceTemperatureC': 20.0,
      'pourToleranceMode': 'Hybrid',
      'pourToleranceMl': 3.0,
      'pourTolerancePercent': 0.1,
      'currency': 'NGN',
      'isActive': true,
    },
  ];

  static final _seedBottles = <Map<String, dynamic>>[
    {
      'id': 'bot-0',
      'rfidTag': 'RF1001',
      'productId': 'prod-0',
      'productName': 'Jack Daniels',
      'venueId': 'ven-0',
      'venueName': 'Skybar Rooftop',
      'currentWeightG': 850.0,
      'fullWeightG': 1200.0,
      'emptyWeightG': 420.0,
      'coasterName': 'Coaster 1',
      'barLocation': 'Bar 1',
      'isRetired': false,
    },
    {
      'id': 'bot-1',
      'rfidTag': 'RF1002',
      'productId': 'prod-1',
      'productName': 'Grey Goose',
      'venueId': 'ven-1',
      'venueName': 'The Grand Lounge',
      'currentWeightG': 600.0,
      'fullWeightG': 1100.0,
      'emptyWeightG': 380.0,
      'coasterName': 'Coaster 2',
      'barLocation': 'Bar 2',
      'isRetired': false,
    },
    {
      'id': 'bot-2',
      'rfidTag': 'RF1003',
      'productId': 'prod-2',
      'productName': 'Hendricks Gin',
      'venueId': 'ven-2',
      'venueName': 'Pool Bar',
      'currentWeightG': 450.0,
      'fullWeightG': 1150.0,
      'emptyWeightG': 400.0,
      'coasterName': null,
      'barLocation': null,
      'isRetired': false,
    },
    {
      'id': 'bot-3',
      'rfidTag': 'RF1004',
      'productId': 'prod-3',
      'productName': 'Johnnie Walker Black',
      'venueId': 'ven-0',
      'venueName': 'Skybar Rooftop',
      'currentWeightG': 1220.0,
      'fullWeightG': 1220.0,
      'emptyWeightG': 430.0,
      'coasterName': 'Coaster 3',
      'barLocation': 'Bar 1',
      'isRetired': false,
    },
    {
      'id': 'bot-4',
      'rfidTag': 'RF1005',
      'productId': 'prod-4',
      'productName': 'Patron Silver',
      'venueId': 'ven-3',
      'venueName': 'Lobby Bar',
      'currentWeightG': 500.0,
      'fullWeightG': 1080.0,
      'emptyWeightG': 360.0,
      'coasterName': 'Coaster 4',
      'barLocation': 'Bar 4',
      'isRetired': false,
    },
    {
      'id': 'bot-5',
      'rfidTag': 'RF1006',
      'productId': 'prod-5',
      'productName': 'Absolut Vodka',
      'venueId': 'ven-1',
      'venueName': 'The Grand Lounge',
      'currentWeightG': 430.0,
      'fullWeightG': 1100.0,
      'emptyWeightG': 390.0,
      'coasterName': null,
      'barLocation': null,
      'isRetired': true,
    },
  ];
}
