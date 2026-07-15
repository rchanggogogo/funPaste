# Universal DMG and GitHub Release Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an unsigned universal funPaste DMG for both Apple Silicon and Intel Macs, publish it from tagged private GitHub Releases, and document the product and installation experience.

**Architecture:** `scripts/build-dmg.sh` builds each Swift architecture into its own build directory, combines the release executables with `lipo`, and delegates app-bundle creation to `scripts/build-app.sh`. A shell integration test proves the resulting app is universal and the DMG is mountable. GitHub Actions runs tests for changes and invokes the same script for version tags.

**Tech Stack:** Swift Package Manager, Bash, macOS `lipo`, `codesign`, `hdiutil`, GitHub Actions, GitHub Releases.

---

### Task 1: Make the app-bundle script accept a prebuilt universal executable

**Files:**
- Modify: `scripts/build-app.sh`
- Create: `Tests/release-build-tests.sh`

- [ ] **Step 1: Write the failing release-build test**

Create `Tests/release-build-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
version="0.0.0-test"
app="$project_dir/dist/funPaste.app"
dmg="$project_dir/dist/funPaste-$version.dmg"

rm -rf "$app" "$dmg"
bash "$project_dir/scripts/build-dmg.sh" "$version"

[[ -f "$dmg" ]]
[[ -x "$app/Contents/MacOS/funPaste" ]]
[[ "$(lipo -archs "$app/Contents/MacOS/funPaste")" == *arm64* ]]
[[ "$(lipo -archs "$app/Contents/MacOS/funPaste")" == *x86_64* ]]
codesign --verify --deep --strict --verbose=2 "$app"
hdiutil imageinfo "$dmg" | grep -q 'Class Name: CRawDiskImage'
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash Tests/release-build-tests.sh`

Expected: nonzero exit with `scripts/build-dmg.sh: No such file or directory`.

- [ ] **Step 3: Modify the bundle script**

In `scripts/build-app.sh`, replace its unconditional release build and executable copy with:

```bash
if [[ -n "${FUNPASTE_EXECUTABLE_PATH:-}" ]]; then
  executable_path="$FUNPASTE_EXECUTABLE_PATH"
  [[ -x "$executable_path" ]] || { echo "Missing executable: $executable_path" >&2; exit 1; }
else
  swift build -c release --product FunPastePreview
  executable_path="$project_dir/.build/release/FunPastePreview"
fi

cp "$executable_path" "$contents_dir/MacOS/funPaste"
```

- [ ] **Step 4: Verify the existing app build**

Run: `bash scripts/build-app.sh && codesign --verify --deep --strict --verbose=2 dist/funPaste.app`

Expected: exit 0.

- [ ] **Step 5: Commit**

```bash
git add scripts/build-app.sh Tests/release-build-tests.sh
git commit -m "build: allow prebuilt app executables"
```

### Task 2: Build and package a universal unsigned DMG

**Files:**
- Create: `scripts/build-dmg.sh`
- Modify: `.gitignore`
- Test: `Tests/release-build-tests.sh`

- [ ] **Step 1: Add the release script**

Create `scripts/build-dmg.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-1.0.0}"
dist_dir="$project_dir/dist"
arm_build="$project_dir/.build-release-arm64"
intel_build="$project_dir/.build-release-x86_64"
universal_binary="$dist_dir/funPaste-universal"
app="$dist_dir/funPaste.app"
dmg="$dist_dir/funPaste-$version.dmg"
stage_dir="$(mktemp -d)"
trap 'rm -rf "$stage_dir"' EXIT

rm -rf "$arm_build" "$intel_build" "$app" "$universal_binary" "$dmg"
swift build -c release --product FunPastePreview --arch arm64 --build-path "$arm_build"
swift build -c release --product FunPastePreview --arch x86_64 --build-path "$intel_build"
lipo -create "$arm_build/release/FunPastePreview" "$intel_build/release/FunPastePreview" -output "$universal_binary"
lipo -verify_arch arm64 "$universal_binary"
lipo -verify_arch x86_64 "$universal_binary"
FUNPASTE_EXECUTABLE_PATH="$universal_binary" bash "$project_dir/scripts/build-app.sh"
codesign --verify --deep --strict --verbose=2 "$app"
cp -R "$app" "$stage_dir/funPaste.app"
ln -s /Applications "$stage_dir/Applications"
hdiutil create -volname "funPaste" -srcfolder "$stage_dir" -ov -format UDZO "$dmg"
echo "Created $dmg"
```

