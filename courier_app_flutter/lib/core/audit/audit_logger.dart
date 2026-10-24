// Audit Logger for Sensitive Staff Actions
// Logs voids, discounts, manager PIN overrides, and cash discrepancies.

class AuditLogEntry {
  final String id;
  final DateTime timestamp;
  final String staffName;
  final String role;
  final String action;
  final String details;
  final String? managerPinUsed;

  const AuditLogEntry({
    required this.id,
    required this.timestamp,
    required this.staffName,
    required this.role,
    required this.action,
    required this.details,
    this.managerPinUsed,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'staff_name': staffName,
        'role': role,
        'action': action,
        'details': details,
        'manager_pin_used': managerPinUsed != null ? '****' : null,
      };
}

class AuditLogger {
  AuditLogger._();
  static final AuditLogger instance = AuditLogger._();

  final List<AuditLogEntry> _logs = [];
  List<AuditLogEntry> get logs => List.unmodifiable(_logs);

  void log({
    required String staffName,
    required String role,
    required String action,
    required String details,
    String? managerPinUsed,
  }) {
    final entry = AuditLogEntry(
      id: 'audit_${DateTime.now().millisecondsSinceEpoch}_${_logs.length}',
      timestamp: DateTime.now(),
      staffName: staffName,
      role: role,
      action: action,
      details: details,
      managerPinUsed: managerPinUsed,
    );
    _logs.insert(0, entry);
  }
}
