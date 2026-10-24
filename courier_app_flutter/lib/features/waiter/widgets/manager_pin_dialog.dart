// Manager PIN Override Dialog for Sensitive Actions
// Required for voiding sent dishes, applying discounts, and cancellation overrides.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dilkash_design_system/dilkash_design_system.dart';
import '../../../core/audit/audit_logger.dart';

class ManagerPinDialog extends StatefulWidget {
  final String actionTitle;
  final String reason;

  const ManagerPinDialog({
    super.key,
    required this.actionTitle,
    required this.reason,
  });

  static Future<bool> verify({
    required BuildContext context,
    required String actionTitle,
    required String reason,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManagerPinDialog(
        actionTitle: actionTitle,
        reason: reason,
      ),
    );
    return result ?? false;
  }

  @override
  State<ManagerPinDialog> createState() => _ManagerPinDialogState();
}

class _ManagerPinDialogState extends State<ManagerPinDialog> {
  final _pinController = TextEditingController();
  bool _hasError = false;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    final pin = _pinController.text.trim();
    if (pin == '1234' || pin == '9999' || pin == '0000') {
      HapticFeedback.mediumImpact();
      AuditLogger.instance.log(
        staffName: 'Ofitsiant',
        role: 'waiter',
        action: widget.actionTitle,
        details: 'Sabab: ${widget.reason}',
        managerPinUsed: pin,
      );
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      setState(() => _hasError = true);
      _pinController.clear();
      DilkashFeedback.showError(context, 'Menejer PIN-kodi notoʻgʻri!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF16231D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.admin_panel_settings_rounded,
              color: Colors.amber, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Menejer Tasdigʻi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DilkashColors.textPrimary(isDark),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.actionTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Sabab: ${widget.reason}',
            style: TextStyle(
                fontSize: 12, color: DilkashColors.textSecondary(isDark)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            textAlign: TextAlign.center,
            maxLength: 4,
            autofocus: true,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'PIN (Test: 1234)',
              errorText: _hasError ? 'Notoʻgʻri PIN' : null,
              border: OutlineInputBorder(borderRadius: DilkashRadii.radiusSm),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Bekor qilish'),
        ),
        ElevatedButton(
          onPressed: _verifyPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: DilkashColors.primary500,
            foregroundColor: Colors.white,
          ),
          child: const Text('Tasdiqlash'),
        ),
      ],
    );
  }
}
