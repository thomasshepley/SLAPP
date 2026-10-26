// Remote/RDPFailure.swift
import Foundation

/// Turns FreeRDP's failure text ("The connection was cancelled.") into what
/// actually went wrong, using whether the PC answered on the remote desktop
/// port at all. Pure, so it's tested.
enum RDPFailure {
    static func describe(_ freerdpMessage: String, host: String, port: UInt16, answered: Bool,
                         blankPassword: Bool = false) -> String {
        let address = port == 3389 ? host : "\(host):\(port)"
        guard answered else {
            return "Nothing answered at \(address) on the remote desktop port (\(port)). "
                + "Check the PC's address in Settings > Remote desktop (with more than one network, use the show network's), "
                + "that the PC is on, and that Remote Desktop is allowed through its firewall: TitanDeck Host's checks "
                + "flag Remote Desktop being off or the network set to Public."
        }
        let detail = freerdpMessage.trimmingCharacters(in: CharacterSet(charactersIn: " ."))
        if blankPassword {
            // Windows' default "Limit local account use of blank passwords to console logon only".
            return "The PC answered at \(address), but Windows won't let an account with no password sign in remotely "
                + "(\(detail)). On the PC, TitanDeck Host (0.9) > Accounts with no password > Allow. "
                + "Or give the Windows account a password, type it in Settings > Remote desktop, "
                + "and turn on automatic sign-in so the PC still starts straight into Titan."
        }
        return "The PC answered at \(address), but the remote desktop didn't open (\(detail)). "
            + "Check the username and password in Settings > Remote desktop, and TitanDeck Host's Remote Desktop checks "
            + "(RDP Wrapper on Windows Home)."
    }
}
