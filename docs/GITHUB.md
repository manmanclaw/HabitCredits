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
- `HabitCredits-macOS.zip`（用于发布）

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

## 四、可选：用 GitHub Actions 自动打包

若需要「打 tag 自动构建并上传 Release」，可在仓库添加 `.github/workflows/release.yml`。需要苹果开发者证书与 Secrets 配置，复杂度较高；有需求可再单独加。

---

## 五、仓库里已忽略的内容

见根目录 `.gitignore`：例如 `.build/`、`DerivedData/`、`dist/` 打包产物、`xcuserdata` 等，避免把本机缓存和安装包提交进仓库。
