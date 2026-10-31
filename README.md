# aether-proxy-channel

[aether-proxy](https://github.com/leochien0102/aether-proxy) 的签名更新通道：编译、签名、发布。不放应用源码。

设备从 Release `channel-stable` 读取 `manifest.json` 与 `manifest.json.sig`，用随 aether-proxy 安装的公钥（`keys/` 中同一把）验签后再下载资产。
设计见 aether-proxy 仓库 `docs/08-updates.md`。

| 内容 | 作用 |
|---|---|
| `aether-xray/Makefile` | 从 XTLS/Xray-core 上游 tag 源码编译无补丁的 `aether-xray`，固定官方 Go 工具链，安装 `/usr/bin/aether-xray` |
| `chinadns-ng/Makefile` | 打包 ChinaDNS-NG 上游发布的静态二进制（按 sha256 固定），供固件里没有它的用户**手工安装**；设备不会检查、安装或更新它 |
| `AETHER_PROXY_REF` | 要打包的 aether-proxy 提交（完整哈希） |
| `keys/` | 通道公钥（文件名为 usign 指纹），发布前验签 |
| `scripts/publish.sh` | 生成数据与清单、签名、上传（已有资产不覆盖）、清理旧资产 |
| `.github/workflows/packages.yml` | Xray 版本闸门（`tests/ci/xray.sh`，上游 `xray run -test`）→ SDK 编译 `aether-xray` 等包 → 发布（仅 `main`） |
| `.github/workflows/data.yml` | 每天发布规则数据（不编译包，没有变化就不发布） |
| `.github/workflows/xray-bump.yml` | 上游有新版本时在 `bump/aether-xray-*` 开 PR，只改 `aether-xray/Makefile`；合并后才发布 |

当前应用打包版本为 **aether-proxy 0.6.0-r1**（`AETHER_PROXY_REF` 固定为 `d9c48bf29c214eb41263a9a26f13b30fe78eaa25`），从此前的 **0.5.0-r1** 升级；后端、LuCI 与中文翻译包一起构建，运行时使用独立的 `aether-xray` 包。
SDK 构建列表为 `aether-xray chinadns-ng aether-proxy luci-app-aether-proxy`，产物检查另包含 `luci-i18n-aether-proxy-zh-cn`；不再要求构建或产出 `xray-core`。

`aether-xray` 当前上游基版本为 **26.10.21**（release 为 1），与 feeds/packages 的上游基版本对齐，但不带其补丁。
产物名为 `aether-xray_*.ipk` / `aether-xray-*.apk`，不会覆盖 feeds/ssr-plus 的 `/usr/bin/xray`，也不自动卸载旧包。
发布生成器 `tools/channel/build.py`（位于 aether-proxy 仓库）原样保留旧 manifest 的 `xray-core` 条目供旧客户端使用；不重命名或删除旧历史。
旧 `bump/xray-*` 分支不复用、不删除，由仓库所有者后续清理。

签名私钥只在 Actions Secret `USIGN_SECRET_KEY` 中，PR 与非 `main` 分支的运行拿不到，也不发布。

## 许可证

本仓库的脚本与工作流以 **GPL-3.0-or-later** 发布（见 `LICENSE`），与 aether-proxy 相同。
`aether-xray/Makefile` 打包的 Xray 本身是 MPL-2.0（包元数据中的 `PKG_LICENSE`）；
`chinadns-ng/Makefile` 打包的 ChinaDNS-NG 是 AGPL-3.0-only，二进制未经修改，对应源码见上游同版本的 tag（[zfl9/chinadns-ng](https://github.com/zfl9/chinadns-ng)）；发布的规则数据各自的来源与许可证见 aether-proxy 仓库 `aether-proxy/files/data/SOURCES.md`，数据随包安装。
