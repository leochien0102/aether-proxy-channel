# aether-proxy-channel

[aether-proxy](https://github.com/leochien0102/aether-proxy) 的签名更新通道：编译、签名、发布。不放应用源码。

设备从 Release `channel-stable` 读取 `manifest.json` 与 `manifest.json.sig`，用随 aether-proxy 安装的公钥（`keys/` 中同一把）验签后再下载资产。
设计见 aether-proxy 仓库 `docs/08-updates.md`。

| 内容 | 作用 |
|---|---|
| `xray-core/Makefile` | 从 Xray 上游源码包编译 `xray-core`，固定官方 Go 工具链 |
| `AETHER_PROXY_REF` | 要打包的 aether-proxy 提交（完整哈希） |
| `keys/` | 通道公钥（文件名为 usign 指纹），发布前验签 |
| `scripts/publish.sh` | 生成数据与清单、签名、上传（已有资产不覆盖）、清理旧资产 |
| `.github/workflows/packages.yml` | Xray 版本闸门（golden 配置 `xray run -test`）→ SDK 编译 → 发布（仅 `main`） |
| `.github/workflows/data.yml` | 每天发布规则数据（不编译包，没有变化就不发布） |
| `.github/workflows/xray-bump.yml` | 上游有新版本时开 PR；合并后才发布 |

签名私钥只在 Actions Secret `USIGN_SECRET_KEY` 中，PR 与非 `main` 分支的运行拿不到，也不发布。
