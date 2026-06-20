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
| `screenshots/` | 截图存放目录（当前为占位，需替换为 App 实机截图） |
| `assets/` | 其他素材（Logo、二维码等） |

## 品牌规范

- **中文名：** 排期天菜
- **英文名：** Paiqi
- **Slogan：** 排期的事，交给排期天菜。
- **视觉风格：** 像素风 + 星之果实紫绿
- **配色：**
  - 背景黑：`#0F0F0F`
  - 主色紫：`#8B5CF6`
  - 强调绿：`#34D399`
  - 辅助灰：`#B0B0B0`

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

## 截图替换说明

所有截图位置在 `presentation.md` 中用 `【截图位置】` 标记。请按 `screenshots/README.md` 中的规格准备图片，然后替换占位符。

---

**提示：** 当前版本截图位置为 CSS 占位框，不包含真实图片。导出前请先截图并替换。
