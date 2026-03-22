# HabitCredits

习惯积分 Mac 应用（SwiftUI）。

## 开发与构建

- 用 Xcode 打开 `HabitCredits.xcodeproj` 即可编译运行。
- 命令行：`swift build`（Swift Package）或 Xcode 工程构建 `.app`。

## GitHub 与发布安装包

代码托管、打包 zip、上传到 GitHub **Releases** 的步骤见：**[docs/GITHUB.md](docs/GITHUB.md)**。

**CI**：推送到 `main` 后，GitHub Actions 会自动构建并上传 **Artifacts**（见仓库 **Actions** 页）。

**发版**：打 tag 并推送，例如 `git tag v1.0.0 && git push origin v1.0.0`，会自动创建 **Release** 并附带 `HabitCredits-macOS.zip`（详见 `docs/GITHUB.md`）。

快速打包（生成 `dist/HabitCredits-macOS.zip`）：

```bash
./scripts/package-release.sh
```
