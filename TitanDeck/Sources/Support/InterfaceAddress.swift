// Support/InterfaceAddress.swift
import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// An interface's IPv4 address and subnet mask, e.g. 192.168.0.23 / 255.255.255.0.
struct IPv4Interface: Equatable {
    let address: String
    let netmask: String
}

/// Reads this device's own addresses, and checks whether two addresses are on
/// the same network - the usual reason the iPad can't see the Titan PC.
enum InterfaceAddress {
    /// The IPv4 address of a named interface ("en0"), or nil if it has none.
    static func ipv4(interface name: String) -> IPv4Interface? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let entry = pointer.pointee
            guard String(cString: entry.ifa_name) == name,
                  let address = entry.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  let text = dottedQuad(address) else { continue }
            return IPv4Interface(address: text, netmask: entry.ifa_netmask.flatMap(dottedQuad) ?? "")
        }
        return nil
    }

    /// True if `other` is on the same subnet as `address`/`netmask`. Nil when
    /// any of them isn't an IPv4 address (a host name, say), so we can't tell.
    static func sameSubnet(address: String, netmask: String, as other: String) -> Bool? {
        guard let a = parse(address), let mask = parse(netmask), let b = parse(other) else { return nil }
        return a & mask == b & mask
    }

    /// "192.168.0.147" -> its 32-bit value, or nil if it isn't a dotted quad.
    static func parse(_ text: String) -> UInt32? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let byte = UInt8(part) else { return nil }
            value = value << 8 | UInt32(byte)
        }
        return value
    }

    private static func dottedQuad(_ address: UnsafeMutablePointer<sockaddr>) -> String? {
        // Netmasks don't always carry AF_INET in sa_family, so read the
        // address bytes directly rather than asking getnameinfo.
        var addr = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard inet_ntop(AF_INET, &addr, &buffer, socklen_t(buffer.count)) != nil else { return nil }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
