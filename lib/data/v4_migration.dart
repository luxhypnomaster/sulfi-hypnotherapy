import 'dart:convert';

import '../models/session_plan.dart';
import '../models/modular_plan.dart';

Map<String, dynamic> migratePlanDocument(Map<String, dynamic> document) {
  final result = Map<String, dynamic>.from(document);
  if (result['plan'] is Map) {
    result['plan'] = modularize(
      SessionPlan.fromMap(Map<String, dynamic>.from(result['plan'])),
    ).toMap();
    if (result['baseFingerprint'] is String) {
      result['baseFingerprint'] = modularize(
        SessionPlan.fromMap(
          Map<String, dynamic>.from(jsonDecode(result['baseFingerprint'])),
        ),
      ).fingerprint;
    }
    result['draftSchemaVersion'] = 4;
  }
  if (result['snapshot'] is Map) {
    result['snapshot'] = migratePlanDocument(
      Map<String, dynamic>.from(result['snapshot']),
    );
    if (!result.containsKey('startedUtcOffsetMinutes')) {
      result['legacyTimezoneUnknown'] = true;
    }
  }
  return result;
}
