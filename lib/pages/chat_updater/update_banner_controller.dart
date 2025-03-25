import 'package:cloudchat/pages/chat_updater/update_banner.dart';
import 'package:flutter/material.dart';

class UpdateBannerController extends ChangeNotifier {
  UpdateBanner? _banner;
  UpdateBanner? get banner => _banner;

  void showBanner(UpdateBanner banner) {
    _banner = banner;
    notifyListeners();
  }

  void hideBanner() {
    _banner = null;
    notifyListeners();
  }
}
