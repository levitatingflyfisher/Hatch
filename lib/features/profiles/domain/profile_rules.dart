import '../../../core/storage/app_database.dart';

/// The picker shows at most four hatchers — one shared device, one family.
const kMaxProfiles = 4;

/// A profile's display name. Names are optional (no typing required to
/// create), so an empty name renders as "Hatcher N" by grid position —
/// pre-reader friendly and never blank.
String profileDisplayName(Profile profile, int index) =>
    profile.name.isEmpty ? 'Hatcher ${index + 1}' : profile.name;
