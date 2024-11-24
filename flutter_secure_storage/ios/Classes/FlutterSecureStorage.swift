//
//  FlutterSecureStorageManager.swift
//  flutter_secure_storage
//
//  Created by Julian Steenbakker on 22/08/2022.
//

import Foundation
import LocalAuthentication

class FlutterSecureStorage {
    private func parseAccessibleAttr(accessibility: String?) -> CFString {
        guard let accessibility = accessibility else {
            return kSecAttrAccessibleWhenUnlocked
        }

        switch accessibility {
        case "passcode":
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        case "unlocked":
            return kSecAttrAccessibleWhenUnlocked
        case "unlocked_this_device":
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case "first_unlock":
            return kSecAttrAccessibleAfterFirstUnlock
        case "first_unlock_this_device":
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        default:
            return kSecAttrAccessibleWhenUnlocked
        }
    }

    private func baseQuery(key: String?, groupId: String?, accountName: String?, synchronizable: Bool?, accessibility: String?, returnData: Bool?, laContext:LAContext?=nil) -> Dictionary<CFString, Any> {
        var keychainQuery: [CFString: Any] = [
            kSecClass : kSecClassGenericPassword
        ]

        if (accessibility != nil) {
            keychainQuery[kSecAttrAccessible] = parseAccessibleAttr(accessibility: accessibility)
        }

        if (key != nil) {
            keychainQuery[kSecAttrAccount] = key
        }

        if (groupId != nil) {
            keychainQuery[kSecAttrAccessGroup] = groupId
        }

        if (accountName != nil) {
            keychainQuery[kSecAttrService] = accountName
        }

        if (synchronizable != nil) {
            keychainQuery[kSecAttrSynchronizable] = synchronizable
        }

        if (returnData != nil) {
            keychainQuery[kSecReturnData] = returnData
        }
        if (laContext != nil) {
            keychainQuery[kSecUseAuthenticationContext] = laContext
        }
     
        return keychainQuery
    }

    internal func containsKey(key: String, groupId: String?, accountName: String?) -> Result<Bool, OSSecError> {
        // The accessibility parameter has no influence on uniqueness.
        func queryKeychain(synchronizable: Bool) -> OSStatus {
           let keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, accessibility: nil, returnData: false)
           return SecItemCopyMatching(keychainQuery as CFDictionary, nil)
       }

       let statusSynchronizable = queryKeychain(synchronizable: true)
       if statusSynchronizable == errSecSuccess {
           return .success(true)
       } else if statusSynchronizable != errSecItemNotFound {
           return .failure(OSSecError(status: statusSynchronizable))
       }

