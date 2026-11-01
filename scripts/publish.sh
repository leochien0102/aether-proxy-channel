#!/usr/bin/env bash
# Build, sign and publish the channel release (aether-proxy docs/08 "发布通道").
#
#   publish.sh <aether-proxy checkout> [packages dir]
#
# Without a packages dir this is a data-only release: the package entries of the published
# manifest are kept. Env: GH_TOKEN, GITHUB_REPOSITORY, USIGN (usign binary), USIGN_SECRET_KEY.
# Optional COMPATIBILITY_FILE: compatibility object JSON; new bridge assets live beside it.
#
# Asset rule: a file already in the release is never replaced. Rebuilt packages with an
# unchanged version keep their old manifest entry (tools/channel/build.py), so only the old
# bytes match its sha256; uploading the new build over it would break every device's check.
set -euo pipefail

src=$1
packages=${2:-}
tag=channel-stable
root=$(cd "$(dirname "$0")/.." && pwd)
keys="$root/keys"
usign=${USIGN:?USIGN must point to the usign binary}
: "${USIGN_SECRET_KEY:?USIGN_SECRET_KEY is not set}"

# Fail before any release mutation if explicitly supplied input is missing or invalid JSON.
compatibility=()
if [ "${COMPATIBILITY_FILE+x}" = x ]; then
	python3 - "$COMPATIBILITY_FILE" <<'PY'
import json, sys
from pathlib import Path
json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
PY
	compatibility=(--compatibility "$COMPATIBILITY_FILE")
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

release_assets() {
	gh release view "$tag" --json assets -q '.assets[].name'
}

# 1. The published manifest is the base for current/previous; it must verify like on a device.
previous=()
if gh release view "$tag" >/dev/null 2>&1; then
	if gh release download "$tag" -p manifest.json -p manifest.json.sig -D "$work/prev" 2>/dev/null; then
		"$usign" -V -q -m "$work/prev/manifest.json" -P "$keys" || {
			echo "error: the published manifest does not verify with keys/" >&2
			exit 1
		}
		previous=(--previous "$work/prev/manifest.json")
	fi
else
	# Only used when the release is first created; edit later notes on GitHub (gh release edit).
	gh release create "$tag" --title "aether-proxy channel (stable)" --latest=false \
		--notes $'**这是设备用的更新通道，不是给人下载的发布页。**\n\n设备从这里读取签名清单 `manifest.json`，验签后按清单下载文件。每个包只保留当前版和上一版，规则数据每天更新，所以文件列表里新旧混在一起。\n\n要手工下载某个版本，请到 aether-proxy 的 [Releases](https://github.com/leochien0102/aether-proxy/releases)，每个版本一页、附更新说明。'
fi
if [ "${#previous[@]}" -eq 0 ] && [ -z "$packages" ]; then
	echo "error: no published manifest yet; the first release must include packages" >&2
	exit 1
fi

# 2. Rule data (generator and sanity checks live in aether-proxy) and the release directory.
python3 "$src/tools/data/build.py" --out "$work/data" --cache "$work/cache"
args=(--out "$work/out" --data "$work/data" "${previous[@]}" "${compatibility[@]}")
[ -z "$packages" ] || args+=(--packages "$packages")
python3 "$src/tools/channel/build.py" "${args[@]}"
if [ -e "$work/out/unchanged" ]; then
	echo "manifest unchanged: nothing to publish"
	exit 0
fi

# 3. Sign, then verify with the public keys the devices carry.
(umask 077 && printf '%s\n' "$USIGN_SECRET_KEY" > "$work/key.sec")
"$usign" -S -m "$work/out/manifest.json" -s "$work/key.sec"
rm -f "$work/key.sec"
"$usign" -V -q -m "$work/out/manifest.json" -P "$keys" || {
	echo "error: USIGN_SECRET_KEY does not match any public key in keys/" >&2
	exit 1
}

# 4. Upload what the manifest references and the release lacks.
python3 - "$work/out/manifest.json" > "$work/urls" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))
urls = set()
for entry in m["packages"].values():
    for release in (entry.get("current"), entry.get("previous")):
        for formats in ((release or {}).get("assets") or {}).values():
            urls.update(asset["url"] for asset in formats.values())
urls.update(item["url"] for item in m["data"].values())
for chain in m.get("compatibility", {}).values():
    for step in chain.get("steps", []):
        for formats in step["assets"].values():
            urls.update(asset["url"] for asset in formats.values())
# This same URL set gates uploads and protects referenced assets from cleanup.
print("\n".join(sorted(urls)))
PY
release_assets | sort > "$work/existing"
uploads=()
while read -r url; do
	if grep -qxF "$url" "$work/existing"; then
		continue
	fi
	if [ ! -f "$work/out/$url" ]; then
		echo "error: $url is referenced but neither in the release nor built now" >&2
		exit 1
	fi
	uploads+=("$work/out/$url")
done < "$work/urls"
[ "${#uploads[@]}" -eq 0 ] || gh release upload "$tag" "${uploads[@]}"
release_assets | sort > "$work/existing"
missing=$(comm -23 "$work/urls" "$work/existing")
if [ -n "$missing" ]; then
	# GitHub renames some characters on upload; the manifest url would then 404.
	echo "error: referenced assets missing after upload (renamed by GitHub?):" >&2
	printf '  %s\n' $missing >&2
	exit 1
fi

# 5. Switch devices to the new manifest, then drop assets nothing references any more.
gh release upload "$tag" "$work/out/manifest.json.sig" "$work/out/manifest.json" --clobber
comm -23 "$work/existing" "$work/urls" | { grep -vxE 'manifest\.json(\.sig)?' || true; } | while read -r stale; do
	gh release delete-asset "$tag" "$stale" --yes
done
echo "published: $(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["generated"])' "$work/out/manifest.json")"
