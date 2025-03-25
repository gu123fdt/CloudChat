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
                title: Text(minutes < 60
                    ? L10n.of(context).minutes(minutes)
                    : L10n.of(context).hours(minutes ~/ 60)),
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

    String? newLock;
    await showDialog(
      useRootNavigator: false,
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        final confirmController = TextEditingController();
        String? errorText;
        String? confirmErrorText;
        bool obscureText = true;

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(L10n.of(context).pleaseChooseAPasscode),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      lockMethod == LockMethod.pin
                          ? L10n.of(context).pleaseEnter4Digits
                          : L10n.of(context).pleaseEnterPassword,
                    ),
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: lockMethod == LockMethod.pin
                      ? TextInputType.number
                      : TextInputType.text,
                  obscureText: obscureText,
                  maxLines: 1,
                  maxLength: lockMethod == LockMethod.pin ? 4 : 32,
                  onSubmitted: (text) {
                    if (confirmErrorText == null &&
                        errorText == null &&
                        controller.text.isNotEmpty &&
                        controller.text == confirmController.text) {
                      newLock = controller.text;
                      Navigator.pop(context);
                    }
                  },
                  onChanged: (text) {
                    setState(() {
                      if (text.contains(' ')) {
                        text = text.replaceAll(' ', '');
                        controller.text = text;
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: text.length),
                        );
                      }
                      if (lockMethod == LockMethod.pin) {
                        if (text.isEmpty ||
                            (text.length == 4 && int.tryParse(text) != null)) {
                          errorText = null;
                        } else {
                          errorText = L10n.of(context).pleaseEnter4Digits;
                        }
                      } else {
                        if (text.length >= 6 || text.isEmpty) {
                          errorText = null;
                        } else {
                          errorText =
                              L10n.of(context).passwordMustBeAtLeast6Characters;
                        }
                      }
                      if (confirmController.text.isNotEmpty &&
                          confirmController.text != text) {
                        confirmErrorText = L10n.of(context).passwordsDoNotMatch;
                      } else {
                        confirmErrorText = null;
                      }
                    });
                  },
                  inputFormatters: lockMethod == LockMethod.pin
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: InputDecoration(
                    errorText: errorText,
                    labelText: lockMethod == LockMethod.pin
                        ? L10n.of(context).pin
                        : L10n.of(context).password,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureText = !obscureText;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: confirmController,
                  keyboardType: lockMethod == LockMethod.pin
                      ? TextInputType.number
                      : TextInputType.text,
                  obscureText: obscureText,
                  maxLines: 1,
                  maxLength: lockMethod == LockMethod.pin ? 4 : 32,
                  onSubmitted: (text) {
                    if (confirmErrorText == null &&
                        errorText == null &&
                        controller.text.isNotEmpty &&
                        controller.text == confirmController.text) {
                      newLock = controller.text;
                      Navigator.pop(context);
                    }
                  },
                  onChanged: (text) {
                    setState(() {
                      if (text.contains(' ')) {
                        text = text.replaceAll(' ', '');
                        confirmController.text = text;
                        confirmController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: text.length),
                        );
                      }
                      if (text != controller.text) {
                        confirmErrorText = L10n.of(context).passwordsDoNotMatch;
                      } else {
                        confirmErrorText = null;
                      }
                    });
                  },
                  inputFormatters: lockMethod == LockMethod.pin
                      ? [FilteringTextInputFormatter.digitsOnly]
                      : [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: InputDecoration(
                    errorText: confirmErrorText,
                    labelText: lockMethod == LockMethod.pin
                        ? L10n.of(context).confirmPin
                        : L10n.of(context).confirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          obscureText = !obscureText;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      newLock = '';
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    child: Text(L10n.of(context).removePassword),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(L10n.of(context).cancel),
                      ),
                      TextButton(
                        onPressed: confirmErrorText == null &&
                                errorText == null &&
                                controller.text.isNotEmpty &&
                                controller.text == confirmController.text
                            ? () {
                                newLock = controller.text;
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(L10n.of(context).ok),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (newLock != null) {
      await AppLocker.setLockMethod(lockMethod, newLock!);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLock!.isNotEmpty
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
