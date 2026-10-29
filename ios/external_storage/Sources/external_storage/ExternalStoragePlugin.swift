import Flutter
import UIKit

/// iOS 端只实现 Dart (dart:io) 做不到的部分：存储卷容量和打开设置页。
/// 文件/目录操作与文件监视在 Dart 侧完成；iOS 应用沙盒没有存储权限的概念。
public class ExternalStoragePlugin: NSObject, FlutterPlugin {
  static let channelName = "tech.thispage.external_storage"

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ExternalStoragePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getAllStorageDevices":
      result(StorageVolumes.devices())
    case "getStorageSpace":
      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Missing argument 'path'", details: nil))
        return
      }
      do {
        result(try StorageVolumes.space(at: URL(fileURLWithPath: path)))
      } catch {
        result(FlutterError(
          code: "NATIVE_ERROR",
          message: "getStorageSpace: \(error.localizedDescription)",
          details: nil))
      }
    case "openAppSettings":
      openAppSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func openAppSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(["success": false])
      return
    }
    UIApplication.shared.open(url, options: [:]) { opened in
      result(["success": opened])
    }
  }
}
