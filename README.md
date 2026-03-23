# website

静态官网目录（应用介绍 + 下载链接）。

## 本地预览

```bash
cd website
python3 -m http.server 8080
```

打开 `http://127.0.0.1:8080`。

## 配置下载地址

编辑 `config.js` 的 `githubRepo`，格式：

```js
window.HABITCREDITS = { githubRepo: "manmanclaw/HabitCredits" };
```

页面会自动拼接：

- `https://github.com/<repo>/releases/latest/download/HabitCredits.dmg`
- `https://github.com/<repo>/releases/latest/download/HabitCredits-macOS.zip`