       let statusNonSynchronizable = queryKeychain(synchronizable: false)
       switch statusNonSynchronizable {
       case errSecSuccess:
           return .success(true)
       case errSecItemNotFound:
           return .success(false)
       default:
           return .failure(OSSecError(status: statusNonSynchronizable))
       }
    }

    internal func readAll(groupId: String?, accountName: String?, synchronizable: Bool?, accessibility: String?) -> FlutterSecureStorageResponse {
        var keychainQuery = baseQuery(key: nil, groupId: groupId, accountName: accountName, synchronizable: synchronizable, accessibility: accessibility, returnData: true)

        keychainQuery[kSecMatchLimit] = kSecMatchLimitAll
        keychainQuery[kSecReturnAttributes] = true

        var ref: AnyObject?
        let status = SecItemCopyMatching(
            keychainQuery as CFDictionary,
            &ref
        )

        if (status == errSecItemNotFound) {
            // readAll() returns all elements, so return nil if the items does not exist
            return FlutterSecureStorageResponse(status: errSecSuccess, value: nil)
        }

        var results: [String: String] = [:]

        if (status == noErr) {
            (ref as! NSArray).forEach { item in
                let key: String = (item as! NSDictionary)[kSecAttrAccount] as! String
                let value: String = String(data: (item as! NSDictionary)[kSecValueData] as! Data, encoding: .utf8) ?? ""
                results[key] = value
            }
        }

        return FlutterSecureStorageResponse(status: status, value: results)
    }

    internal func read(key: String, groupId: String?, accountName: String?, laContext: LAContext?=nil) -> FlutterSecureStorageResponse {
        // Function to retrieve a value considering the synchronizable parameter.
        func readValue(synchronizable: Bool?) -> FlutterSecureStorageResponse {
            let keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, accessibility: nil, returnData: true,laContext: laContext)

            var ref: AnyObject?
            let status = SecItemCopyMatching(
                keychainQuery as CFDictionary,
                &ref
            )

            // Return nil if the key is not found.
            if status == errSecItemNotFound {
                return FlutterSecureStorageResponse(status: errSecSuccess, value: nil)
            }

            var value: String? = nil
            
            

            if status == noErr, let data = ref as? Data {
                value = unarchivingData(data: data)
            }

            return FlutterSecureStorageResponse(status: status, value: value)
        }

        // First, query without synchronizable, then with synchronizable if no value is found.
        let responseWithoutSynchronizable = readValue(synchronizable: nil)
        return responseWithoutSynchronizable.value != nil ? responseWithoutSynchronizable : readValue(synchronizable: true)
    }

    internal func deleteAll(groupId: String?, accountName: String?) -> FlutterSecureStorageResponse {
        let keychainQuery = baseQuery(key: nil, groupId: groupId, accountName: accountName, synchronizable: nil, accessibility: nil, returnData: nil)
        let status = SecItemDelete(keychainQuery as CFDictionary)

        if (status == errSecItemNotFound) {
            // deleteAll() deletes all items, so return nil if the items does not exist
            return FlutterSecureStorageResponse(status: errSecSuccess, value: nil)
        }

        return FlutterSecureStorageResponse(status: status, value: nil)
    }

    internal func delete(key: String, groupId: String?, accountName: String?) -> FlutterSecureStorageResponse {
        let keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: nil, accessibility: nil, returnData: true)
        let status = SecItemDelete(keychainQuery as CFDictionary)

        // Return nil if the key is not found
        if (status == errSecItemNotFound) {
            return FlutterSecureStorageResponse(status: errSecSuccess, value: nil)
        }

        return FlutterSecureStorageResponse(status: status, value: nil)
    }

    internal func write(key: String, value: String, groupId: String?, accountName: String?, synchronizable: Bool?, accessibility: String?) -> FlutterSecureStorageResponse {
        var keyExists: Bool = false

        // Check if the key exists but without accessibility.
        // This parameter has no effect on the uniqueness of the key.
    	switch containsKey(key: key, groupId: groupId, accountName: accountName) {
            case .success(let exists):
                keyExists = exists
                break;
            case .failure(let err):
                return FlutterSecureStorageResponse(status: err.status, value: nil)
        }
        let archivedValue = archivingData(data: value)
        var keychainQuery = baseQuery(key: key, groupId: groupId, accountName: accountName, synchronizable: synchronizable, accessibility: accessibility, returnData: nil)

        if (keyExists) {
            // Entry exists, try to update it. Change of kSecAttrAccessible not possible via update.
            let update: [CFString: Any?] = [
                kSecValueData: archivedValue,
                kSecAttrSynchronizable: synchronizable
            ]

            let status = SecItemUpdate(keychainQuery as CFDictionary, update as CFDictionary)

            if status == errSecSuccess {
                return FlutterSecureStorageResponse(status: status, value: nil)
            }

            // Update failed, possibly due to different kSecAttrAccessible.
            // Delete the entry and create a new one in the next step.
            delete(key: key, groupId: groupId, accountName: accountName)
        }

        // Entry does not exist or was deleted, create a new entry.
        keychainQuery[kSecValueData] = archivedValue

        let status = SecItemAdd(keychainQuery as CFDictionary, nil)

        return FlutterSecureStorageResponse(status: status, value: nil)
    }
    internal func writeWithLocalAuth(key: String, value: String, laContext: LAContext? = nil, groupId: String?, accountName: String?, synchronizable: Bool?) -> FlutterSecureStorageResponse {
        // First, attempt to delete any existing item
        let deleteResponse = delete(key: key, groupId: groupId, accountName: accountName)

        if deleteResponse.status != errSecSuccess && deleteResponse.status != errSecItemNotFound {
            return deleteResponse // Return if deletion fails
        }
        
        // Archive the value
        guard let data = archivingData(data: value) else {
            return FlutterSecureStorageResponse(status: errSecParam, value: nil)
        }

        // Create access control object for authentication
        let accessControl = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, [.userPresence], nil)

        // Build the query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: accountName ?? "defaultService",
            kSecAttrAccessControl as String: accessControl as Any,
            kSecUseAuthenticationContext as String: laContext as Any,
            kSecAttrSynchronizable as String: synchronizable ?? false,
            kSecValueData as String: data
        ]

        // Attempt to add the item to the keychain
        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecSuccess {
            print("Item saved successfully")
        } else {
            print("Error saving item: \(status)")
        }
        
        return FlutterSecureStorageResponse(status: status, value: nil)
    }

    internal func readWithLocalAuth(key: String, laContext: LAContext? = nil, accountName: String?) -> FlutterSecureStorageResponse {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: accountName ?? "defaultService",
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationContext as String: laContext as Any,
            kSecReturnData as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return FlutterSecureStorageResponse(status: errSecSuccess, value: nil)
        }

        if status != errSecSuccess {
            return FlutterSecureStorageResponse(status: status, value: nil) // Return on other errors
        }

        guard let data = item as? Data, let value = unarchivingData(data: data) else {
            return FlutterSecureStorageResponse(status: errSecParam, value: nil)
        }

        return FlutterSecureStorageResponse(status: status, value: value)
    }
        /// archiver that makes data hiden in keychain
        private func archivingData(data : Any) -> NSData? {
            do{
                return try NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true) as NSData
            }catch{
                return NSData(data: Data())
            }
        }

        /// unarchiver that retrive hiden data in keychaink
        private func unarchivingData(data : Any?) -> String? {
            if let unarchivedObject = data{
                do{
                    return try NSKeyedUnarchiver.unarchivedObject(ofClass: NSString.self, from: unarchivedObject as! Data) as String?
                }catch{
                    return String()
                }
            }
            return nil
        }
}

struct FlutterSecureStorageResponse {
    var status: OSStatus?
    var value: Any?
}

struct OSSecError: Error {
    var status: OSStatus
}
