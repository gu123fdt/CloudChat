import 'package:flutter/material.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:cloudchat/widgets/layouts/login_scaffold.dart';
import 'package:cloudchat/widgets/matrix.dart';
import 'login.dart';

class LoginView extends StatelessWidget {
  final LoginController controller;

  const LoginView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final homeserver = Matrix.of(context)
        .getLoginClient()
        .homeserver
        .toString()
        .replaceFirst('https://', '');
    final title = controller.isRegistration
        ? L10n.of(context).registerTo(homeserver)
        : L10n.of(context).logInTo(homeserver);
    final titleParts = title.split(homeserver);

    return LoginScaffold(
      enforceMobileMode: Matrix.of(context).client.isLogged(),
      appBar: AppBar(
        leading: controller.loading
            ? null
            : Center(
                child: BackButton(
                onPressed:
                    controller.isRegistration ? controller.goToLogin : null,
              ),),
        automaticallyImplyLeading: !controller.loading,
        titleSpacing: !controller.loading ? 0 : null,
        title: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: titleParts.first),
              TextSpan(
                text: homeserver,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: titleParts.last),
            ],
          ),
          style: const TextStyle(fontSize: 18),
        ),
      ),
      body: Builder(
        builder: (context) {
          if (!controller.isRegistration && !controller.isEmailConfirmation) {
            return AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  Hero(
                    tag: 'info-logo',
                    child: Image.asset('assets/banner.png'),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofocus: true,
                      onChanged: controller.checkWellKnownWithCoolDown,
                      controller: controller.usernameController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.username],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.account_box_outlined),
                        errorText: controller.usernameError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        hintText: '@username:domain',
                        labelText: L10n.of(context).emailOrUsername,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.password],
                      controller: controller.passwordController,
                      textInputAction: TextInputAction.go,
                      obscureText: !controller.showPassword,
                      onSubmitted: (_) => controller.login(),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outlined),
                        errorText: controller.passwordError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        suffixIcon: IconButton(
                          onPressed: controller.toggleShowPassword,
                          icon: Icon(
                            controller.showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black,
                          ),
                        ),
                        hintText: '******',
                        labelText: L10n.of(context).password,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed: controller.loading ? null : controller.login,
                      child: controller.loading
                          ? const LinearProgressIndicator()
                          : Text(L10n.of(context).login),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextButton(
                      onPressed: controller.loading
                          ? () {}
                          : controller.passwordForgotten,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      child: Text(L10n.of(context).passwordForgotten),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<bool>(
                    future: Matrix.of(context)
                        .checkHomeserverIsSupportedRegistration(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError ||
                          snapshot.connectionState == ConnectionState.waiting ||
                          !snapshot.data!) {
                        return const SizedBox.shrink();
                      } else {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: TextButton(
                            onPressed: controller.loading
                                ? () {}
                                : controller.goToRegister,
                            style: TextButton.styleFrom(
                              foregroundColor: theme.colorScheme.secondary,
                            ),
                            child: Text(L10n.of(context).register),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          } else if (controller.isRegistration &&
              !controller.isEmailConfirmation) {
            return AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: <Widget>[
                  Hero(
                    tag: 'info-logo',
                    child: Image.asset('assets/banner.png'),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofocus: true,
                      controller: controller.usernameController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.text,
                      onChanged: controller.checkUsernameAvailability,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.username],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.account_box_outlined),
                        errorText: controller.usernameError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        hintText: 'username',
                        labelText: L10n.of(context).username,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.password],
                      controller: controller.passwordController,
                      textInputAction: TextInputAction.go,
                      obscureText: !controller.showPassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outlined),
                        errorText: controller.passwordError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        suffixIcon: IconButton(
                          onPressed: controller.toggleShowPassword,
                          icon: Icon(
                            controller.showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black,
                          ),
                        ),
                        hintText: '******',
                        labelText: L10n.of(context).password,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextField(
                      readOnly: controller.loading,
                      autocorrect: false,
                      autofocus: true,
                      controller: controller.emailController,
                      textInputAction: TextInputAction.next,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: controller.checkEmailCorrect,
                      autofillHints:
                          controller.loading ? null : [AutofillHints.email],
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.mail_outlined),
                        errorText: controller.emailError,
                        errorStyle: const TextStyle(color: Colors.orange),
                        hintText: 'email',
                        labelText: L10n.of(context).email,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                      onPressed:
                          controller.loading ? null : controller.register,
                      child: controller.loading
                          ? const LinearProgressIndicator()
                          : Text(L10n.of(context).register),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: TextButton(
                      onPressed:
                          controller.loading ? () {} : controller.goToLogin,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                      ),
                      child: Text(L10n.of(context).login),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return AutofillGroup(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  Hero(
                    tag: 'info-logo',
                    child: Image.asset('assets/banner_transparent.png'),
                  ),
                  const SizedBox(height: 16),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: SelectableLinkify(
                      text: L10n.of(context).emailConfirmations,
                      style: TextStyle(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
