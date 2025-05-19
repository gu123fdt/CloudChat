import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:cloudchat/utils/voip/sound_service.dart';
import 'package:cloudchat/widgets/matrix.dart';

class SettingsSelectInputDeviceListTile extends StatefulWidget {
  final ValueChanged<bool>? onChanged;

  const SettingsSelectInputDeviceListTile({super.key, this.onChanged});

  @override
  _SettingsSelectInputDeviceListTileState createState() =>
      _SettingsSelectInputDeviceListTileState();
}

class _SettingsSelectInputDeviceListTileState
    extends State<SettingsSelectInputDeviceListTile> {
  late SoundService _soundService;

  @override
  void initState() {
    super.initState();
    _soundService = Matrix.of(context).soundService!;
    _initializeSelection();
  }

  Future<void> _initializeSelection() async {
    final savedId = _soundService.selectedInputId;
    if (savedId == null ||
        !_soundService.inputs.any((d) => d.deviceId == savedId)) {
      if (_soundService.inputs.isNotEmpty) {
        await _soundService.selectInput(_soundService.inputs.first.deviceId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = _soundService.inputs;
    final selectedId = _soundService.selectedInputId;

    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 24, bottom: 8),
          child: Text(
            L10n.of(context).inputDevice,
            style: TextStyle(color: theme.colorScheme.secondary, fontSize: 17),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0),
              isExpanded: true,
              value: selectedId,
              items: [
                ...devices.map((device) {
                  return DropdownMenuItem<String>(
                    value: device.deviceId,
                    child: Text(device.label),
                  );
                }),
              ],
              onChanged: (newId) {
                setState(() {
                  _soundService.selectInput(newId!);
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
