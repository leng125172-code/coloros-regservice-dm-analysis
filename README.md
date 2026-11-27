# ColorOS 预装组件 `com.coloros.regservice` 数据采集行为分析

> 一台一加 15（国行 PLK110，ColorOS 16.0.10.502 / Android 16）的实测记录。
> 全部数据由设备所有者在自有设备上以 **adb + root 只读方式**提取，未修改任何系统文件。
> 采集时间：2026-11-27

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

---

## 一句话结论

ColorOS 国行固件预装的 `com.coloros.regservice`（内部命名空间 `com.dmyk.android.telephony`，集成彩讯 richinfo DM 云控 SDK）在**无桌面入口、无系统设置开关、无独立隐私告知**的情况下，持续采集已安装应用清单、应用使用行为与流量、设备与网络标识，并通过 HTTPS 上传至 `fxltsbl.com`（域名注册人：中国移动通信集团终端有限公司）。

---

## 观测到的采集范围

| 数据类别 | 实测规模 | 说明 |
|---|---|---|
| 已安装应用 | 524 条 | 包名、应用名、启动次数、使用时长、移动/WiFi 收发流量、安装时间、UID |
| 预装应用 | 6010 条 | 包名、版本、签名信息、安装时间 |
| 卡与基站 | 173 条 | 按天记录 ICCID1/2、IMSI1/2、LAC、CellID、PCI |
| 网络环境 | 7 + 7 条 | BSSID、SSID、路由器出口 IP、信号强度 |
| 其他 | — | 电量与温度、蓝牙状态、漫游状态、网速 |

## 观测到的上报行为

```
GET  https://a.fxltsbl.com/getIpAddr
POST https://a.fxltsbl.com/accept/sdkService?func=tsdk:postreglog   设备注册
POST https://a.fxltsbl.com/accept/sdkService?func=tsdk:posthblog    心跳
POST https://a.fxltsbl.com/accept/sdkService?func=tsdk:postapplylog 应用数据
GET  https://a.fxltsbl.com/TerminalConfigService/terminalConf       下发采集开关
```

- 传输：全程 HTTPS；服务器证书为 DigiCert 签发的 `*.fxltsbl.com`（DV 级，仅域名验证）
- 开关：所有采集开关由服务端下发覆盖，客户端无用户可见的关闭入口
- 频次：注册/心跳/网络信息每日一次，应用清单采集周期 7 天；实测 2026-11-27 当日上报 4 次

---

## 证据索引

```
证据/
├── 00_阅读指引.md                    总览与阅读顺序
├── 02_证据_组件本体/
│   ├── RegService系统组件.apk         被分析组件原件（639,658 字节）
│   ├── 采集数据库_脱敏版.db           采集结果（524/6010/173 行数保留）
│   ├── 数据库结构说明.txt             12 张表结构与行数
│   └── 采集字段示例.txt               采集粒度示例（包名已占位符化）
├── 03_证据_行为与配置/
│   ├── 上传接口清单.md                5 个接口 + 10 个触发广播 + 时间线
│   ├── 采集开关配置.md                服务端开关、白名单、采集频率
│   ├── 组件内SDK字符串.txt            二进制内 SDK 标识（375 条）
│   └── 组件内中文字符串.txt           二进制内中文功能串（185 条）
├── 04_证据_域名与证书/
│   ├── 证书_a.fxltsbl.com.txt
│   ├── 证书_b.fxltsbl.com.txt
│   └── DNS解析记录.txt
└── 05_校验与复现/
    ├── 文件哈希清单.txt               全部文件 SHA256
    └── 复现脚本.sh                    重新采样脚本

报告/
├── 技术分析报告.md                    完整分析（结论/证据/合规依据/处置）
└── 投诉正文_完整版.txt                已整理的举报材料正文
```

## 自行复核

```bash
# 1) 看证书级别（DV 还是 OV/EV）
openssl s_client -connect a.fxltsbl.com:443 -servername a.fxltsbl.com </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates

# 2) 看数据库里采了什么
sqlite3 证据/02_证据_组件本体/采集数据库_脱敏版.db '.tables'
sqlite3 证据/02_证据_组件本体/采集数据库_脱敏版.db \
  'select count(*) from app_info_1795218359539;'   # → 524

# 3) 校验文件完整性
sha256sum -c 证据/05_校验与复现/文件哈希清单.txt
```

---

## 隐私说明（重要）

本仓库**不包含任何可识别到个人的原始数据**。所有公开材料均已做如下处理：

| 数据 | 处理 |
|---|---|
| IMEI / ICCID / IMSI / CellID / LAC / PCI / BSSID / SSID / MAC | 统一替换为 `REDACTED` |
| 应用包名、应用名 | 统一替换为 `com.redacted.app` / `REDACTED_APP` |
| 表结构、行数、字段名、统计数值 | **保留**（用于证明采集范围与粒度） |

原始未脱敏数据仅保留在设备所有者本地，**未上传至本仓库**。

---

## 范围与限定

- 本文结论基于**单台设备、单一时点**（2026-11-27）的观测快照，不代表其他机型或系统版本的必然行为。
- 组件行为可能随系统更新、服务端配置变化而改变；复现请以本文所附脚本重新采样为准。
- 文中引用《个人信息保护法》等条款仅用于说明可对照的合规关注点，**不构成法律意见**。
- 被分析组件及其数据库快照的著作权归原权利人，此处仅用于安全研究与合规投诉目的的有限引用。

## 许可

- 文档、分析文字：CC BY 4.0
- `证据/02_证据_组件本体/RegService系统组件.apk`、`采集数据库_脱敏版.db`：仅作证据留存，不授予任何再分发许可

## 相关
- 一加/OPPO 客服：400-888-1111
- 12321 网络不良与垃圾信息举报受理中心：https://www.12321.cn/