- [ ] **Step 2: Ignore generated files**

Append:

```gitignore
.build-release-arm64/
.build-release-x86_64/
dist/
```

- [ ] **Step 3: Run the release-build test**

Run: `bash Tests/release-build-tests.sh`

Expected: exit 0; the DMG exists and `lipo -archs` reports both architectures.

- [ ] **Step 4: Commit**

```bash
git add .gitignore scripts/build-dmg.sh Tests/release-build-tests.sh
git commit -m "build: package universal funPaste DMG"
```

### Task 3: Add CI and tagged-release workflows

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Add CI**

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Run UI tests
        run: swift run FunPasteUITestRunner
      - name: Verify universal release build
        run: bash Tests/release-build-tests.sh
```

- [ ] **Step 2: Add the tagged release workflow**

```yaml
name: Release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build DMG
        run: bash scripts/build-dmg.sh "${GITHUB_REF_NAME#v}"
      - name: Create GitHub release
        env:
          GH_TOKEN: ${{ github.token }}
        run: gh release create "$GITHUB_REF_NAME" "dist/funPaste-${GITHUB_REF_NAME#v}.dmg" --generate-notes --title "funPaste $GITHUB_REF_NAME"
```

- [ ] **Step 3: Validate workflow YAML**

Run: `ruby -e "require 'yaml'; %w[.github/workflows/ci.yml .github/workflows/release.yml].each { |path| YAML.load_file(path); puts \"valid: #{path}\" }"`

Expected: both files print `valid:` and exit 0.

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/release.yml
git commit -m "ci: test and release universal DMGs"
```

### Task 4: Document the product and installation experience

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add the product lead**

Insert below the title:

```markdown
复制只是开始。funPaste 一键构建 Prompt，把灵感、剪贴板和常用指令留在手边。按下 `Shift + Command + V`，搜索、收藏、粘贴一气呵成。
```

- [ ] **Step 2: Add a test-release installation section**

Insert before `## 快速开始`:

```markdown
## 安装测试版

测试版同时支持 Apple 芯片和 Intel Mac，要求 macOS 14 或更高版本。

1. 从本仓库的 Releases 下载最新 `.dmg` 文件。
2. 双击 `.dmg`，将 `funPaste.app` 拖入“应用程序（Applications）”文件夹。
3. 首次打开时按住 Control 点按 App，选择“打开”，再确认打开。此测试版未经过 Apple 公证，因此会显示安全提示。
4. 在“系统设置 → 隐私与安全性 → 辅助功能”中允许 funPaste 控制电脑；这是全局快捷键和自动粘贴所必需的权限。

发布者可运行：

```sh
bash scripts/build-dmg.sh 1.0.0
```
```

- [ ] **Step 3: Verify documentation references**

Run: `rg -n "build-dmg.sh|Releases|辅助功能|一键构建 Prompt" README.md && test -x scripts/build-dmg.sh`

Expected: all four terms print and exit 0.

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: explain funPaste test release"
```

### Task 5: Verify and publish the private repository

**Files:**
- Verify: all tracked project files

- [ ] **Step 1: Run full verification**

```bash
swift run FunPasteUITestRunner
bash Tests/release-build-tests.sh
ruby -e "require 'yaml'; %w[.github/workflows/ci.yml .github/workflows/release.yml].each { |path| YAML.load_file(path) }"
git diff --check
```

Expected: each command exits 0.

- [ ] **Step 2: Create the private repository and push main**

```bash
gh repo create funPaste --private --source=. --remote=origin --push
```

Expected: GitHub CLI prints the private repository URL and `git remote -v` lists `origin`.

- [ ] **Step 3: Verify CI**

```bash
gh run list --limit 5
gh run watch --exit-status
```

Expected: the `CI` workflow completes successfully.

- [ ] **Step 4: Publish and verify the first release**

```bash
git tag v1.0.0
git push origin v1.0.0
gh run watch --exit-status
gh release view v1.0.0
```

Expected: the Release workflow succeeds and lists `funPaste-1.0.0.dmg`.

- [ ] **Step 5: Confirm generated files remain untracked**

Run: `git status --short`

Expected: no uncommitted tracked changes; do not commit `dist/` or architecture build directories.
