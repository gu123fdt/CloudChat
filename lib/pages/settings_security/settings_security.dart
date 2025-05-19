import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:cloudchat/utils/app_locker/app_locker.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/widgets/app_lock.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:cloudchat/widgets/matrix.dart';
import '../bootstrap/bootstrap_dialog.dart';
import 'settings_security_view.dart';

class LockDialog extends StatefulWidget {
  final LockMethod lockMethod;

  const LockDialog({super.key, required this.lockMethod});

  @override
  State<LockDialog> createState() => _LockDialogState();
}

class _LockDialogState extends State<LockDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureText = true;
  String? _errorText;
  String? _confirmErrorText;

  void _validate() {
    final value = _controller.text;
    final confirmValue = _confirmController.text;

    setState(() {
      if (value.contains(' ')) {
        _controller.text = value.replaceAll(' ', '');
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      }
      if (confirmValue.contains(' ')) {
        _confirmController.text = confirmValue.replaceAll(' ', '');
        _confirmController.selection =
            TextSelection.collapsed(offset: _confirmController.text.length);
      }

      if (widget.lockMethod == LockMethod.pin) {
        _errorText = value.length == 4 && int.tryParse(value) != null
            ? null
            : L10n.of(context).pleaseEnter4Digits;
      } else {
        _errorText = value.length >= 6
            ? null
            : L10n.of(context).passwordMustBeAtLeast6Characters;
      }

      _confirmErrorText =
          value == confirmValue ? null : L10n.of(context).passwordsDoNotMatch;
    });
  }

  void _submit() {
    _validate();
    if (_errorText == null &&
        _confirmErrorText == null &&
        _controller.text.isNotEmpty) {
      Navigator.pop(context, _controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPin = widget.lockMethod == LockMethod.pin;

    return AlertDialog(
      title: Text(L10n.of(context).pleaseChooseAPasscode),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isPin
                  ? L10n.of(context).pleaseEnter4Digits
                  : L10n.of(context).pleaseEnterPassword,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _controller,
            label: isPin ? L10n.of(context).pin : L10n.of(context).password,
            errorText: _errorText,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _confirmController,
            label: isPin
                ? L10n.of(context).confirmPin
                : L10n.of(context).confirmPassword,
            errorText: _confirmErrorText,
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: Text(L10n.of(context).removePassword),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(L10n.of(context).cancel),
        ),
        TextButton(
          onPressed: (_errorText == null &&
                  _confirmErrorText == null &&
                  _controller.text == _confirmController.text &&
                  _controller.text.isNotEmpty)
              ? _submit
              : null,
          child: Text(L10n.of(context).ok),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      obscureText: _obscureText,
      maxLength: widget.lockMethod == LockMethod.pin ? 4 : 32,
      keyboardType: widget.lockMethod == LockMethod.pin
          ? TextInputType.number
          : TextInputType.text,
      inputFormatters: widget.lockMethod == LockMethod.pin
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      decoration: InputDecoration(
        labelText: label,
        errorText: errorText,
        suffixIcon: IconButton(
          icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        ),
      ),
      onChanged: (_) => _validate(),
      onSubmitted: (_) => _submit(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }
}

class SettingsSecurity extends StatefulWidget {
  const SettingsSecurity({super.key});

  @override
  SettingsSecurityController createState() => SettingsSecurityController();
}

class SettingsSecurityController extends State<SettingsSecurity> {
  void setAppLockTimeoutAction() async {
    if (AppLock.of(context).isActive) {
      AppLock.of(context).showLockScreen();
    }

    final defaultTimeout = AppLocker.getLockTimeout();

    final lockTime = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                L10n.of(context).pleaseChooseALockTimeout,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            RadioListTile<int>(
              title: Text(L10n.of(context).never),
              value: 0,
              groupValue: defaultTimeout,
              onChanged: (value) => Navigator.pop(context, value),
            ),
            ...([1, 5, 15, 30, 60, 120, 360].map(
              (minutes) => RadioListTile<int>(
                title: Text(
                  minutes < 60
                      ? L10n.of(context).minutes(minutes)
                      : L10n.of(context).hours(minutes ~/ 60),
                ),
                value: minutes,
                groupValue: defaultTimeout,
                onChanged: (value) => Navigator.pop(context, value),
              ),
            )),
          ],
        ),
      ),
    );

    if (lockTime != null) {
      await AppLocker.setLockTimeout(lockTime);
    }
  }

  void setAppLockAction() async {
    if (AppLock.of(context).isActive) {
      AppLock.of(context).showLockScreen();
    }
    final lockMethod = await showModalBottomSheet<LockMethod>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              L10n.of(context).pleaseChooseALockMethod,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ListTile(
            title: Text(L10n.of(context).pin),
            onTap: () => Navigator.pop(context, LockMethod.pin),
          ),
          ListTile(
            title: Text(L10n.of(context).password),
            onTap: () => Navigator.pop(context, LockMethod.password),
          ),
        ],
      ),
    );

    if (lockMethod == null) return;

    final newLock = await showDialog<String?>(
      context: context,
      builder: (_) => LockDialog(lockMethod: lockMethod),
    );

    if (newLock != null) {
      await AppLocker.setLockMethod(lockMethod, newLock);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLock.isNotEmpty
                ? (lockMethod == LockMethod.pin
                    ? L10n.of(context).pinSetSuccessfully
                    : L10n.of(context).passwordSetSuccessfully)
                : L10n.of(context).removePasswordSuccessfully,
          ),
          action: SnackBarAction(
            label: L10n.of(context).close,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  void deleteAccountAction() async {
    if (await showOkCancelAlertDialog(
          useRootNavigator: false,
          context: context,
          title: L10n.of(context).warning,
          message: L10n.of(context).deactivateAccountWarning,
          okLabel: L10n.of(context).ok,
          cancelLabel: L10n.of(context).cancel,
          isDestructiveAction: true,
        ) ==
        OkCancelResult.cancel) {
      return;
    }
    final supposedMxid = Matrix.of(context).client.userID!;
    final mxids = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).confirmMatrixId,
      textFields: [
        DialogTextField(
          validator: (text) => text == supposedMxid
              ? null
              : L10n.of(context).supposedMxid(supposedMxid),
        ),
      ],
      isDestructiveAction: true,
      okLabel: L10n.of(context).delete,
      cancelLabel: L10n.of(context).cancel,
    );
    if (mxids == null || mxids.length != 1 || mxids.single != supposedMxid) {
      return;
    }
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).pleaseEnterYourPassword,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      isDestructiveAction: true,
      textFields: [
        const DialogTextField(
          obscureText: true,
          hintText: '******',
          minLines: 1,
          maxLines: 1,
        ),
      ],
    );
    if (input == null) return;
    await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).client.deactivateAccount(
            auth: AuthenticationPassword(
              password: input.single,
              identifier: AuthenticationUserIdentifier(
                user: Matrix.of(context).client.userID!,
              ),
            ),
          ),
    );
  }

  void showBootstrapDialog(BuildContext context) async {
    await BootstrapDialog(
      client: Matrix.of(context).client,
    ).show(context);
  }

  Future<void> dehydrateAction() => Matrix.of(context).dehydrateAction(context);

  @override
  Widget build(BuildContext context) => SettingsSecurityView(this);
}
