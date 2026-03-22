# 用 GitHub 管理代码 & 发布 Mac 安装包

## 一、代码放到 GitHub（首次）

1. 在 [GitHub](https://github.com) 新建仓库（例如 `HabitCredits`），**不要**勾选自动添加 README（若本地已有代码）。

2. 在本项目根目录执行（把地址换成你的仓库）：

```bash
cd /path/to/HabitCredits
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/<你的用户名>/HabitCredits.git
git push -u origin main
```

3. 若仓库已存在且远程已配置，日常只需：

```bash
git add .
git commit -m "说明本次修改"
git push
```

---

## 二、Mac 打包（生成可上传的 zip）

项目已包含脚本：`scripts/package-release.sh`

在**项目根目录**执行：

```bash
chmod +x scripts/package-release.sh
./scripts/package-release.sh
```

会在 `dist/` 下生成：

- `HabitCredits.app`
- `HabitCredits-macOS.zip`
- `HabitCredits.dmg`（磁盘映像，双击即可挂载后拖入「应用程序」）

> **说明**：脚本默认 `CODE_SIGNING_ALLOWED=NO`，适合本机测试或内部分发。若要对外公开下载且减少「无法验证开发者」提示，需用 Apple Developer 账号做**代码签名 + 公证（notarize）**，再在 Xcode 里用 Archive 流程导出；此处不展开。

---

## 三、把安装包发到 GitHub（Releases）

**思路**：代码仍在仓库里；**安装包**作为 **Release 附件**上传，**不要**把大体积 zip 提交进 Git 历史（`.gitignore` 已忽略 `dist/`）。

### 方式 A：网页操作

1. 打开 GitHub 仓库 → **Releases** → **Draft a new release**。
2. **Tag** 填版本号，例如 `v1.0.0`。
3. **Release title** 写标题，说明里写更新内容。
4. 将本地的 `dist/HabitCredits-macOS.zip` **拖进**「Attach binaries」区域。
5. 发布 **Publish release**。

### 方式 B：命令行（需安装 [GitHub CLI](https://cli.github.com/)）

```bash
gh auth login
gh release create v1.0.0 dist/HabitCredits-macOS.zip \
  --title "HabitCredits v1.0.0" \
  --notes "首次发布"
```

---

## 四、CI/CD：每次提交自动云端打包

仓库已包含 **GitHub Actions** 工作流：`.github/workflows/macos-build.yml`。

- **何时运行**：向 `main` 或 `master` **push** 时；对这些分支的 **Pull Request** 也会跑；也可在 Actions 里 **手动运行**（workflow_dispatch）。
- **做什么**：在 GitHub 的 **macOS 虚拟机**上用 Xcode 打 **Release**，生成 `HabitCredits-macOS.zip`。
- **去哪里下载**：仓库页 → **Actions** → 点进最近一次成功的工作流 → 底部 **Artifacts** → 下载 zip（不会自动出现在 Releases 里，避免每次 push 都造一个 Release）。

> 与本地 `scripts/package-release.sh` 一样，默认 **不签名**（`CODE_SIGNING_ALLOWED=NO`）。若要 CI 里自动签名/公证，需把证书与 Secrets 配进仓库，可后续再加。

### Tag 自动发版（推荐）

仓库已包含：`.github/workflows/release-on-tag.yml`。

当你 **推送以 `v` 开头的 tag**（例如 `v1.0.0`）时，会：

1. 在云端打 Release 包，生成 **`HabitCredits-macOS.zip`** 与 **`HabitCredits.dmg`**  
2. **自动创建 GitHub Release**，并把上述两个文件作为 **Assets** 上传（并生成简要 Release notes）

### Release 页上的「源代码 zip」是什么？

每个 Release 下方 **GitHub 会自动附带**「Source code (zip / tar.gz)」，那是 **仓库在该 tag 上的源码快照**，**无法关闭**。  
**真正的安装包**请往下看 **Assets** 里的：

- `HabitCredits.dmg`（推荐给用户）
- `HabitCredits-macOS.zip`（解压得到 `.app`）

若 **Assets** 里只有源码、没有 dmg/zip，说明 **Actions 工作流失败**，请到 **Actions** 里查看报错。

本地命令示例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

> Tag 须匹配 `v*`（如 `v1.0.0`），不要用 `1.0.0` 无 `v` 前缀，否则不会触发（除非你改 workflow）。

---

## 五、仓库里已忽略的内容

见根目录 `.gitignore`：例如 `.build/`、`DerivedData/`、`dist/` 打包产物、`xcuserdata` 等，避免把本机缓存和安装包提交进仓库。
