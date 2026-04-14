class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'http://localhost:5000/api/v1';

  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';

  static const String me = '/users/me';
  static const String users = '/users';

  static const String venues = '/venues';
  static const String devices = '/devices';
  static const String products = '/products';
  static const String productCalibrationSessions =
      '/products/calibration-sessions';
  static const String bottles = '/bottles';
  static const String pourEvents = '/pour-events';
  static const String alerts = '/alerts';
  static const String analytics = '/analytics';
  static const String reports = '/reports';
  static const String organisation = '/organisation';
}
