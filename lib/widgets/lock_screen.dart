import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';

import 'package:cloudchat/config/themes.dart';
import 'package:cloudchat/utils/app_locker/app_locker.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _errorText;
  int _coolDownSeconds = 5;
  bool _inputBlocked = false;
  final TextEditingController _textEditingController = TextEditingController();
  LockMethod? _lockMethod;

  void tryUnlock(String text) async {
    setState(() {
      _errorText = null;
    });

    final lockMethod = AppLocker.getLockMethod();

    if (lockMethod == LockMethod.pin) {
      if (text.length < 4) {
        setState(() {
          _errorText = L10n.of(context).invalidInput;
        });
        return;
      }

      if (text.length != 4) {
        setState(() {
          _errorText = L10n.of(context).invalidInput;
        });
        _textEditingController.clear();
        return;
      }
    } else if (lockMethod == LockMethod.password) {
      if (text.length < 6) {
        setState(() {
          _errorText = L10n.of(context).invalidInput;
        });
        return;
      }
    }

    if (await AppLocker.unlockApp(text)) {
      setState(() {
        _inputBlocked = false;
        _errorText = null;
      });
      _textEditingController.clear();
      return;
    }

    setState(() {
      _errorText = lockMethod == LockMethod.pin
          ? L10n.of(context).wrongPinEntered(_coolDownSeconds)
          : L10n.of(context).wrongPasswordEntered(_coolDownSeconds);
      _inputBlocked = true;
    });
    Future.delayed(Duration(seconds: _coolDownSeconds)).then((_) {
      setState(() {
        _inputBlocked = false;
        _coolDownSeconds *= 2;
        _errorText = null;
      });
    });
    _textEditingController.clear();
  }

  @override
  void initState() {
    super.initState();
    setState(() {
      _lockMethod = AppLocker.getLockMethod();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lockMethod == LockMethod.pin
            ? L10n.of(context).pleaseEnterYourPin
            : L10n.of(context).pleaseEnterYourPassword,),
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => Material(
              type: MaterialType.transparency,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: CloudThemes.columnWidth,
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/info-logo.png',
                            width: 256,
                          ),
                        ),
                        TextField(
                          controller: _textEditingController,
                          textInputAction: TextInputAction.done,
                          keyboardType: _lockMethod == LockMethod.pin
                              ? TextInputType.number
                              : TextInputType.text,
                          obscureText: true,
                          autofocus: true,
                          textAlign: TextAlign.center,
                          readOnly: _inputBlocked,
                          onChanged: (text) {
                            setState(() {});
                          },
                          onSubmitted: tryUnlock,
                          style: const TextStyle(fontSize: 40),
                          inputFormatters: [
                            if (_lockMethod == LockMethod.pin) ...[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ] else
                              LengthLimitingTextInputFormatter(32),
                          ],
                          decoration: InputDecoration(
                            errorText: _errorText,
                            hintText: _lockMethod == LockMethod.pin
                                ? '****'
                                : '******',
                            suffix: IconButton(
                              icon: const Icon(Icons.lock_open_outlined),
                              onPressed: () =>
                                  tryUnlock(_textEditingController.text),
                            ),
                          ),
                        ),
                        if (_inputBlocked)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _inputBlocked
                              ? null
                              : () => tryUnlock(_textEditingController.text),
                          icon: const Icon(Icons.lock_open),
                          label: const Text(
                            "",
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24,),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
