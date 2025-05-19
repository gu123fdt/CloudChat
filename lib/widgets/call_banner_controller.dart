import 'package:cloudchat/widgets/call_banner.dart';
import 'package:flutter/material.dart';

class CallBannerController extends ChangeNotifier {
  CallBanner? _banner;
  CallBanner? get banner => _banner;

  void showBanner(CallBanner banner) {
    _banner = banner;
    notifyListeners();
  }

  void hideBanner() {
    _banner = null;
    notifyListeners();
  }
}
