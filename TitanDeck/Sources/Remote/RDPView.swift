// Remote/RDPView.swift
import SwiftUI
import UIKit

/// Full-screen remote desktop view - stub until M5.
///
/// TODO(M5): render RDPSession.framebuffer and map touch to mouse: tap = left
/// click, two-finger tap = right click, two-finger drag = scroll, pencil
/// hover = mouse move, three-finger long-press = open settings. See the
/// "FreeRDP on iOS" section of the build plan:
/// https://claude.ai/artifact/PXtiepzci194FMHiHaynGM
struct RDPView: UIViewRepresentable {
    @ObservedObject var session: RDPSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
