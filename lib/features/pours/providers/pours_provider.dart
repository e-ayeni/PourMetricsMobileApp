import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';

// ── Filter model ──────────────────────────────────────────────────────────────

enum DatePreset { today, yesterday, sevenDays, custom }

class PoursFilter {
  final DatePreset preset;
  final DateTime from;
  final DateTime to;
  final bool oversizeOnly;
  final bool afterHoursOnly;

  const PoursFilter._({
    required this.preset,
    required this.from,
    required this.to,
    required this.oversizeOnly,
    required this.afterHoursOnly,
  });

  factory PoursFilter.today() {
    final now = DateTime.now();
    return PoursFilter._(
      preset: DatePreset.today,
      from: DateTime(now.year, now.month, now.day),
      to: now,
      oversizeOnly: false,
      afterHoursOnly: false,
    );
  }

  PoursFilter copyWith({
    DatePreset? preset,
    DateTime? from,
    DateTime? to,
    bool? oversizeOnly,
    bool? afterHoursOnly,
  }) =>
      PoursFilter._(
        preset: preset ?? this.preset,
        from: from ?? this.from,
        to: to ?? this.to,
        oversizeOnly: oversizeOnly ?? this.oversizeOnly,
        afterHoursOnly: afterHoursOnly ?? this.afterHoursOnly,
      );

  @override
  bool operator ==(Object other) =>
      other is PoursFilter &&
      preset == other.preset &&
      from == other.from &&
      to == other.to &&
      oversizeOnly == other.oversizeOnly &&
      afterHoursOnly == other.afterHoursOnly;

  @override
  int get hashCode =>
      Object.hash(preset, from, to, oversizeOnly, afterHoursOnly);
}

// ── Query model (filter + page) ───────────────────────────────────────────────

class PoursQuery {
  final PoursFilter filter;
  final int page;

  const PoursQuery({required this.filter, required this.page});

  @override
  bool operator ==(Object other) =>
      other is PoursQuery && filter == other.filter && page == other.page;

  @override
  int get hashCode => Object.hash(filter, page);
}

// ── Providers ─────────────────────────────────────────────────────────────────

final poursFilterProvider = StateProvider<PoursFilter>((ref) => PoursFilter.today());

final poursPageProvider = StateProvider<int>((ref) => 1);

final poursListProvider =
    FutureProvider.autoDispose.family<List<dynamic>, PoursQuery>(
        (ref, query) async {
  final dio = ref.watch(dioProvider);
  final params = <String, dynamic>{
    'from': query.filter.from.toIso8601String(),
    'to': query.filter.to.toIso8601String(),
    'page': query.page,
    'pageSize': 20,
    if (query.filter.oversizeOnly) 'isOversize': true,
    if (query.filter.afterHoursOnly) 'isAfterHours': true,
  };
  final response =
      await dio.get(ApiConstants.pourEvents, queryParameters: params);
  return response.data as List<dynamic>;
});
