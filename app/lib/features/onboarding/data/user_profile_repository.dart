import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../domain/entities/user_profile.dart';

/// Repository: converts [UserProfileRow] ↔ [UserProfile] and hides DAO
/// plumbing from the UI layer.
class UserProfileRepository {
  UserProfileRepository(this._db) : _dao = _db.userProfileDao;

  final AppDatabase _db;
  final UserProfileDao _dao;

  /// One-shot read.
  Future<UserProfile?> getProfile() async {
    final row = await _dao.getProfile();
    return row == null ? null : _fromRow(row);
  }

  /// Reactive read — UI auto-refreshes on upsert/delete.
  Stream<UserProfile?> watchProfile() {
    return _dao.watchProfile().map((row) => row == null ? null : _fromRow(row));
  }

  /// Save (create or update) the profile.
  ///
  /// If a profile already exists, [createdAt] is preserved and only
  /// [updatedAt] is bumped. Validation happens in [UserProfile.validate] at
  /// the UI layer — the repo just persists what it's given.
  Future<UserProfile> saveProfile({
    required String name,
    required String vesselName,
    required double trawlWidthMeters,
    double? vesselGt,
    String? homePort,
  }) async {
    final now = DateTime.now();
    final existing = await _dao.getProfile();
    final createdAt = existing?.createdAt ?? now;

    await _dao.upsertProfile(UserProfilesCompanion(
      name: Value(name.trim()),
      vesselName: Value(vesselName.trim()),
      vesselGt: Value(vesselGt),
      homePort: Value(homePort?.trim().isEmpty ?? true ? null : homePort!.trim()),
      trawlWidthMeters: Value(trawlWidthMeters),
      createdAt: Value(createdAt),
      updatedAt: Value(now),
    ),);

    return UserProfile(
      name: name.trim(),
      vesselName: vesselName.trim(),
      vesselGtOptional: vesselGt,
      homePortOptional:
          homePort?.trim().isEmpty ?? true ? null : homePort!.trim(),
      trawlWidthMeters: trawlWidthMeters,
      createdAt: createdAt,
      updatedAt: now,
    );
  }

  /// Remove profile — used for "reset onboarding" debug action. Not surfaced
  /// in the production UI.
  Future<void> deleteProfile() => _dao.deleteProfile();

  UserProfile _fromRow(UserProfileRow r) {
    return UserProfile(
      name: r.name,
      vesselName: r.vesselName,
      vesselGtOptional: r.vesselGt,
      homePortOptional: r.homePort,
      trawlWidthMeters: r.trawlWidthMeters,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
    );
  }
}

// =============================================================================
// Providers
// =============================================================================

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return UserProfileRepository(db);
});

/// Reactive profile stream — UI switches from Onboarding to main shell when
/// this emits a non-null value.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(userProfileRepositoryProvider).watchProfile();
});

/// One-shot variant for places that want a Future (e.g., initial boot gate
/// that hasn't subscribed to the stream yet).
final userProfileFutureProvider = FutureProvider<UserProfile?>((ref) {
  return ref.watch(userProfileRepositoryProvider).getProfile();
});
