import 'dart:async';

import 'package:flutter/material.dart';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:matrix/matrix.dart';

import 'package:cloudchat/utils/localized_exception_extension.dart';
import 'package:cloudchat/widgets/future_loading_dialog.dart';
import 'package:cloudchat/widgets/matrix.dart';
import '../../utils/platform_infos.dart';
import 'login_view.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  LoginController createState() => LoginController();
}

class LoginController extends State<Login> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String? usernameError;
  String? passwordError;
  String? emailError;
  bool loading = false;
  bool showPassword = false;
  bool isRegistration = false;
  bool isEmailConfirmation = false;

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);

  void register() async {
    setState(() => loading = true);

    final matrix = Matrix.of(context);

    if (usernameController.text.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
    } else if (await checkUsernameAvailability(usernameController.text)) {
      setState(() => usernameError = null);
    }

    if (passwordController.text.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
    } else {
      setState(() => passwordError = null);
    }

    if (emailController.text.isEmpty) {
      setState(() => emailError = L10n.of(context).pleaseEnterYourEmail);
    } else if (checkEmailCorrect(emailController.text)) {
      setState(() => emailError = null);
    }

    if (usernameController.text.isEmpty ||
        passwordController.text.isEmpty ||
        emailController.text.isEmpty ||
        !checkEmailCorrect(emailController.text) ||
        !await checkUsernameAvailability(usernameController.text)) {
      setState(() => loading = false);
      return;
    }

    String? session;

    try {
      await matrix.getLoginClient().register(
            password: passwordController.text,
            username: usernameController.text,
          );
    } on MatrixException catch (e) {
      session = e.session;
    }

    final clientSecret = DateTime.now().millisecondsSinceEpoch.toString();
    RequestTokenResponse emailResponse;

    try {
      emailResponse = await matrix
          .getLoginClient()
          .requestTokenToRegisterEmail(clientSecret, emailController.text, 1);
    } on MatrixException catch (_) {
      setState(() => loading = false);
      setState(() => emailError = L10n.of(context).emailAlreadyExists);
      return;
    }

    setState(() => isEmailConfirmation = true);

    while (true) {
      try {
        await matrix.getLoginClient().register(
              auth: AuthenticationThreePidCreds(
                session: session,
                type: "m.login.email.identity",
                threepidCreds: ThreepidCreds(
                  sid: emailResponse.sid,
                  clientSecret: clientSecret,
                ),
              ),
              password: passwordController.text,
              username: usernameController.text,
            );
      } on MatrixException catch (e) {
        if (e.errcode != "M_UNAUTHORIZED") {
          setState(() => loading = false);
          setState(() => isEmailConfirmation = false);
          return;
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  bool checkEmailCorrect(String email) {
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (regex.hasMatch(email)) {
      setState(() => emailError = null);
      return true;
    } else {
      setState(() => emailError = L10n.of(context).emailIsNotCorrect);
      return false;
    }
  }

  void login() async {
    final matrix = Matrix.of(context);
    if (usernameController.text.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
    } else {
      setState(() => usernameError = null);
    }
    if (passwordController.text.isEmpty) {
      setState(() => passwordError = L10n.of(context).pleaseEnterYourPassword);
    } else {
      setState(() => passwordError = null);
    }

    if (usernameController.text.isEmpty || passwordController.text.isEmpty) {
      return;
    }

    setState(() => loading = true);

    _coolDown?.cancel();

    final oldHomeserver = matrix.getLoginClient().homeserver;

    try {
      final username = usernameController.text.trim();
      AuthenticationIdentifier identifier;
      if (username.isEmail) {
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'email',
          address: username,
        );
      } else if (username.isPhoneNumber) {
        identifier = AuthenticationThirdPartyIdentifier(
          medium: 'msisdn',
          address: username,
        );
      } else {
        identifier = AuthenticationUserIdentifier(user: username);
      }

      try {
        await matrix.getLoginClient().login(LoginType.mLoginPassword);
      } catch (_) {}
      matrix.getLoginClient().homeserver = oldHomeserver;
      await matrix.getLoginClient().login(
            LoginType.mLoginPassword,
            identifier: identifier,
            // To stay compatible with older server versions
            // ignore: deprecated_member_use
            user: identifier.type == AuthenticationIdentifierTypes.userId
                ? username
                : null,
            password: passwordController.text,
            initialDeviceDisplayName: PlatformInfos.clientName,
          );
    } on MatrixException catch (exception) {
      matrix.getLoginClient().homeserver = oldHomeserver;
      setState(() => passwordError = exception.errorMessage);
      return setState(() => loading = false);
    } catch (exception) {
      matrix.getLoginClient().homeserver = oldHomeserver;
      setState(() => passwordError = exception.toString());
      return setState(() => loading = false);
    }

    if (mounted) setState(() => loading = false);
  }

  Timer? _coolDown;

  Future<bool> checkUsernameAvailability(String username) async {
    try {
      await Matrix.of(context)
          .getLoginClient()
          .checkUsernameAvailability(username);
      setState(() => usernameError = null);
      return true;
    } on MatrixException catch (exception) {
      if (exception.errcode == "M_USER_IN_USE") {
        setState(() => usernameError = L10n.of(context).usernameAlreadyExists);
      } else {
        setState(() => usernameError = L10n.of(context).usernameIsUnsuitable);
      }

      return false;
    }
  }

  void checkWellKnownWithCoolDown(String userId) async {
    _coolDown?.cancel();
    _coolDown = Timer(
      const Duration(seconds: 1),
      () => _checkWellKnown(userId),
    );
  }

  void goToRegister() {
    setState(() {
      isRegistration = true;
    });
  }

  void goToLogin() {
    setState(() {
      isRegistration = false;
    });
  }

  void _checkWellKnown(String userId) async {
    if (mounted) setState(() => usernameError = null);
    if (!userId.isValidMatrixId) return;
    final oldHomeserver = Matrix.of(context).getLoginClient().homeserver;
    try {
      var newDomain = Uri.https(userId.domain!, '');
      Matrix.of(context).getLoginClient().homeserver = newDomain;
      DiscoveryInformation? wellKnownInformation;
      try {
        wellKnownInformation =
            await Matrix.of(context).getLoginClient().getWellknown();
        if (wellKnownInformation.mHomeserver.baseUrl.toString().isNotEmpty) {
          newDomain = wellKnownInformation.mHomeserver.baseUrl;
        }
      } catch (_) {
        // do nothing, newDomain is already set to a reasonable fallback
      }
      if (newDomain != oldHomeserver) {
        await Matrix.of(context).getLoginClient().checkHomeserver(newDomain);

        if (Matrix.of(context).getLoginClient().homeserver == null) {
          Matrix.of(context).getLoginClient().homeserver = oldHomeserver;
          // okay, the server we checked does not appear to be a matrix server
          Logs().v(
            '$newDomain is not running a homeserver, asking to use $oldHomeserver',
          );
          final dialogResult = await showOkCancelAlertDialog(
            context: context,
            useRootNavigator: false,
            message: L10n.of(context).noMatrixServer(newDomain, oldHomeserver!),
            okLabel: L10n.of(context).ok,
            cancelLabel: L10n.of(context).cancel,
          );
          if (dialogResult == OkCancelResult.ok) {
            if (mounted) setState(() => usernameError = null);
          } else {
            Navigator.of(context, rootNavigator: false).pop();
            return;
          }
        }
        usernameError = null;
        if (mounted) setState(() {});
      } else {
        Matrix.of(context).getLoginClient().homeserver = oldHomeserver;
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      Matrix.of(context).getLoginClient().homeserver = oldHomeserver;
      usernameError = e.toLocalizedString(context);
      if (mounted) setState(() {});
    }
  }

  void passwordForgotten() async {
    final input = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).passwordForgotten,
      message: L10n.of(context).enterAnEmailAddress,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      fullyCapitalizedForMaterial: false,
      textFields: [
        DialogTextField(
          initialText:
              usernameController.text.isEmail ? usernameController.text : '',
          hintText: L10n.of(context).enterAnEmailAddress,
          keyboardType: TextInputType.emailAddress,
        ),
      ],
    );
    if (input == null) return;
    final clientSecret = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await showFutureLoadingDialog(
      context: context,
      future: () =>
          Matrix.of(context).getLoginClient().requestTokenToResetPasswordEmail(
                clientSecret,
                input.single,
                sendAttempt++,
              ),
    );
    if (response.error != null) return;
    final password = await showTextInputDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).passwordForgotten,
      message: L10n.of(context).chooseAStrongPassword,
      okLabel: L10n.of(context).ok,
      cancelLabel: L10n.of(context).cancel,
      fullyCapitalizedForMaterial: false,
      textFields: [
        const DialogTextField(
          hintText: '******',
          obscureText: true,
          minLines: 1,
          maxLines: 1,
        ),
      ],
    );
    if (password == null) return;
    final ok = await showOkAlertDialog(
      useRootNavigator: false,
      context: context,
      title: L10n.of(context).weSentYouAnEmail,
      message: L10n.of(context).pleaseClickOnLink,
      okLabel: L10n.of(context).iHaveClickedOnLink,
      fullyCapitalizedForMaterial: false,
    );
    if (ok != OkCancelResult.ok) return;
    final data = <String, dynamic>{
      'new_password': password.single,
      'logout_devices': false,
      "auth": AuthenticationThreePidCreds(
        type: AuthenticationTypes.emailIdentity,
        threepidCreds: ThreepidCreds(
          sid: response.result!.sid,
          clientSecret: clientSecret,
        ),
      ).toJson(),
    };
    final success = await showFutureLoadingDialog(
      context: context,
      future: () => Matrix.of(context).getLoginClient().request(
            RequestType.POST,
            '/client/v3/account/password',
            data: data,
          ),
    );
    if (success.error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.of(context).passwordHasBeenChanged)),
      );
      usernameController.text = input.single;
      passwordController.text = password.single;
      login();
    }
  }

  static int sendAttempt = 0;

  @override
  Widget build(BuildContext context) => LoginView(this);
}

extension on String {
  static final RegExp _phoneRegex =
      RegExp(r'^[+]*[(]{0,1}[0-9]{1,4}[)]{0,1}[-\s\./0-9]*$');
  static final RegExp _emailRegex = RegExp(r'(.+)@(.+)\.(.+)');

  bool get isEmail => _emailRegex.hasMatch(this);

  bool get isPhoneNumber => _phoneRegex.hasMatch(this);
}
