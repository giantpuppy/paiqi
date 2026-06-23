# 排期天菜发布会 PPT

基于 [Marp](https://marp.app/) 生成，可直接导出 PDF / PPTX / HTML，再导入 Canva 二次编辑。

## 在线预览与二维码

> **注意**：`paiqi.vercel.app` 已被他人占用，扫码会打开一个医院内部系统。当前二维码已改为指向 **GitHub Pages** 稳定地址。

- **在线预览地址**：`https://giantpuppy.github.io/leeks-genius`
- **二维码文件**：`presentation/assets/qr_paiqi_preview.png`
- **GitHub Pages 自动部署**：`.github/workflows/deploy-gh-pages.yml`
- **Vercel 部署配置**：`vercel.json`（备用，需自行选择可用域名）
- **本地一键部署脚本**：`scripts/deploy_vercel.ps1` / `scripts/deploy_vercel.sh`

### GitHub Pages 启用步骤

1. 把当前改动 push 到 GitHub。
2. 进入仓库 Settings → Pages。
3. Source 选择 **Deploy from a branch**，Branch 选择 `gh-pages` / `/(root)`，点击 Save。
4. 等待 1–2 分钟，访问 `https://giantpuppy.github.io/leeks-genius`。

### Vercel 部署（如需使用）

由于 `paiqi.vercel.app` 已被占用，部署后会得到随机子域名（如 `paiqi-xxx.vercel.app`），或你可绑定自己的域名。

```powershell
# Windows
.\scripts\deploy_vercel.ps1

# macOS / Linux / Git Bash
bash scripts/deploy_vercel.sh
```

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `presentation.md` | Marp 幻灯片源文件（18 页） |
| `presentation.pdf` | 最终导出 PDF |
| `presentation.pptx` | 最终导出 PPTX |
| `presentation.*.png` | 各页幻灯片 PNG 截图 |
| `assets/` | 素材（二维码等） |

## 品牌规范

- **中文名：** 排期天菜
- **英文名：** LeeksGenius
- **Slogan：** 排期的事，交给排期天菜。
- **视觉风格：** 剧场暗黑风，"黑暗中的光"设计哲学
- **配色：**
  - 背景深黑：`#121212`（Canvas）
  - 品牌紫：`#6B5BCD`（Brand Primary）
  - 想看紫：`#811FE2`
  - 已买绿：`#34D399`
  - 今日红：`#F54A45`
  - 文字白：`#FFFFFF`
  - 辅助灰：`#B3B3B3`

## 安装 Marp CLI

```bash
# 方式一：npm 安装
npm install -g @marp-team/marp-cli

# 方式二：npx 临时使用（推荐）
npx @marp-team/marp-cli --version
```

## 导出命令

### 导出 PDF

```bash
cd presentation
npx @marp-team/marp-cli presentation.md --pdf --allow-local-files
```

### 导出 PPTX（可编辑）

```bash
cd presentation
npx @marp-team/marp-cli presentation.md --pptx --allow-local-files
```

### 导出 HTML

```bash
cd presentation
npx @marp-team/marp-cli presentation.md --html --allow-local-files
```

### 实时预览

```bash
cd presentation
npx @marp-team/marp-cli presentation.md --preview --watch
```

## 导入 Canva

1. 导出为 **PDF** 或 **PPTX**
2. 打开 Canva，创建演示文稿
3. 点击「上传」→ 选择导出的 PDF/PPTX
4. Canva 会自动按页拆分
5. 替换占位截图、调整字体、贴二维码

---
