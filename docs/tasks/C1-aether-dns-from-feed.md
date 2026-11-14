# C1 aether-dns 改由 proxy feed 构建，删除 DNS staging 与钉版

状态：**已实现并合并**（2026-11-14）。

**前置（顺序不能反）**：

1. aether-proxy 的 `M4-20` 已合并：proxy 仓库里已有 `aether-dns/Makefile`（chinadns-ng 模式，
   下载 DNS Release 的裸二进制并按架构校验哈希）；
2. `AETHER_PROXY_REF` 已指向包含该 Makefile 的 commit；
3. aether-dns 1.0.2 已发布，Release 含每架构裸二进制。

- **单一目标**：aether-dns 像其它包一样由本通道的 SDK 构建产生，删除"从 DNS Release 下载
  ipk/apk 再 stage"的特殊路径与两个 pin 文件。
- **分支**：`feat/c1-aether-dns-from-feed`

## 背景

- 设计依据：aether-proxy 仓库的 `docs/design/versioning-20261114.md` §6（T1/T3）；
- 现状：`packages.yml` 在 SDK 构建后用 `AETHER_DNS_RELEASE` + `AETHER_DNS_SHA256SUMS`
  从 DNS Release 下载 ipk/apk 并 stage 到 `packages/<arch>/channel/`；
- 目标：`aether-dns` 与 `aether-xray`、`chinadns-ng` 一样，从 source checkout 的包目录构建，
  清单生成沿用 `tools/channel/build.py` 现有逻辑（`PACKAGE_NAMES` 已含 aether-dns）。

## 允许改动

- `.github/workflows/packages.yml`
- `AETHER_DNS_RELEASE`、`AETHER_DNS_SHA256SUMS`（**删除**）
- `README.md`（来源说明）
- 如需：`scripts/publish.sh`（只改与 aether-dns 相关的注释/校验）

**不改**：DNS 仓库、proxy 仓库的 `aether-dns/Makefile`、清单格式、签名逻辑。

## 要求

1. 构建列表加 `aether-dns`：
   - `PACKAGES` 环境变量加 `aether-dns`；
   - "Copy binary packages from the pinned application source" 步骤加
     `cp -a src/aether-proxy/aether-dns ./aether-dns`；
   - SDK 构建产物应出现 `aether-dns_*.ipk` / `aether-dns-*.apk`。
2. 删除 `Stage prebuilt aether-dns packages` 整个步骤，以及 `AETHER_DNS_RELEASE` /
   `AETHER_DNS_SHA256SUMS` 两个文件；`paths` 里的两行一并删除。
3. 清单生成不需要特殊处理：`tools/channel/build.py` 的 `PACKAGE_NAMES` 已含 `aether-dns`，
   构建目录里出现该包后会被正常选取；确认 `previous` 滚动与其它包一致。
4. 校验：构建结束后断言 `aether-dns` 的产物版本与 `src/aether-proxy/aether-dns/Makefile` 的
   `PKG_VERSION`-`PKG_RELEASE` 一致；不一致失败（与其它包的版本校验风格一致）。
5. 更新 `README.md`：说明 aether-dns 现在与本通道其它包同源（proxy feed），
   DNS 仓库的 Release 只服务人工下载。

## 验收

1. 一次真实的 `packages` 运行成功，产物含 aether-dns 的 ipk/apk（四个 SDK/架构组合）；
2. 清单里 `aether-dns` 的 `current` 版本与 proxy `aether-dns/Makefile` 一致，
   哈希与构建产物一致；`previous` 正确滚动；
3. `aether-proxy` / `luci-app-aether-proxy` 的更新不受影响；
4. 删除后仓库里不再有 `AETHER_DNS_*` 引用（`grep -r AETHER_DNS .` 为空）；
5. 报告给出：运行 id、清单片段、产物哈希与 Makefile 版本的比对、删除项清单。

## 不做

- 不改 DNS 仓库的发布物、不改 proxy 的 Makefile、不改清单 schema、不发版。
