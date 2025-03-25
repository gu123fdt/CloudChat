import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:record/record.dart';
import 'matrix.dart';

class SettingsSelectRecordDeviceListTile extends StatefulWidget {
  final String? defaultValue;
  final Function(bool)? onChanged;

  const SettingsSelectRecordDeviceListTile({
    super.key,
    this.defaultValue,
    this.onChanged,
  });

  @override
  SettingsSelectRecordDeviceListTileState createState() =>
      SettingsSelectRecordDeviceListTileState();
}

class SettingsSelectRecordDeviceListTileState
    extends State<SettingsSelectRecordDeviceListTile> {
  final _audioRecorder = AudioRecorder();
  List<InputDevice> devices = [];

  void loadInputDevice() async {
    final devices = await _audioRecorder.listInputDevices();
    setState(() {
      this.devices = devices;
    });
  }

  @override
  void initState() {
    super.initState();
    loadInputDevice();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDevice = Matrix.of(context).store.getString("recordDevice");

    if (devices.isEmpty) {
      return const SizedBox.shrink();
    }

    final String? currentDevice =
        devices.any((device) => device.id == selectedDevice)
            ? selectedDevice
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 24, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              L10n.of(context).recordDivace,
              style: TextStyle(
                color: theme.colorScheme.secondary,
                fontSize: 17,
              ),
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              padding: const EdgeInsets.only(left: 24.0, right: 24.0),
              value: currentDevice,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text("Default"),
                ),
                ...devices.map<DropdownMenuItem<String>>((device) {
                  return DropdownMenuItem<String>(
                    value: device.id,
                    child: Text(device.label),
                  );
                }),
              ],
              onChanged: (device) {
                FocusScope.of(context).requestFocus(FocusNode());

                if (device != null) {
                  Matrix.of(context).store.setString("recordDevice", device);
                } else {
                  Matrix.of(context).store.remove("recordDevice");
                }

                setState(() {});
              },
            ),
          ),
        ),
      ],
    );
  }
}
