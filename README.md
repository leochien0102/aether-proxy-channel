# aether-proxy-channel

[aether-proxy](https://github.com/leochien0102/aether-proxy) 的签名更新通道：编译、签名、发布。不放应用源码。

设备从 Release `channel-stable` 读取 `manifest.json` 与 `manifest.json.sig`，用随 aether-proxy 安装的公钥（`keys/` 中同一把）验签后再下载资产。
设计见 aether-proxy 仓库 `docs/08-updates.md`。

| 内容 | 作用 |
|---|---|
| `AETHER_PROXY_REF` | 要打包的 aether-proxy 提交（完整哈希）；包源（含 `aether-xray/`、`chinadns-ng/`）在应用仓库，gate/build 时复制，不在本仓库保存 |
| `keys/` | 通道公钥（文件名为 usign 指纹），发布前验签 |
| `scripts/publish.sh` | 生成数据与清单、签名、上传（已有资产不覆盖）、清理旧资产 |
| `.github/workflows/packages.yml` | Xray 版本闸门（`tests/ci/xray.sh`，上游 `xray run -test`）→ SDK 编译 `aether-xray` 等包 → 发布（仅 `main`） |
| `.github/workflows/data.yml` | 每天发布规则数据（不编译包，没有变化就不发布） |

当前应用打包版本为 **aether-proxy 0.6.3-r1**（`AETHER_PROXY_REF` 固定为 `7380587a2226353e5661ede0d685311d6e751275`）；后端、LuCI 与中文翻译包一起构建，运行时使用独立的 `aether-xray` 包。

全量固件使用 aether-proxy 应用仓库中的 `aether-xray` 和 `chinadns-ng` 包；应用显式依赖这两个独立包。channel 只负责包的构建、签名与发布，不再维护它们的源码副本。gate 和 build 均在 checkout 固定应用提交后，将 `src/aether-proxy/aether-xray` 和 `src/aether-proxy/chinadns-ng` 同时复制到 feed 根的对应目录，再读取 Makefile 或构建。`chinadns-ng` 保持 2025.08.09、安装 `/usr/bin/chinadns-ng`，版本 bump 也只在应用仓库进行；它仍不自动更新。

**版本 bump 在 aether-proxy 仓库进行**：只改应用仓库的 `aether-xray/Makefile`（版本、源码 hash 和必要的 Go 工具链固定值）；验证合并后，channel 通过更新 `AETHER_PROXY_REF` 选择该提交。channel 原有 `.github/workflows/xray-bump.yml` 已删除，不再定时修改本仓库的 Makefile。
SDK 构建列表为 `aether-xray chinadns-ng aether-proxy luci-app-aether-proxy`，产物检查另包含 `luci-i18n-aether-proxy-zh-cn`；不再要求构建或产出 `xray-core`。

`aether-xray` 当前上游版本为 **26.10.31**（release 为 1），不带 feeds/packages 或 feeds/ssr-plus 的补丁。
产物名为 `aether-xray_*.ipk` / `aether-xray-*.apk`，不会覆盖 feeds/ssr-plus 的 `/usr/bin/xray`，也不自动卸载旧包。
发布生成器 `tools/channel/build.py`（位于 aether-proxy 仓库）原样保留旧 manifest 的 `xray-core` 条目供旧客户端使用；不重命名或删除旧历史。
历史 `bump/xray-*` 分支已清理；后续版本 bump 只在应用仓库进行。

签名私钥只在 Actions Secret `USIGN_SECRET_KEY` 中，PR 与非 `main` 分支的运行拿不到，也不发布。

## RC 原样晋升（T11.12）

在 **main** 手动运行 `.github/workflows/promote.yml`，输入 app 已验收的 `rc_tag`（如 `v0.6.3-rc1`）。这是新增路径；原 `packages.yml` / `data.yml` 行为保留，不要为晋升再次触发 SDK 构建。

- 只接受公开 prerelease；下载 20 个 RC 包、`rc-manifest.json` 和 `SHA256SUMS`，检查完整矩阵、版本、tag commit 和两层 hash。
- 不 checkout app 源码，不调用 SDK 或编译器。只按 RC commit 下载两个独立发布工具和 Makefile 版本元数据；以系统包安装 usign。
- `tools/channel/build.py --packages packages` 先预检，再由现有 `scripts/publish.sh publisher packages` 生成数据、签名和发布 `channel-stable`。与其他发布共用 `channel-publish` 并发锁。
- 已有同名包不同字节、同版本清单不同均失败，不用覆盖或静默保留旧字节来冒充晋升成功。noarch 按现有生成器选 `aarch64_generic` 路径的原始字节；正式包通常 14 个文件，均来自已校验的 RC。
- `USIGN_SECRET_KEY` 只在最后一个发布步骤取自 Actions Secret。PR、非 main dispatch 不发布。
- 正式 tag 必须使用 RC 清单记录的 `target_tag` 和同一 app commit；若正式 tag 已存在，promote 检查其 commit。若尚不存在，后续创建和保护 tag 是维护者责任；按本卡约束未改 app `release-assets.yml`，它仍只从 channel manifest 复制包，不能自动检查未来 tag 的 RC commit。

离线测试在 app 仓库：

```sh
CHANNEL_ROOT=/path/to/aether-proxy-channel python3 tests/release/test_rc_promotion.py
```

执行该命令的当前目录是 app checkout。fake gh / artifact / signer 不访问网络、不发布；测试真实 workflow 脚本及现有 publish/channel 生成器。详见 `reports/T11.12.md`。本卡不修改版本或 `AETHER_PROXY_REF`，不创建真实 tag、不 push、不发布。

## 许可证

本仓库的脚本与工作流以 **GPL-3.0-or-later** 发布（见 `LICENSE`），与 aether-proxy 相同。
应用仓库 `aether-xray/Makefile` 打包的 Xray 本身是 MPL-2.0（包元数据中的 `PKG_LICENSE`）；
应用仓库 `chinadns-ng/Makefile` 打包的 ChinaDNS-NG 是 AGPL-3.0-only，二进制未经修改，对应源码见上游同版本的 tag（[zfl9/chinadns-ng](https://github.com/zfl9/chinadns-ng)）；发布的规则数据各自的来源与许可证见 aether-proxy 仓库 `aether-proxy/files/data/SOURCES.md`，数据随包安装。
