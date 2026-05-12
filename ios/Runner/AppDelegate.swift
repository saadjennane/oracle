import Flutter
import UIKit
import MediaPlayer
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var volumeButtonChannel: FlutterMethodChannel?
    private var audioSession: AVAudioSession?
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var isListening = false
    private var initialVolume: Float = 0.5
    private var volumeObserver: NSKeyValueObservation?
    private var isResettingVolume = false

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Setup volume button channel
        if let controller = window?.rootViewController as? FlutterViewController {
            volumeButtonChannel = FlutterMethodChannel(
                name: "com.oracle_poc/volume_buttons",
                binaryMessenger: controller.binaryMessenger
            )

            volumeButtonChannel?.setMethodCallHandler { [weak self] call, result in
                switch call.method {
                case "startListening":
                    self?.startListening(result: result)
                case "stopListening":
                    self?.stopListening(result: result)
                case "isAvailable":
                    result(true)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

            // Setup iCloud KV channel
            let icloudChannel = FlutterMethodChannel(
                name: "com.sj.oracle/icloud_kv",
                binaryMessenger: controller.binaryMessenger
            )
            icloudChannel.setMethodCallHandler { call, result in
                let store = NSUbiquitousKeyValueStore.default
                let args = call.arguments as? [String: Any]

                switch call.method {
                case "setString":
                    if let key = args?["key"] as? String, let value = args?["value"] as? String {
                        store.set(value, forKey: key)
                        store.synchronize()
                        result(true)
                    } else {
                        result(false)
                    }
                case "getString":
                    if let key = args?["key"] as? String {
                        result(store.string(forKey: key))
                    } else {
                        result(nil)
                    }
                case "remove":
                    if let key = args?["key"] as? String {
                        store.removeObject(forKey: key)
                        store.synchronize()
                        result(true)
                    } else {
                        result(false)
                    }
                case "synchronize":
                    result(store.synchronize())
                case "isAvailable":
                    // NSUbiquitousKeyValueStore is available if iCloud is signed in
                    result(FileManager.default.ubiquityIdentityToken != nil)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }

            // Observe external iCloud KV changes → notify Dart
            let kvChannel = icloudChannel
            NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default,
                queue: .main
            ) { _ in
                kvChannel.invokeMethod("onExternalChange", arguments: nil)
            }
            NSUbiquitousKeyValueStore.default.synchronize()

            // Setup iCloud Files channel (ubiquitous container for bank images)
            let icloudFilesChannel = FlutterMethodChannel(
                name: "com.sj.oracle/icloud_files",
                binaryMessenger: controller.binaryMessenger
            )
            icloudFilesChannel.setMethodCallHandler { call, result in
                let args = call.arguments as? [String: Any]

                func containerDocs() -> URL? {
                    guard let container = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
                        return nil
                    }
                    let docs = container.appendingPathComponent("Documents")
                    try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
                    return docs
                }

                switch call.method {
                case "isAvailable":
                    result(FileManager.default.ubiquityIdentityToken != nil && containerDocs() != nil)
                case "writeFile":
                    guard let relPath = args?["relPath"] as? String,
                          let srcPath = args?["srcPath"] as? String,
                          let docs = containerDocs() else {
                        result(false); return
                    }
                    let dst = docs.appendingPathComponent(relPath)
                    do {
                        try FileManager.default.createDirectory(
                            at: dst.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        if FileManager.default.fileExists(atPath: dst.path) {
                            try FileManager.default.removeItem(at: dst)
                        }
                        try FileManager.default.copyItem(at: URL(fileURLWithPath: srcPath), to: dst)
                        result(true)
                    } catch {
                        result(false)
                    }
                case "readFileTo":
                    guard let relPath = args?["relPath"] as? String,
                          let dstPath = args?["dstPath"] as? String,
                          let docs = containerDocs() else {
                        result(false); return
                    }
                    let src = docs.appendingPathComponent(relPath)
                    // Trigger download if file not locally materialized
                    try? FileManager.default.startDownloadingUbiquitousItem(at: src)
                    // Wait briefly for download (up to ~2s)
                    let deadline = Date().addingTimeInterval(2.0)
                    while !FileManager.default.fileExists(atPath: src.path) && Date() < deadline {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    guard FileManager.default.fileExists(atPath: src.path) else {
                        result(false); return
                    }
                    do {
                        let dst = URL(fileURLWithPath: dstPath)
                        try FileManager.default.createDirectory(
                            at: dst.deletingLastPathComponent(),
                            withIntermediateDirectories: true
                        )
                        if FileManager.default.fileExists(atPath: dst.path) {
                            try FileManager.default.removeItem(at: dst)
                        }
                        try FileManager.default.copyItem(at: src, to: dst)
                        result(true)
                    } catch {
                        result(false)
                    }
                case "fileExists":
                    guard let relPath = args?["relPath"] as? String,
                          let docs = containerDocs() else {
                        result(false); return
                    }
                    result(FileManager.default.fileExists(atPath: docs.appendingPathComponent(relPath).path))
                case "deleteFile":
                    guard let relPath = args?["relPath"] as? String,
                          let docs = containerDocs() else {
                        result(false); return
                    }
                    try? FileManager.default.removeItem(at: docs.appendingPathComponent(relPath))
                    result(true)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func startListening(result: @escaping FlutterResult) {
        guard !isListening else {
            result(true)
            return
        }

        do {
            audioSession = AVAudioSession.sharedInstance()
            try audioSession?.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession?.setActive(true)

            // Create hidden volume view to prevent system volume HUD
            // Use a proper-sized frame and alpha for hiding (off-screen tiny frames
            // don't create the UISlider subview on iOS 17+)
            let vv = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 100, height: 100))
            vv.showsRouteButton = false
            vv.alpha = 0.001
            volumeView = vv
            window?.addSubview(vv)

            // Find the volume slider (may be nested in subviews on newer iOS)
            volumeSlider = findSlider(in: vv)

            // Get initial volume
            initialVolume = audioSession?.outputVolume ?? 0.5

            // If slider found, set it to middle immediately
            if let slider = volumeSlider {
                slider.setValue(0.5, animated: false)
                slider.sendActions(for: .valueChanged)
            }

            // Observe volume changes
            volumeObserver = audioSession?.observe(\.outputVolume, options: [.new, .old]) { [weak self] session, change in
                guard let self = self, self.isListening else { return }

                // Ignore volume changes caused by our reset
                if self.isResettingVolume {
                    return
                }

                let newVolume = change.newValue ?? 0.5
                let oldVolume = change.oldValue ?? self.initialVolume

                if newVolume > oldVolume {
                    // Volume up pressed
                    DispatchQueue.main.async {
                        self.volumeButtonChannel?.invokeMethod("onVolumeUp", arguments: nil)
                    }
                    // Reset volume to prevent hitting max/min
                    self.resetVolume()
                } else if newVolume < oldVolume {
                    // Volume down pressed
                    DispatchQueue.main.async {
                        self.volumeButtonChannel?.invokeMethod("onVolumeDown", arguments: nil)
                    }
                    // Reset volume to prevent hitting max/min
                    self.resetVolume()
                }
            }

            isListening = true
            result(true)
        } catch {
            print("Failed to setup audio session: \(error)")
            result(false)
        }
    }

    private func findSlider(in view: UIView) -> UISlider? {
        for subview in view.subviews {
            if let slider = subview as? UISlider {
                return slider
            }
            if let found = findSlider(in: subview) {
                return found
            }
        }
        return nil
    }

    private func resetVolume() {
        // Reset volume to middle to allow continued detection
        // Re-find slider if not cached (iOS may recreate view hierarchy)
        if volumeSlider == nil, let vv = volumeView {
            volumeSlider = findSlider(in: vv)
        }

        guard let slider = volumeSlider else { return }

        isResettingVolume = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            slider.setValue(0.5, animated: false)
            slider.sendActions(for: .valueChanged)
            // Allow a brief delay for the observer to fire before re-enabling
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.isResettingVolume = false
            }
        }
    }

    private func stopListening(result: @escaping FlutterResult) {
        volumeObserver?.invalidate()
        volumeObserver = nil
        volumeView?.removeFromSuperview()
        volumeView = nil

        do {
            try audioSession?.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }

        audioSession = nil
        isListening = false
        result(nil)
    }
}
