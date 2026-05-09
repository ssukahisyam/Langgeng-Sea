import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'user_profile_dao.g.dart';

/// DAO for the single-row [UserProfiles] table.
///
/// Invariant: at most one row exists (id = [kProfileRowId]). All writes go
/// through [upsertProfile] which uses INSERT OR REPLACE so callers never
/// have to distinguish first-save vs. edit.
@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  /// Fixed id so we never insert a second profile row by accident.
  static const int kProfileRowId = 1;

  /// Returns the singleton profile, or null if onboarding hasn't happened yet.
  Future<UserProfileRow?> getProfile() {
    return (select(userProfiles)
          ..where((p) => p.id.equals(kProfileRowId))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Reactive variant for UI that should refresh when the profile changes
  /// (top bar greeting, settings card, etc.).
  Stream<UserProfileRow?> watchProfile() {
    return (select(userProfiles)
          ..where((p) => p.id.equals(kProfileRowId))
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Create or update the singleton profile row.
  ///
  /// [companion] must NOT set `id` — we force it to [kProfileRowId] so
  /// callers can't accidentally create a second profile.
  Future<void> upsertProfile(UserProfilesCompanion companion) {
    return into(userProfiles).insertOnConflictUpdate(
      companion.copyWith(id: const Value(kProfileRowId)),
    );
  }

  /// Remove the profile (back to "not onboarded" state).
  Future<int> deleteProfile() =>
      (delete(userProfiles)..where((p) => p.id.equals(kProfileRowId))).go();
}
