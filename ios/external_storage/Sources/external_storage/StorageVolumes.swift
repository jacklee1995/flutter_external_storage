import Foundation
import UIKit

/// 沙盒所在数据卷的信息。iOS 应用无法按路径访问 U 盘 / SD 卡等外接卷，
/// 只能通过 UIDocumentPickerViewController 取得带安全作用域的 URL。
enum StorageVolumes {
  private static let keys: Set<URLResourceKey> = [
    .volumeTotalCapacityKey,
    .volumeAvailableCapacityKey,
    .volumeAvailableCapacityForImportantUsageKey,
    .volumeIsReadOnlyKey,
    .volumeIsRemovableKey,
    .volumeUUIDStringKey,
    .volumeLocalizedNameKey,
  ]

  /// 以 Documents 目录作为主存储的根路径：它是用户可见的位置
  /// （在 Info.plist 开启 UIFileSharingEnabled 后会出现在「文件」App 中）。
  static func devices() -> [[String: Any]] {
    guard
      let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
      let values = try? documents.resourceValues(forKeys: keys)
    else {
      return []
    }
    var device: [String: Any] = [
      "path": documents.path,
      "name": UIDevice.current.localizedModel,
      "isPrimary": true,
      "isRemovable": values.volumeIsRemovable ?? false,
      "isReadOnly": values.volumeIsReadOnly ?? false,
      "totalSize": values.volumeTotalCapacity ?? 0,
      "availableSize": availableCapacity(values),
    ]
    if let uuid = values.volumeUUIDString {
      device["uuid"] = uuid
    }
    if let label = values.volumeLocalizedName {
      device["description"] = label
    }
    return [device]
  }

  static func space(at url: URL) throws -> [String: Any] {
    let values = try url.resourceValues(forKeys: keys)
    return [
      "totalSpace": values.volumeTotalCapacity ?? 0,
      "freeSpace": values.volumeAvailableCapacity ?? 0,
      "usableSpace": availableCapacity(values),
    ]
  }

  /// 与「设置 > 通用 > iPhone 储存空间」一致的可用空间（包含系统可自动清理的部分）。
  private static func availableCapacity(_ values: URLResourceValues) -> Int64 {
    if let important = values.volumeAvailableCapacityForImportantUsage, important > 0 {
      return important
    }
    return Int64(values.volumeAvailableCapacity ?? 0)
  }
}
