import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore returns [Timestamp]s; the models work with [DateTime].
Map<String, dynamic> normalizeTimestamps(Map<String, dynamic> data) {
  return data.map((key, value) =>
      MapEntry(key, value is Timestamp ? value.toDate() : value));
}
