import Flutter
import Network
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // Same channel names and replies as MainActivity.kt, so the Dart callers
  // (device_storage.dart, device_health.dart) are identical on both platforms.
  // The recording and backup channels are deliberately absent: background
  // recording is the `audio` background mode in Info.plist, and the iOS backup
  // target is plain Dart (AppDocumentsBackupTarget). Dart treats a missing
  // channel as "nothing to do".
  private let storageChannel = "com.margo.margo/storage"
  private let deviceChannel = "com.margo.margo/device"

  // NWPathMonitor reports asynchronously, so keep the latest answer.
  private let pathMonitor = NWPathMonitor()
  private var metered = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UIDevice.current.isBatteryMonitoringEnabled = true
    pathMonitor.pathUpdateHandler = { [weak self] path in
      // Cellular or a hotspot (isExpensive), or Low Data Mode (isConstrained).
      self?.metered = path.isExpensive || path.isConstrained
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.margo.margo.path"))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    FlutterMethodChannel(name: storageChannel, binaryMessenger: messenger)
      .setMethodCallHandler { call, result in
        guard call.method == "getFreeBytes" else { return result(FlutterMethodNotImplemented) }
        // "Important usage" counts space iOS would free on demand (caches), the
        // figure Apple recommends before a large download.
        let home = URL(fileURLWithPath: NSHomeDirectory())
        if let free = try? home.resourceValues(
          forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage {
          result(NSNumber(value: free))
        } else {
          result(FlutterError(code: "STATFS_ERROR", message: "Could not read free space", details: nil))
        }
      }

    FlutterMethodChannel(name: deviceChannel, binaryMessenger: messenger)
      .setMethodCallHandler { [weak self] call, result in
        guard call.method == "snapshot", let self = self else {
          return result(FlutterMethodNotImplemented)
        }
        result(self.deviceSnapshot())
      }
  }

  private func deviceSnapshot() -> [String: Any] {
    let process = ProcessInfo.processInfo
    let device = UIDevice.current

    // Android's scale: 0 none, 1 light, 3 severe, 4 critical. The Dart side
    // pauses background work from 2 up, i.e. from iOS "serious".
    let thermal: Int
    switch process.thermalState {
    case .nominal: thermal = 0
    case .fair: thermal = 1
    case .serious: thermal = 3
    case .critical: thermal = 4
    @unknown default: thermal = 0
    }

    // batteryLevel is -1 when it cannot be read; the Dart side treats anything
    // outside 0-100 as unknown.
    let battery = device.batteryLevel < 0 ? -1 : Int((device.batteryLevel * 100).rounded())

    return [
      "totalRamBytes": NSNumber(value: process.physicalMemory),
      "thermalStatus": thermal,
      "thermalHeadroom": NSNull(),  // iOS has no forecast
      "batteryPercent": battery,
      "charging": device.batteryState == .charging || device.batteryState == .full,
      "powerSave": process.isLowPowerModeEnabled,
      "metered": metered,
    ]
  }
}
