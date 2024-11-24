part of '../flutter_secure_storage.dart';

/// Specific options for iOS platform.
class IOSOptions extends AppleOptions {
  const IOSOptions(
      {String? groupId,
      String? accountName = AppleOptions.defaultAccountName,
      KeychainAccessibility? accessibility = KeychainAccessibility.unlocked,
      bool synchronizable = false,
      bool isLaRead = false,
      String? laReason})
      : super(
          groupId: groupId,
          accountName: accountName,
          accessibility: accessibility,
          synchronizable: synchronizable,
          isLaRead: isLaRead,
          laReason: laReason,
        );

  static const IOSOptions defaultOptions = IOSOptions();

  IOSOptions copyWith({
    String? groupId,
    String? accountName,
    KeychainAccessibility? accessibility,
    bool? synchronizable,
    bool? isLaRead,
    String? laReason,
  }) =>
      IOSOptions(
        groupId: groupId ?? _groupId,
        accountName: accountName ?? _accountName,
        accessibility: accessibility ?? _accessibility,
        synchronizable: synchronizable ?? _synchronizable,
        isLaRead: isLaRead ?? _isLaRead,
        laReason: laReason ?? _laReason,
      );
}
