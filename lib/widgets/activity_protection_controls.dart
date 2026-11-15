import 'package:flutter/material.dart';

import '../models/activity.dart';

class ActivityProtectionControls extends StatelessWidget {
  final ActivityAttachmentAccess attachmentAccess;
  final ValueChanged<ActivityAttachmentAccess> onAttachmentAccessChanged;
  final int? timeLimitMinutes;
  final ValueChanged<int?> onTimeLimitChanged;
  final bool monitorFocusLoss;
  final ValueChanged<bool> onMonitorFocusLossChanged;

  const ActivityProtectionControls({
    super.key,
    required this.attachmentAccess,
    required this.onAttachmentAccessChanged,
    required this.timeLimitMinutes,
    required this.onTimeLimitChanged,
    required this.monitorFocusLoss,
    required this.onMonitorFocusLossChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Document access',
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      RadioListTile<ActivityAttachmentAccess>(
        contentPadding: EdgeInsets.zero,
        title: const Text('Allow downloads'),
        subtitle: const Text('Students can open the file in another app.'),
        value: ActivityAttachmentAccess.download,
        groupValue: attachmentAccess,
        onChanged: (value) {
          if (value != null) onAttachmentAccessChanged(value);
        },
      ),
      RadioListTile<ActivityAttachmentAccess>(
        contentPadding: EdgeInsets.zero,
        title: const Text('View only in EduSync'),
        subtitle: const Text(
          'Files open in the built-in reader; download links are not shared.',
        ),
        value: ActivityAttachmentAccess.viewOnly,
        groupValue: attachmentAccess,
        onChanged: (value) {
          if (value != null) onAttachmentAccessChanged(value);
        },
      ),
      DropdownButtonFormField<int>(
        value: timeLimitMinutes ?? 0,
        decoration: const InputDecoration(
          labelText: 'Activity timer',
          prefixIcon: Icon(Icons.timer_outlined),
          helperText:
              'Starts when the student begins; expiry is enforced in the app.',
        ),
        items: const [
          DropdownMenuItem(value: 0, child: Text('No timer')),
          DropdownMenuItem(value: 15, child: Text('15 minutes')),
          DropdownMenuItem(value: 30, child: Text('30 minutes')),
          DropdownMenuItem(value: 45, child: Text('45 minutes')),
          DropdownMenuItem(value: 60, child: Text('60 minutes')),
          DropdownMenuItem(value: 90, child: Text('90 minutes')),
          DropdownMenuItem(value: 120, child: Text('120 minutes')),
        ],
        onChanged: (value) =>
            onTimeLimitChanged(value == null || value == 0 ? null : value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Count app exits'),
        subtitle: const Text(
          'Records when the activity loses foreground; it cannot identify '
          'which app was opened or prevent switching.',
        ),
        value: monitorFocusLoss,
        onChanged: onMonitorFocusLossChanged,
      ),
      if (attachmentAccess == ActivityAttachmentAccess.viewOnly ||
          monitorFocusLoss)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Android screenshot blocking is best-effort. App switching cannot '
            'be prevented on unmanaged devices, and view-only cannot prevent '
            'external capture or a modified client.',
            style: TextStyle(fontSize: 12),
          ),
        ),
    ],
  );
}
