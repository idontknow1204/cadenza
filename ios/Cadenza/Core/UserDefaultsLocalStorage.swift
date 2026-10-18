import Foundation
import Auth

/// Keychain 접근이 불가한 서명 없는 시뮬레이터 빌드용 UserDefaults 스토리지.
/// 릴리즈 빌드에서는 사용하지 않음.
struct UserDefaultsLocalStorage: AuthLocalStorage {
    private let prefix = "supabase.auth."

    func store(key: String, value: Data) throws {
        UserDefaults.standard.set(value, forKey: prefix + key)
    }

    func retrieve(key: String) throws -> Data? {
        UserDefaults.standard.data(forKey: prefix + key)
    }

    func remove(key: String) throws {
        UserDefaults.standard.removeObject(forKey: prefix + key)
    }
}
