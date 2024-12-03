# Changelog

All notable changes to the `external_storage` plugin will be documented in this file.
本文档记录了 `external_storage` 插件的所有重要更新。

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2024-12-03

### Added
- 首次发布核心功能：
  - 存储设备管理（列出设备、获取存储信息）
  - 文件操作（读取、写入、复制、移动、删除）
  - 目录操作（列表、创建、删除、信息）
  - 文件系统监视（监控目录变化）
  - 权限管理（请求和检查存储权限）
  - 路径工具（规范化、连接、分割路径）
- 完整的数据模型：
  - `StorageDevice` 存储设备信息
  - `FileInfo` 文件元数据
  - `DirectoryInfo` 目录详情
  - `WatchEvent` 文件系统事件
- Android 平台接口实现
- 原生通信的方法通道实现
- 空安全支持
- 文档和示例代码