// Titan/TitanUsers.swift
import Foundation

/// Titan's users (Disk > Users), for sharing the desk's user with the deck
/// (0.42, experimental): Titan keeps a programmer per user, and the WebAPI
/// (4430) is a user of its own, so switching it to the desk's user may put
/// the deck's selection and levels in the desk's programmer. The list's
/// shape isn't documented, so any JSON with an id and a name per user is
/// read. Pure, so it's tested.
enum TitanUsers {
    struct User: Equatable, Hashable, Identifiable {
        var id: Int
        var name: String
    }

    private static let nameKeys = ["legend", "name", "text", "title", "label", "displayname", "username"]

    /// The users in Titan's answer to `Users/GetUserListMenuItems`, in its order, once each.
    static func parse(_ data: Data) -> [User] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        var users: [User] = []
        func walk(_ node: Any) {
            if let list = node as? [Any] {
                list.forEach(walk)
            } else if let object = node as? [String: Any] {
                if let user = user(in: object), !users.contains(where: { $0.id == user.id }) { users.append(user) }
                object.values.forEach(walk)
            }
        }
        walk(json)
        return users
    }

    private static func user(in object: [String: Any]) -> User? {
        let lowered = Dictionary(object.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { first, _ in first })
        let idKeys = ["titanid", "userid", "id", "value", "handleid"]
        let id = idKeys.lazy.compactMap { key -> Int? in
            if let number = lowered[key] as? Int { return number }
            if let text = lowered[key] as? String { return Int(text) }
            return nil
        }.first
        let name = nameKeys.lazy.compactMap { (lowered[$0] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
        guard let id, id > 0, let name else { return nil }
        return User(id: id, name: name)
    }

    /// A Titan answer that's a plain value ("Operator", 1234), as text.
    static func value(_ data: Data) -> String? {
        if let text = try? JSONDecoder().decode(String.self, from: data) { return text }
        if let number = try? JSONDecoder().decode(Int.self, from: data) { return String(number) }
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r"))
        return text.isEmpty ? nil : text
    }
}
