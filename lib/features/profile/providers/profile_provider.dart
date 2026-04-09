import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/user_profile.dart';

final profileProvider = FutureProvider.autoDispose<UserProfile>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(ApiConstants.me);
  return UserProfile.fromJson(response.data as Map<String, dynamic>);
});
