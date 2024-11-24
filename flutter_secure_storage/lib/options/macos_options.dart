part of '../flutter_secure_storage.dart';

/// Specific options for macOS platform.
class MacOsOptions extends AppleOptions {
  const MacOsOptions({
    String? groupId,
    String? accountName = AppleOptions.defaultAccountName,
    KeychainAccessibility? accessibility = KeychainAccessibility.unlocked,
    bool synchronizable = false,
    bool isLaRead = false,
    String? laReason,
    bool useDataProtectionKeyChain = true,
  })  : _useDataProtectionKeyChain = useDataProtectionKeyChain,
        super(
          groupId: groupId,
          accountName: accountName,
          accessibility: accessibility,
          synchronizable: synchronizable,
          isLaRead: isLaRead,
          laReason: laReason,
        );

  static const MacOsOptions defaultOptions = MacOsOptions();

  final bool _useDataProtectionKeyChain;

  MacOsOptions copyWith({
    String? groupId,
    String? accountName,
    KeychainAccessibility? accessibility,
    bool? synchronizable,
    bool? isLaRead,
    String? laReason,
    bool? useDataProtectionKeyChain,
  }) =>
      MacOsOptions(
        groupId: groupId ?? _groupId,
        accountName: accountName ?? _accountName,
        accessibility: accessibility ?? _accessibility,
        synchronizable: synchronizable ?? _synchronizable,
        isLaRead: isLaRead ?? _isLaRead,
        laReason: laReason ?? _laReason,
        useDataProtectionKeyChain:
            useDataProtectionKeyChain ?? _useDataProtectionKeyChain,
      );

  @override
  Map<String, String> toMap() => <String, String>{
        ...super.toMap(),
        'useDataProtectionKeyChain': '$_useDataProtectionKeyChain',
      };
}
