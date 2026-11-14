# aether-proxy-channel

[aether-proxy](https://github.com/leochien0102/aether-proxy) 的签名更新通道：编译、签名、发布。不放应用源码。

设备从 Release `channel-stable` 读取 `manifest.json` 与 `manifest.json.sig`，用随 aether-proxy 安装的公钥（`keys/` 中同一把）验签后再下载资产。
设计见 aether-proxy 仓库 `docs/08-updates.md`。

| 内容 | 作用 |
|---|---|
| `AETHER_PROXY_REF` | 要打包的 aether-proxy 提交（完整哈希）；包源（含 `aether-dns/`、`aether-xray/`、`chinadns-ng/`）在应用仓库，gate/build 时复制，不在本仓库保存 |
| `keys/` | 通道公钥（文件名为 usign 指纹），发布前验签 |
| `scripts/publish.sh` | 生成数据与清单、签名、上传（已有资产不覆盖）、清理旧资产 |
| `.github/workflows/packages.yml` | Xray 版本闸门（`tests/ci/xray.sh`，上游 `xray run -test`）→ SDK 编译 `aether-xray` 等包 → 发布（仅 `main`） |
| `.github/workflows/data.yml` | 每天发布规则数据（不编译包，没有变化就不发布） |

当前应用打包版本为 **aether-proxy 1.1.2**（`AETHER_PROXY_REF` 固定为 `6b52be8f3e1ae9648f9d02ab674a66f218521275`）；后端、LuCI 与中文翻译包一起构建，运行时使用独立的 `aether-xray` 包。

全量固件使用 aether-proxy 应用仓库中的 `aether-xray` 和 `chinadns-ng` 包；应用显式依赖这两个独立包。channel 只负责包的构建、签名与发布，不再维护它们的源码副本。gate 和 build 均在 checkout 固定应用提交后，将 `src/aether-proxy/aether-xray` 和 `src/aether-proxy/chinadns-ng` 同时复制到 feed 根的对应目录，再读取 Makefile 或构建。`chinadns-ng` 保持 2025.08.09、安装 `/usr/bin/chinadns-ng`，版本 bump 也只在应用仓库进行；它仍不自动更新。

**版本 bump 在 aether-proxy 仓库进行**：只改应用仓库的 `aether-xray/Makefile`（版本、源码 hash 和必要的 Go 工具链固定值）；验证合并后，channel 通过更新 `AETHER_PROXY_REF` 选择该提交。channel 原有 `.github/workflows/xray-bump.yml` 已删除，不再定时修改本仓库的 Makefile。
SDK 构建列表为 `aether-dns aether-xray chinadns-ng aether-proxy luci-app-aether-proxy`，产物检查另包含 `luci-i18n-aether-proxy-zh-cn`；不再要求构建或产出 `xray-core`。

`aether-dns` 也由固定应用提交中的 proxy feed（`src/aether-proxy/aether-dns/Makefile`）提供：
gate/build 将其复制到 feed 根目录，与其它包一起由四个 SDK/架构组合构建，
不再下载或 stage DNS Release 的 ipk/apk。Makefile 下载并校验上游裸二进制；
DNS 仓库的 Release 只服务人工下载，不作为通道的预构建包来源。
构建后逐个矩阵检查包文件名版本与 Makefile 的 `PKG_VERSION`、`PKG_RELEASE` 一致
（沿用生成器的 `-N` / `-rN` 渲染约定），清单收集、哈希与 `current/previous` 滚动使用现有通用逻辑。
合并本改动时，所有者须一并将 `AETHER_PROXY_REF` 更新为含该 Makefile 的提交；本改动不调整 ref。

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

## Bridge 资产发布（T11.15）

`scripts/publish.sh` 支持可选环境变量 `COMPATIBILITY_FILE`，原样传给应用仓库的
`tools/channel/build.py --compatibility <file>`。该文件是 compatibility 对象本身
（顶层为 `aether-proxy`，不是完整 manifest）；格式、`required_steps`、有序 steps、
终点版本与资产 hash/size 由 T11.14 builder 校验，并写入最终签名 manifest。
新的历史 bridge 包放在 JSON 同目录；已发布的资产允许复用，但元数据不能冲突。

维护者准备并审核输入后，调用形式为：

```sh
COMPATIBILITY_FILE=/path/to/reviewed/compatibility.json \
  scripts/publish.sh /path/to/app-with-T11.14 /path/to/verified-packages
```

这是真实发布命令的说明，不是本任务执行的测试命令。需要原有的签名环境和发布权限。
显式设置为空、文件不存在或非法 JSON 会在任何 release 操作之前失败；链或资产校验失败
不会签名、上传或切换 manifest。未设置时不传新参数：无链旧清单行为不变；已有链由
builder 从验签后的旧 manifest 继承，数据更新也不会清掉历史 bridge 包。
上传、上传后存在性检查、stale 删除共用同一份 URL 集合：packages current/previous、
data 与全部 compatibility steps；不再被任何部分引用的资产才会清理。

本次不修改 `AETHER_PROXY_REF`、版本、keys 或 RC 资产契约。当前固定的旧应用 ref
不因此自动获得 T11.14 builder；使用 compatibility 必须明确选择包含 T11.14 的发布工具。
上传、上传后存在性检查、stale 删除共用同一份 URL 集合：packages current/previous、
data 与全部 compatibility steps；不再被任何部分引用的资产才会清理。

离线验证（在 app checkout 执行）：

```sh
CHANNEL_ROOT=/path/to/aether-proxy-channel python3 -m unittest tools.channel.test_build
CHANNEL_ROOT=/path/to/aether-proxy-channel python3 tests/release/test_rc_promotion.py
```

## Bridge 发布链路（T11.16）

**版本规范（返工后）**：包的 canonical version 就是包文件名里的版本串（同一包
ipk/apk 必须一致），manifest、compatibility 步骤与设备比较全部使用它。RC 与
promote 共用 RC commit 里 `tools/channel/build.py` 的 `canonical_version()`：接受
真实发布的两种渲染（标准包 `-<release>` 如 `0.6.3-1`、`luci.mk` 包 `-r<release>`
如 `0.6.3-r1`），不匹配 Makefile 即失败；正式 tag（`v<version>-r<release>`）是
单独的 tag 规范，经 rc-manifest 的 `target_tag` 绑定。

`promote.yml` 现在会自动携带 bridge 链，前提是 app 的 RC 带了受审文件：

- app 的 `release-candidate.yml` 在 tagged commit 里发现 `bridges/compatibility.json`
  时，把它原样放进 prerelease（资产 22→23）并在 `rc-manifest.json` 写入
  `"compatibility": "<资产名>"` 绑定；终点步不是本 RC 构建版本的 aether-proxy 时
  RC 失败。没有该文件时 RC 与 promote 行为完全不变，也不声称支持 bridge。
- `promote.yml` 按 rc-manifest 的绑定下载 compatibility 文件，先检查终点步必须
  等于本 RC 构建的 aether-proxy 版本（fail-fast），再按文件里的 url 逐个取历史
  字节：目标步的资产必须就是本 RC 构建的 aether-proxy 包（noarch 取
  aarch64_generic 字节），历史步从既有 `channel-stable` 按名下载；每步必须
  ipk+apk 齐备，逐一校验 sha256/size。缺任一资产、hash/size 不符、非法 JSON
  都在这一步立即失败，先于 preflight、签名与任何 release 操作。
- 校验通过后把字节与文件放在 `bridge/`（`COMPATIBILITY_FILE` 指向其中的
  compatibility.json，经 `GITHUB_ENV` 传给后续步骤），preflight 与
  `scripts/publish.sh` 用同一份输入；生成器从 JSON 同目录取新 bridge 字节。
  仍然不 checkout app 源码、不调用 SDK 或编译器。

app 仓库**尚未登记任何链**（`bridges/compatibility.json` 不存在）：首个真实链
在全部步骤的 ipk+apk 字节可核对后由维护者提交，此前 promote 走无链路径。测试
里的链是合成 fixture，不代表已发布的链。`COMPATIBILITY_FILE` 手工发布路径
（上一节）不变。

## C1 本地验证记录

本次仅完成 feed 构建路径及离线验证，未运行 SDK、签名、发布或 push。

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/packages.yml'))"`：通过；
  环境未安装 actionlint，另对 workflow 全部 `run` 脚本执行 `bash -n`，通过。
- 从 workflow 提取实际 DNS 版本检查脚本，以相邻应用 checkout 的 Makefile
  （`PKG_VERSION=1.0.2`、`PKG_RELEASE=1`）为输入，在临时目录执行四个矩阵共 30 个用例：
  `-1` / `-r1` 正例通过；错误版本、错误 release、缺包、多版本、缺失 Makefile release，
  以及 ipk 架构错误均按预期失败。测试使用合成文件名，不验证包内部元数据或二进制。
- 只读调用应用仓库 `tools/channel/build.py`，用六个包的双架构 ipk/apk 合成文件验证：
  全部被收集，清单 SHA-256/size 与输入字节一致，更新时旧 `current` 成为 `previous`，
  同版本重建保留原 `current/previous`。包含后端、LuCI 与翻译包；未修改生成器或清单格式。
  合成清单版本片段为 `aether-dns: {current: {version: "1.0.2-1"}, previous: {version: "1.0.1-1"}}`，
  仅用于验证滚动逻辑，不是真实发布清单。
- 旧 DNS pin 引用检查：除 `.git` 历史和 `docs/tasks/C1-aether-dns-from-feed.md`
  的旧流程背景、删除要求外无匹配；任务卡按允许改动范围保留原文。
- 删除项：两个 DNS pin 文件、workflow 对应的两条 `paths`、完整 DNS staging 步骤。
  `git diff --check` 通过；`AETHER_PROXY_REF` 与 `scripts/publish.sh` 未改动。

真实 Actions **运行 ID：无（未触发）**；真实产物哈希与发布清单片段尚不可提供，
不能用合成数据替代验收。合并时所有者更新 ref 后，仍须核验四个 SDK/架构组合成功、
DNS 产物与 Makefile 版本一致、清单哈希匹配，以及真实 `previous` 正确滚动。

## 许可证

本仓库的脚本与工作流以 **GPL-3.0-or-later** 发布（见 `LICENSE`），与 aether-proxy 相同。
应用仓库 `aether-xray/Makefile` 打包的 Xray 本身是 MPL-2.0（包元数据中的 `PKG_LICENSE`）；
应用仓库 `chinadns-ng/Makefile` 打包的 ChinaDNS-NG 是 AGPL-3.0-only，二进制未经修改，对应源码见上游同版本的 tag（[zfl9/chinadns-ng](https://github.com/zfl9/chinadns-ng)）；发布的规则数据各自的来源与许可证见 aether-proxy 仓库 `aether-proxy/files/data/SOURCES.md`，数据随包安装。
