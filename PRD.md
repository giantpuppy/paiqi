# 排期天菜 (Paiqi App) — 产品需求文档 (PRD)

> **版本**: v1.0  
> **日期**: 2026/06/01  
> **状态**: 开发中（MVP 已完成，UI 优化进行中）  
> **上次更新**: 2026/06/18 — 修复排期流 3天/7天 切换红屏与月历折叠黄黑警告频闪：补齐行高除零保护、动画状态清理与 firstWhere/orElse 边界处理

---

## 📋 变更日志 / 开发进展

| 日期 | 改动内容 | 关联文件/模块 |
|------|---------|-------------|
| 2026/06/20 | Vercel 发布会 Demo 体验收尾：Demo 模式跨平台生效且每次启动强制刷新数据；无用户时自动创建 `demo` 账号，清空旧数据后重新导入卡司排期汇总并自动加入排期流；Web 端隐藏「我的」页面设置入口及设置页内破坏性操作；管理台海报网格按剧目起止时间升序排列；剧目管理页状态选择自动同步排期流（想看/已买/已看加入排期流，未标记移出），返回管理台时自动刷新；表格角色列宽度加大减少截断；修复 `database_helper_web.dart` 缺失 `deleteAllShows`/`deleteAllPerformances` 导致 Web Release 构建失败的问题 | `lib/main.dart`, `lib/services/schedule_import_service.dart`, `lib/screens/profile_screen.dart`, `lib/screens/settings_page.dart`, `lib/screens/monthly_workbench_screen.dart`, `lib/screens/show_management_screen.dart`, `lib/widgets/show_table_editor.dart`, `lib/database/database_helper_web.dart` |
| 2026/06/20 | 场次级排期流改造：给 `Performance` 增加 `isInScheduleFlow` 字段，数据库升级到 v13；排期页/月历查询改为按场次 `is_in_schedule_flow` 过滤；管理台海报卡片支持 `待排期 0/Y场` / `排期中 X/Y场` 角标与起止月日；剧目管理页从全剧开关改为按场次加入/移出排期流，支持批量全部加入/移出；备份恢复兼容新字段；设置页重置入口同时重置 show 和 performance 的排期流状态 | `PRD.md`, `performance.dart`, `database_helper_io.dart`, `database_helper_web.dart`, `monthly_workbench_screen.dart`, `show_management_screen.dart`, `show_table_editor.dart`, `data_backup.dart`, `settings_page.dart` |
| 2026/06/20 | 配置 Vercel 在线预览部署：新增 `vercel.json`、GitHub Actions 工作流 `deploy-web.yml`、本地部署脚本 `deploy_vercel.ps1`/`deploy_vercel.sh`；生成 `paiqi.vercel.app` 二维码并放入 PPT 结尾页；新增 10 分钟演说脚本 `launch_script_offline.md` | `vercel.json`, `.github/workflows/deploy-web.yml`, `scripts/deploy_vercel.ps1`, `scripts/deploy_vercel.sh`, `presentation/presentation.md`, `presentation/launch_script_offline.md`, `presentation/README.md` |
| 2026/06/20 | 发现 `paiqi.vercel.app` 已被占用，改为使用 GitHub Pages 稳定地址 `https://giantpuppy.github.io/leeks-genius`：新增 `deploy-gh-pages.yml`、重新生成二维码、更新 PPT 与 README | `.github/workflows/deploy-gh-pages.yml`, `presentation/assets/qr_paiqi_preview.png`, `presentation/presentation.md`, `presentation/README.md` |
| 2026/06/20 | Web 演示模式：当 Web 端无登录用户时自动创建 `demo` 账号并导入卡司排期种子数据，确保线上预览扫码直接进入数据饱满的主界面；同步更新 Web 页面标题/描述/Manifest 品牌信息 | `lib/main.dart`, `web/index.html`, `web/manifest.json` |
| 2026/06/20 | 管理台海报卡片设计定稿：右上角合并为状态+场次角标（`待排期 0/5场` / `排期中 3/5场`）；左下角固定三行信息（剧名/剧院/起止月日 `7.3-7.5`），缺失字段留空保持占位；左上角无角标，不做长按多选；排期流中「删除」文案统一为「移出排期流」 | `PRD.md`, `monthly_workbench_screen.dart`（已合并到上方改造） |
| 2026/06/18 | 统一添加/管理剧目表格：提取 `ShowTableEditor` 与 `ShowHeaderEditor` 公共组件；`AddShowScreen` 复用公共组件保持原有录入体验；`ShowManagementScreen` 从卡片列表改为与添加页同一张表格，支持二次编辑日期、时间、角色、演员；顶部新增「保存」按钮统一事务保存；保留排期流开关、状态循环、票编辑、删除场次/剧目 | `show_table_editor.dart`, `show_header_editor.dart`, `add_show_screen.dart`, `show_management_screen.dart` |
| 2026/06/18 | 修复排期流 3天/7天 切换偶发红屏与月历折叠时黄黑警告频闪：在 `GanttScreen` 所有以行高做除数/乘法的位置增加 `rowHeight > 0` 防御；模式切换 postFrame 中检查 `_availableHeight` 与新旧行高；`LongPressStarButton` 状态变化时先 stop 动画再 reset；`_toggleWantToSee` 的 `firstWhere` 增加 `orElse`；`CalendarScreen` 周视图下 `rowHeight` 统一使用 `monthRowHeight` 并禁用 TableCalendar 格式动画，避免过渡帧 RenderFlex overflow | `gantt_screen.dart`, `calendar_screen.dart`, `long_press_star_button.dart` |
| 2026/06/18 | 解耦「排期流」与「月历」显示：加入排期流仅影响排期页；月历只展示排期流中状态为「想看/已买/已看」的场次，`unmarked` 场次不再出现在月历；同步更新 `ShowManagementScreen` 排期流状态卡片文案，不再提示会进入月历 | `calendar_screen.dart`, `show_management_screen.dart` |
| 2026/06/18 | 调整添加剧目入口位置：移除月历右上角 `+` 入口，改为在排期页管理台（工作台模式）右上角、与「时间线/管理台」切换按钮并排同大小放置；点击后进入 `AddShowScreen`，保存后仍进入 `ShowManagementScreen` 管理场次；管理台通过 `reloadSignal` 在返回后自动刷新，确保新添加剧目可见 | `gantt_screen.dart`, `monthly_workbench_screen.dart`, `calendar_screen.dart` |
| 2026/06/18 | 修复添加剧目核心流程漏洞：新建剧目保存后进入 `ShowManagementScreen`，但此前在剧目管理页内「添加/编辑/删除场次」或「切换场次状态」后会错误调用 `Navigator.pop` 直接返回月历；现统一改为仅刷新列表，保持在管理页内操作，确保用户可继续添加场次、加入排期流 | `show_management_screen.dart` |
| 2026/06/18 | 个人中心结构重新梳理：以「观看总场次」为顶层 Hero 指标；其下新增「观看剧目场次排序」横向条形图；演员排名与剧场分布改为 2 列网格展示；新增「金额统计」卡片展示实付/票面金额及省钱额；新增「状态统计」卡片展示已购买/已观演；时间切片控制器删除「本月」跳转入口；月度观演节奏、想看清单、即将观演、收藏占位保留；二级跳转交互预留，当前仅做展示 | `profile_screen.dart`, `profile_stats.dart`, `horizontal_bar_chart.dart` |
| 2026/06/18 | 统一添加与管理剧目流程：新建剧目保存后直接进入 `ShowManagementScreen`，使用同一界面继续管理场次和排期流状态 | `add_show_screen.dart`, `show_management_screen.dart` |
| 2026/06/18 | 剧目管理页排期流操作优化：将「加入/移出排期流」从头部小开关改为页面核心大卡片，保留完整场次信息的同时提升信噪比 | `show_management_screen.dart` |
| 2026/06/18 | 月历调整：恢复「全部」筛选下展示 `unmarked` 场次；移除月历单元格上的状态文字胶囊（已买/想看/已观演），仅保留状态色时间显示 | `calendar_screen.dart`, `calendar_poster_cell.dart` |
| 2026/06/18 | 排期数据漏斗重构：给 `Show` 增加 `isInScheduleFlow` 字段，数据库升级到 v12；新建/导入剧目默认进入管理台（`false`），排期流（`GanttScreen`）只查询已加入剧目的场次，月历/年历排除 `unmarked` 并只展示排期流中「想看/已买/已看」的场次；管理台海报卡片增加排期流状态徽标、长按导入/移出 Bottom Sheet；剧目管理页增加排期流状态开关；备份恢复保留该字段；设置页新增「重置所有剧目到管理台」入口；修复管理台左右滑动时年月标题不同步的问题 | `show.dart`, `database_helper_io.dart`, `database_helper_web.dart`, `monthly_workbench_screen.dart`, `show_management_screen.dart`, `gantt_screen.dart`, `calendar_screen.dart`, `year_calendar_screen.dart`, `schedule_import_service.dart`, `add_show_screen.dart`, `import_schedule_screen.dart`, `data_backup.dart`, `settings_page.dart` |
| 2026/06/18 | 排期页工作台月份选择交互闭环：嵌入 `MonthlyWorkbenchScreen` 左右滑动切换月份时通过 `onMonthChanged` 回调同步更新 `GanttScreen` 左上角年月标题；点击左上角年月弹出双滚轮（年/月）底部弹窗选择器，替代系统 `showDatePicker` | `gantt_screen.dart`, `monthly_workbench_screen.dart` |
| 2026/06/18 | 补充卡司排期汇总表数据并支持自动导入：新增 `ScheduleImportService`，启动时按当前用户名检测并自动写入数据库；保留设置页手动入口与 `ImportScheduleScreen`；解析脚本生成 `lib/data/schedule_import_bundle.dart` | `tools/parse_schedule_import.py`, `lib/services/schedule_import_service.dart`, `lib/data/schedule_import_bundle.dart`, `lib/screens/import_schedule_screen.dart`, `lib/screens/settings_page.dart`, `lib/main.dart` |
| 2026/06/18 | 设置页收纳管理入口：「我的剧目」「月度管理」「演员名单」从个人中心迁移至设置页；保留新增剧目、跳转剧目管理、删除剧目及删除演员能力；个人中心移除「管理」区块及「设置」tile，设置仅通过顶部头像/用户名区域进入 | `settings_page.dart`, `profile_screen.dart` |
| 2026/06/18 | 排期页嵌入工作台移除独立月份选择器：`MonthlyWorkbenchScreen.embedded` 模式下不再显示 `_buildMonthSelector`，复用排期页左上角年月选择，避免重复控件 | `monthly_workbench_screen.dart` |
| 2026/06/17 | Phase 2 核心流程补全：新建 `BoughtFormSheet` 底部表单，统一详情页、排期板、管理台「标记已买」的录入体验；跳过则只改状态，保存则写入 `tickets`；移除 Gantt 中写入 performances 旧字段的废弃表单 | `bought_form_sheet.dart`, `gantt_screen.dart`, `unified_show_detail_screen.dart`, `show_management_screen.dart` |
| 2026/06/17 | 设置页返回按钮：SettingsPage AppBar 增加返回箭头 | `settings_page.dart` |
| 2026/06/17 | 管理台入口优化：排期板右上角管理按钮从纯图标改为「管理台」文字按钮；ProfileScreen 管理区新增「月度管理」入口，直接打开当月海报墙 | `gantt_screen.dart`, `profile_screen.dart` |
| 2026/06/17 | 备份恢复包含海报图片：DataBackupCore 导出时读取 `cover_path` 图片并嵌入 `cover_image_base64`；导入时解码写回磁盘并更新 `cover_path`；备份版本号升级到 3 | `data_backup.dart`, `cover_helper.dart` |
| 2026/06/17 | Phase 1 数据层统一：数据库升级到 v11，迁移 performances 残留 seat/price/actual_price 到 tickets，并把已买且日期已过的场次持久化为 watched；新增 `getPerformanceWithTicket` / `getPerformancesWithTicketsByShowId` / `getPerformancesWithTicketsByDate` 等 JOIN 查询；`ShowManagementScreen` 改读写 tickets；`AddShowScreen` 保存时创建 Ticket；`replaceAllPerformances` 重建场次时保留原有 ticket；`Performance` 模型 seat/price/actualPrice 加 `@Deprecated` | `database_helper_io.dart`, `database_helper_web.dart`, `show_management_screen.dart`, `add_show_screen.dart`, `performance.dart` |
| 2026/06/17 | 已观演状态持久化：详情页状态循环扩展为 unmarked→想看→已买→已观演→未标记；排期板、月历筛选、ProfileStats 优先判断持久 `status == 'watched'`，旧数据按日期回退 | `unified_show_detail_screen.dart`, `gantt_screen.dart`, `calendar_screen.dart`, `profile_stats.dart`, `profile_screen.dart` |
| 2026/06/17 | 月历默认筛选改为「全部」：字段默认值已改，但 `initState` 中仍回退到 `bought`，导致新添加剧目找不到。已同步修复 `initState` 回退值为 `CalendarFilter.all`，并确保 `_shouldInclude` 在「全部」下包含未标记演出 | `calendar_screen.dart` |
| 2026/06/17 | 修复月历票根列表加载卡住：选中日期后底部票根区一直转圈显示「0 场」，原因是 sqflite `rawQuery` 返回的 Map 可能是不可变的，直接写入 `ticket_seat` 会抛异常，导致 `_isLoading` 无法复位。改为复制 Map 后再写入，并加 `try/catch/finally` 保证加载状态一定关闭 | `calendar_screen.dart` |
| 2026/06/17 | 排期板第二次实机精调：tab 去文字仅保留 icon；点击当前 tab 强制重建使 icon 随 3天/7天 模式更新；今日恢复淡紫色光效；去掉农历；放大星期；日期改为 M.D 格式；周末右侧内容区加淡灰横条标注 | `gantt_screen.dart`, `main_screen.dart` |
| 2026/06/17 | 排期板实机反馈修复：恢复实体 Header、年月标题左对齐；底部 tab 切换改为 `BottomNavigationBar` 以支持点击当前 tab 切换 3天/7天 模式；模式切换时以屏幕中心日期为锚点重新居中；新增屏幕中心日期淡紫色底部高光作为焦点提示 | `gantt_screen.dart`, `main_screen.dart` |
| 2026/06/17 | 排期板视觉打磨（第一阶段）：Header 改为剧场节目单风格（居中标题 + 渐变装饰线），标题点击弹出月份选择器；管理台入口改为安静光点风格；今日行/卡片改用暖金色 WarmSpotlight 呼吸光效、脚灯条与侧边光；空日期背景暗化并删除「无排期」文字，叠加天鹅绒纹理；海报蒙版降低、卡片光晕/溢光/底部投影增强、描边改为深色；时间改为无 emoji 邮票风格；聚焦模式卡司只显示主演前 3 条且角色/演员对比度拉开；剧名常驻卡片底部；微观模式新增状态色圆点；日期标签增加农历、字号全比例化 | `gantt_screen.dart`, `lib/widgets/gantt/cast_list.dart`, `lib/widgets/gantt/gantt_decorations.dart` |
| 2026/06/17 | 排期页交互最终调整：左上角月份标题移除点击跳转管理台功能（仅作标题展示）；右上角保留直接跳转管理台入口。底部「排期」tab 图标改为自定义 `ScheduleTabIcon`：3天聚焦模式显示 3 条横线，7天宏观模式显示 7 条横线，带 200ms 淡入缩放动画；模式切换继续由该 tab 在「已在排期页」时承担 | `gantt_screen.dart`, `main_screen.dart`, `schedule_tab_icon.dart` |
| 2026/06/17 | 排期页交互调整：右上角紫色按钮从底部 sheet 改为直接跳转 `MonthlyWorkbenchScreen` 管理台；清理失效的 `_showManagementMenu`/`_showAddMenu`/`_pickImageAndRecognize` 及对应 OCR 导入；空状态提示更新。底部「排期」tab 图标改为根据当前 3天/7天模式动态显示 `view_column`/`view_week`，并带 200ms 淡入缩放切换动画；已在排期页时点击该 tab 调用 `GanttScreenState.toggleMode()` 切换模式，从其他 tab 首次点击仅导航到排期页 | `gantt_screen.dart`, `main_screen.dart` |
| 2026/06/17 | 月历首页阶段三：与排期板视觉统一——today 单元格/无演出 today 单元格加 `WarmSpotlight` 紫色追光；海报单元格加顶部渐变蒙层、1px 白边、紫色 today 角标；选中态/周视图显示迷你 `StatusBadge`；票根卡片加 `coverColorForShow` 环境光晕。个人中心数据联动——`CalendarScreen` 新增 `initialFilter`/`initialFocusedDay`；Hero 指标卡片（已观演/已购买/关注剧目/已买场次）点击跳转对应过滤月历；月度柱状图 bar 点击跳转对应月份 | `calendar_poster_cell.dart`, `calendar_cell.dart`, `calendar_screen.dart`, `profile_screen.dart`, `simple_bar_chart.dart` |
| 2026/06/16 | 排期管理台重构：海报网格画廊、年月选择器（箭头+picker+滑动）、新建剧目管理页、长按不实现 | `monthly_workbench_screen.dart`, `show_management_screen.dart`, `status_colors.dart` |
| 2026/06/15 | 月历首页反馈优化：月历容器高度精确为 6 行 + 分割线/手柄区余量；分割线上提至第六排下方并进一步调紧余量，月历底部叠加渐变遮罩、分割线下方增加向下渐变过渡，形成柔和预览感；月视图下 `CustomScrollView` 禁用滚动并只显示单张票根预览，上滑切换为周视图后下方票根列表可滚动；`_onHeaderHorizontalSwipe` 区分月/周视图，月视图切换月份、周视图切换周目；新增 `_changeWeek` 处理跨月事件加载与选中日期跟随；TableCalendar 格式动画从 1ms 调至 120ms，垂直切换阈值从 150 降至 100 | `calendar_screen.dart` |
| 2026/06/15 | Tab 栏半透明毛玻璃背景，选中 icon 紫色发光高亮（无灰色药丸蒙版）；海报 cell 恢复层叠小卡，日期数字贴左上角，开场时间居中显示，右下角显示总张数，选中态移除剧名+剧场名浮层；删除 `poster_grid.dart` | `main_screen.dart`, `main.dart`, `calendar_poster_cell.dart` |
| 2026/06/15 | 海报单元格视觉重设计：去掉日期/时间黑底胶囊；日期改为白字+细阴影压在左上角；开场时间移到底部黑色渐变条；张数角标改为半透明白边小胶囊；新增同天二次点击循环轮换层叠海报交互，切换时顶层海报淡入淡出、底部时间同步更新；底部 Tab 栏点击水波纹去除 | `calendar_poster_cell.dart`, `calendar_cell.dart`, `calendar_screen.dart`, `main_screen.dart` |
| 2026/06/15 | 层叠小卡尺寸统一：顶层海报占满整个单元格，与单日海报视觉大小一致；后续卡片仅在右侧露出窄边作为阴影层次，不再挤压顶层尺寸 | `calendar_poster_cell.dart` |
| 2026/06/16 | 层叠小卡改为微信式立体堆叠：顶层海报向左上偏移缩小，底层/中间层从右侧和底侧露出边缘；去掉右下角张数数字角标，用层叠层数暗示多场演出 | `calendar_poster_cell.dart` |
| 2026/06/16 | 海报单元格按比例重设计：使用 `LayoutBuilder` 基于单元格尺寸计算所有边距/高度/偏移/字号；删除海报上的日期数字；海报堆叠区与单元格外框之间留出呼吸空隙；开场时间移到海报下方深灰色半透明蒙版上；层叠小卡改为阶梯式垂直错位，顶层完整、下层依次向下偏移并从底部露出 | `calendar_poster_cell.dart` |
| 2026/06/16 | 海报单元格细节调整：去掉顶层海报状态色边框；时间条文字和背景增加状态色光效；多张海报时在右上角添加四分之一圆角（只有右上角圆角）数量角标，白色数字 | `calendar_poster_cell.dart` |
| 2026/06/16 | 数量角标改为右上+左下双圆角，数字居中；修复周视图下点击日期时 `_focusedDay` 跟随变化导致页面自动左右滑动的问题，周视图点击仅更新 `_selectedDay` | `calendar_poster_cell.dart`, `calendar_screen.dart` |
| 2026/06/16 | 修复周视图（锁定一行状态）下点击日期仍会展开为月视图的问题：删除 `_onDaySelected` 中周视图点击触发 `_expandCalendar()` 的逻辑；票根卡片信息布局调整：日期放在顶部，座位紧跟日期下一行，剧名与剧院放在卡片底部 | `calendar_screen.dart` |
| 2026/06/15 | 月历首页阶段二打磨（第五版）：拆分 `calendar_screen.dart` 为 `calendar_cell.dart` / `calendar_poster_cell.dart` / `poster_grid.dart`；多场海报从层叠改为均分网格（2场 1×2 / 3场 1×3 / 4场 2×2 / 5+场 2×2 + `+N`）；有演出格子左上角增加开场时间胶囊；选中态海报底部渐变浮现剧名+剧场名；选中态外发光改为双层阴影、统一圆角为 6、弱化蒙层；选中日期触发 `HapticFeedback.lightImpact()`；新增 `status_colors.dart` 统一状态色/图标 | `calendar_screen.dart`, `calendar_cell.dart`, `calendar_poster_cell.dart`, `poster_grid.dart`, `status_colors.dart` |
| 2026/06/15 | 月历首页打磨迭代（第四版）：无事件日期格子文字数字垂直居中；今天高亮简化为仅文字/数字高亮，选中态框线弱化晕开与海报比例一致；选中有剧目日期时，底部 tab 导航上方新增提醒光感分隔符；`MainScreen` 通过回调监听 `CalendarScreen` 选中日期事件状态 | `calendar_screen.dart`, `main_screen.dart` |
| 2026/06/15 | 月历首页打磨迭代（第三版）：海报单元格改为 cover 填充单元格而非固定 3:4 容器；月历高度调整为屏幕 58% 留出票根列表；禁用 TableCalendar 内部水平滑动避免上滑时左右晃动；增强光感分割线；无事件单元格自适应字体避免溢出 | `calendar_screen.dart` |
| 2026/06/15 | 月历首页打磨迭代：CustomScrollView + SliverAppBar 固定头部 + 星期标题 SliverPersistentHeader；筛选器改回右上角下拉按钮；月视图满屏铺满；票根卡片高度统一；单周/双周显示跨月日期；上滑折叠为聚焦行（月/单周 1 行，双周 2 行） | `calendar_screen.dart` |
| 2026/06/15 | Phase 2 月历首页 MVP 实现：今日追光呼吸动画、AppBar"今天"按钮、月份切换触觉反馈、筛选器改内联 Chips、票根卡片高度自适应、无海报渐变占位、周视图剧名+时间、海报单元格隐藏冗余状态点 | `calendar_screen.dart`, `today_spotlight.dart` |
| 2026/06/14 | 总体实施路线图确认：Phase 1 基础组件 → Phase 2 月历首页 MVP → Phase 3 月历进阶 → Phase 4 个人中心 → Phase 5 排期板 → Phase 6 详情页 → Phase 7 收尾验证 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 详情页打磨方向确认：保持混合编辑、支持海报更换、星星+文字状态标签、卡司只读+主演标记、先做文字备注、票根统一齿孔风格 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 个人中心细节确认：时间切片默认全部、想看清单单独展示、收藏入口预留、MVP 图表为月度柱状图+演员排名条形图、设置双入口、左滑删除 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 月历首页细节确认：未标记不显示海报、日期数字左上角圆标、多场海报均分网格、周视图显示剧名时间、筛选器改分段按钮/Chips | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 可视化图表设计规范确认：CustomPainter 自定义绘制、发光剧场感、纯展示不下钻、个人中心四张图表（月度柱状/演员排名/剧场分布/时段环形）、数据不足隐藏 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 个人中心重构设计 render 方案确认：数据仪表盘布局、Hero 指标卡片、月度柱状图、演员/剧场排名、时段环形图、时间切片切换、暗黑风光效 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/14 | 月历首页设计方案确认：月历全景模式、单元格海报堆叠、状态色边框（已买绿/想看紫/已看金）、今日追光、回到今天 FAB、月份快切、轻量 Repository/ViewModel 解耦 | `PRD.md`, `plans/radiant-booping-clover.md` |
| 2026/06/10 | 设计哲学确立："黑暗中的光"三层哲学（空间/时间/情绪） | PRD.md |
| 2026/06/10 | 排期板设计方案：灯光秀概念、光的层次、交互优化、信息密度、全比例布局 | PRD.md |
| 2026/06/10 | 详情页重构方案：展示+编辑分离、待办清单、海报作为视觉标识 | PRD.md |
| 2026/06/10 | 管理台重构方案：海报网格画廊、月份筛选、点击进入管理 | PRD.md |
| 2026/06/10 | Header整合：管理台入口替代+按钮，砍掉密度切换按钮 | PRD.md |
| 2026/06/04 | 个人中心画廊墙：总场次、总花费、票面价、省钱额、追踪剧目数、Top3 演员 | `profile_screen.dart` |
| 2026/06/04 | 设置页拆分：OCR 配置、备份恢复、退出登录独立为 `SettingsPage` | `settings_page.dart`, `profile_screen.dart` |
| 2026/06/04 | 修复 AddShowScreen 表头 Row 溢出 0.5px（像素舍入 + border 宽度） | `add_show_screen.dart` |
| 2026/06/04 | 修复演员角色单元格垂直对齐（isCollapsed + contentPadding） | `add_show_screen.dart` |
| 2026/06/04 | 待规划：个人中心+设置页合并为单一页面 | `profile_screen.dart`, `settings_page.dart` |
| 2026/06/03 | 月度管理工作台：按月聚合剧目卡片、场次列表、点击进入编辑，保存后自动刷新 | `monthly_workbench_screen.dart`, `database_helper_io.dart` |
| 2026/06/03 | 甘特图模式切换修复：ValueKey 强制重建 + _justSwitched 防干扰 + postFrame 重算行高，左上角月份实时跟随滚动 | `gantt_screen.dart` |
| 2026/06/02 | 排期页重构为"剧场流时间轴"：双指缩放切换 3天/7天视图、海报卡片、Sticky Header、+号分流弹窗 | `gantt_screen.dart` |
| 2026/06/02 | AddShowScreen 重构：支持手动/OCR/编辑三模式、3:4海报封面、暗黑CupertinoDatePicker、事务级保存 | `add_show_screen.dart` |
| 2026/06/02 | 数据库升级 v7：shows 表新增 cover_path 字段、replaceAllPerformances 事务方法、JOIN查询补充 cover_path | `database_helper_io.dart`, `database_helper_web.dart`, `show.dart` |
| 2026/06/02 | 新增海报工具类：图片持久化到 documents/covers/、非法字符过滤、编辑改名联动 | `utils/cover_helper.dart` |
| 2026/06/01 | 根治年历溢出：Table + 压缩内部尺寸 + 增大卡片高度 (0.78→0.70) | `year_calendar_screen.dart` |
| 2026/06/01 | 年历日期网格改用 Table 组件 | `year_calendar_screen.dart` |
| 2026/06/01 | 年历视图 redesign：3×4 网格、全年数据加载、状态色块（金/绿/紫）、数量标注 | `year_calendar_screen.dart` |
| 2026/06/01 | 日历页/排期页 UI 重构完成 | `calendar_screen.dart`, `gantt_screen.dart`, `year_calendar_screen.dart` |
| 2026/06/01 | 年历改为全屏页面（替代 BottomSheet），修复迷你日历溢出，增加已观演标记 | `year_calendar_screen.dart` |
| 2026/06/01 | 排期页：增大左侧剧目栏占位、放大右上角加号、左侧整行可点击 | `gantt_screen.dart` |
| 2026/06/01 | 初版 PRD 建立，梳理项目整体架构与 Roadmap | `PRD.md` |
| 2026/05/28 | 去掉 OCR 自动保存演员，改为 sheet 手动添加新演员 | `lib/screens/add_show_screen.dart` |
| 2026/05/28 | 修复甘特图日视图窄格子内 Row 溢出 | `lib/screens/gantt_screen.dart` |
| 2026/05/27 | OCR 识别 + 演员选择 + 用户系统 + 数据备份 完成 | 多文件 |
| 2026/05/24 | 甘特图周视图 + 表格输入 + 测试数据 | 多文件 |
| 2026/05/21 | 初始提交 | 项目初始化 |

---

## 1. 产品概述

### 1.1 Slogan

**排期的事，交给排期天菜。**

### 1.2 产品定位

排期天菜是一款专为中国音乐剧观众打造的排期管理 App。

市面上的看剧记录工具都是"看完再记"——买完票才想起来要记录。本产品则从**关注一部剧的那一刻起**就把场次信息纳入排期计划。想看的场次一键标记，已买的票根自动归档，看完的数据自动沉淀。从"关注"到"复盘"，全流程一个 App 搞定。

### 1.3 目标用户

这款 App 面向的是一个月需要关注几十场剧的中国音乐剧观众。

她们同时追好几部戏，关注同一部剧不同日期的演员卡司组合，需要横向对比同一周有哪些剧可看、纵向追踪一部剧从官宣到开票到演出的全周期。

根据中国演出行业协会《2025 年全国演出市场简报》，2025 年全国音乐剧演出 **1.97 万场**，同比增长 **15.04%**；票房收入 **18.07 亿元**，同比增长 **7.55%**；观众人数 **818.59 万人次**，同比增长 **10.41%**。

女性占比高达 **75.5%**，核心年龄层 18-35 岁，一二线城市为主力。音乐剧人均消费约 **221 元**，是电影的 **5 倍**，复购意愿强。跨城观演比例可达 **30% 以上**。

### 1.4 核心痛点：只管记，不管排

一个剧女从"知道一部剧要演了"到"最终买票进场"，中间要经历：关注宣发 → 等排期 → 等演员卡司 → 盘同一周有哪些剧 → 对比演员卡司和时间 → 决定买哪场 → 等开票 → 抢票。

中国音乐剧市场有几个特殊规则让"排"变得更痛：
- **开票时演员卡司没出全**，不敢买但好位置不等人
- **票不能退，出票很难**，买错了只能自己在二手平台降价转手
- **主办方临近打折**，买早怕被背刺买晚怕买不到
- **排期信息散落五六个平台**，每次决策都要手动拼凑

但市面上的工具——售票类的大麦、猫眼聚焦在购票环节，记录类的记录现场、剧在聚焦在看完之后的记录——**没有一个覆盖从"关注"到"排"的前半段路径**。

### 1.5 解决方案：排 · 记 · 存

- **排**——解决"买哪场"的问题。可视化排期流横向纵向对比演员卡司和时间，想看的场次一键 mark，自动同步到月历总览
- **记**——解决"买了什么"的问题。已购票场次集中管理，票根、座位、待办事项一场场列清楚
- **存**——解决"看了多少"的问题。数据自动沉淀，月底年底自动生成可视化图表和看剧报告

### 1.6 产品理念

看剧的快乐不该被排期吃掉。减轻排期的负担，让精力花在值得沉淀的事情上。

### 1.7 竞品差异

| 维度 | 售票类（大麦/猫眼） | 记录类（记录现场/剧在） | 排期天菜 |
|------|-------------------|----------------------|---------|
| **覆盖阶段** | 购票环节 | 看完之后的记录 | 关注 → 排期 → 决策 → 购买 → 记录 → 复盘 |
| **排期能力** | 无 | 无 | 可视化排期流、演员卡司对比、全周期追踪 |
| **视觉** | 标准电商 | 白底+文字列表 | 剧场暗黑风，沉浸感 |
| **核心价值** | 买票 | 记录 | **排期决策** |

### 1.5 设计哲学：黑暗中的光

> 灵感来源：摄影明暗创作 + 戏剧灯光舞美设计。黑暗不是缺失，是设计的一部分。

| 维度 | 理念 | 映射 |
|------|------|------|
| 空间感 | 暗是距离，光是亲近 | 深色背景=观众席，高亮卡片=舞台演员 |
| 时间感 | 暗是等待，亮是发生 | 打开应用先给焦点，滑动有明暗节奏 |
| 情绪感 | 暗是剧场感的来源 | 深色+暖光=剧场入场前的氛围 |

**设计原则：**
- 暗是主体，光是焦点：页面80%深色，20%高亮
- 暗创造节奏：信息密集区 → 留白呼吸区 → 信息密集区
- 光引导视线：最重要信息用最亮颜色/最大对比度
- 减法优先：不是"还能加什么"，而是"还能去掉什么"

---

## 2. 功能架构

```
排期天菜
├── 🔐 用户系统
│   ├── 注册/登录（本地账号，SHA256+盐）
│   ├── 多用户隔离（每用户独立数据库）
│   └── 跳过登录（default 游客模式）
│
├── 📅 日历视图
│   ├── 月/双周/周 三种格式（手势切换）
│   ├── 农历显示
│   ├── 年历弹窗（12 月迷你日历快速跳转）
│   ├── 事件标记（想看=紫 / 已买=绿 / 今日=红）
│   ├── 状态筛选（全部/想看/已买）
│   └── 当日演出列表
│
├── 📊 排期视图（甘特图）
│   ├── 周视图横向时间轴
│   ├── 左侧剧目栏（彩色竖条标识）
│   ├── 多层堆叠（同日多场纵向排列）
│   ├── 今天指示线
│   ├── 手势翻页（左右滑动切换周）
│   ├── 点击场次循环切换状态
│   └── 点击剧目弹出管理面板
│
├── 🎭 剧目管理
│   ├── 添加剧目（表格录入：场次×角色）
│   ├── OCR 智能识别（排期表 / 卡司表）
│   ├── 演员选择器（搜索 + 手动新增）
│   ├── 单场详情（时间/座位/票价/卡司）
│   └── 剧目模板（角色列表复用）
│
├── 🤖 OCR 系统
│   ├── 双引擎识别
│   │   ├── 移动端：Google ML Kit（本地）
│   │   ├── Web 端：Tesseract.js（本地）
│   │   └── 云端：百度 OCR API（可选）
│   ├── 格式解析
│   │   ├── 排期表格式（日期+多角色）
│   │   └── 卡司表格式（角色-演员对应）
│   ├── 知识库纠错（越用越准）
│   │   ├── 精确匹配历史纠错映射
│   │   ├── 模糊匹配模板角色
│   │   └── 模糊匹配演员库
│   └── 演员手动入库（用户确认后保存）
│
├── 👤 个人中心
│   ├── 统计卡片（想看/已买/即将演出）
│   ├── 剧目总览（管理/筛选/调整）
│   ├── 演员名单管理
│   ├── OCR API 配置
│   └── 数据备份/恢复（JSON）
│
└── 🎨 设计系统
    ├── Spotify Dark 暗黑主题
    ├── Material 3 组件
    └── 剧院场景低光优化
```

---

## 3. 技术架构

### 3.1 技术栈

| 层级 | 技术选择 | 说明 |
|------|---------|------|
| **框架** | Flutter 3.x | 一套代码跨 Android / iOS / Web / Windows |
| **语言** | Dart >=3.0.0 | 空安全、异步友好 |
| **UI** | Material 3 + 自定义主题 | Spotify Dark 沉浸式 |
| **移动端数据库** | sqflite (SQLite) | 文件级存储，多用户隔离 |
| **Web 端数据库** | sembast + localStorage | 内存数据库，JSON 持久化 |
| **本地配置** | shared_preferences | 用户列表、OCR Key、当前用户 |
| **日历** | table_calendar | 月/双周/周三视图 |
| **农历** | lunar | 农历计算 |
| **OCR 移动端** | google_mlkit_text_recognition | Google ML Kit 本地识别 |
| **OCR Web** | Tesseract.js (JS Interop) | 浏览器本地识别 |
| **OCR 云端** | 百度通用文字识别 API | HTTP 调用，需配置 Key |
| **图表** | fl_chart | 预留，待用于统计页 |
| **图片选择** | image_picker | 相册/拍照 |
| **文件操作** | file_picker / share_plus | 备份导入导出 |
| **加密** | crypto (SHA-256) | 密码哈希 |

### 3.2 数据库 Schema

```sql
-- 剧目
shows (id, name, theater, created_at)

-- 场次
performances (
  id, show_id, date, time,
  seat, price, actual_price,
  status (unmarked/want_to_see/bought),
  created_at
)

-- 卡司
cast_members (
  id, performance_id,
  role, actor_name,
  is_featured,
  created_at
)

-- 演员库
actors (id, name UNIQUE, note, created_at)

-- OCR 纠错映射
ocr_corrections (
  id, ocr_text, corrected_text,
  category (actor/role/show),
  use_count
)

-- 剧目模板
show_templates (
  id, name UNIQUE, theater,
  roles (JSON), performance_count
)
```

### 3.3 状态管理

- **方案**：纯 Flutter 原生 `setState`（无 Riverpod/Bloc/GetX）
- **数据流**：`initState` → `_loadData()` → 数据库查询 → `setState` 刷新
- **全局访问**：`DatabaseHelper.instance` 单例，所有页面直接 CRUD
- **适用性评估**：当前规模下足够直观，若页面超过 15 个或需要深层数据共享时，建议迁移至 Riverpod

---

## 4. 页面流程

```
[启动]
   │
   ├── 无用户 / 未登录 ──→ [登录页]
   │                        ├── 选择已有用户登录
   │                        ├── 注册新用户
   │                        └── 跳过（default 游客）
   │
   └── 已登录 ───────────→ [主框架: 底部导航]
                              │
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                 ▼
      [日历页]            [排期页]           [我的]
            │                 │                 │
            ├── 年历弹窗      ├── 切换周        ├── 统计卡片
            ├── 切换月/双周/周 ├── 点击场次详情   ├── 剧目管理
            ├── 点击日期      ├── 点击剧目管理   ├── 演员管理
            └── 演出列表      └── 添加剧目      ├── OCR 设置
                                                └── 备份/恢复
                                                      │
                                                [添加剧目页]
                                                      │
                                                ├── 表格录入
                                                ├── OCR 识别
                                                └── 演员选择
```

---

## 5. 核心功能详解

### 5.1 OCR 智能识别

**流程**：
1. 用户拍照/选图
2. `recognizeTextAuto()` 判断引擎：
   - 配置了百度 Key → 调用百度 OCR API
   - 未配置 → 本地识别（ML Kit / Tesseract）
3. 文本解析：
   - `isScheduleFormat()` 判断格式
   - `parseSchedule()` 解析排期表 或 `parseCastText()` 解析卡司表
4. 知识库纠错：`correctOcrResult()` 逐字段纠错
5. 填充表单，用户确认
6. 保存时：模板入库、演员需手动确认后入库、纠错映射入库

### 5.2 知识库自学习

| 优先级 | 匹配源 | 相似度阈值 | 用途 |
|-------|-------|-----------|------|
| 1 | `ocr_corrections` 精确匹配 | 100% | 历史纠正映射 |
| 2 | `ocr_corrections` 模糊匹配 | >= 0.6 | 相似纠错复用 |
| 3 | `show_templates.roles` 模糊匹配 | >= 0.6 | 角色名纠正 |
| 4 | `actors.name` 模糊匹配 | >= 0.6 | 演员名纠正 |

**模糊算法**：Levenshtein 编辑距离 + 前缀/后缀匹配 bonus + 长度差异惩罚

### 5.3 排期板（剧场流时间轴）

**核心概念：** 排期板本身就是一场灯光秀

**双视图模式：**
| 模式 | 一屏 | 卡片布局 | 核心 |
|------|------|---------|------|
| 放大聚焦 | 3天 | 3行×2列=6张 | 海报卡片，时间胶囊+渐变蒙层+卡司列表 |
| 缩小微观 | 7天 | 7行×5列=35张 | 海报邮票墙，时间戳居中叠加 |

**视觉：光的层次**
- 今天最亮：蒙版透明度降低，暖色光晕
- 远离今天更暗：蒙版更重
- 滑动时今天始终是最亮的锚点

**交互：**
- 双指缩放切换3天/7天模式
- 磁吸滚动有弹性曲线
- 横向滑动两种模式都加吸附效果
- 侧光效果：被裁掉的卡片方向有微弱光晕

**Header：剧场节目单风格**
- 月份标题居中，稍大字号，两侧加装饰线
- 右上角合并为一个"管理台"入口
- 月份标题只保留跳转月份功能

**布局原则：** 全比例，不写死px

### 5.4 演出详情页

**页面定位：** 展示为主、编辑为辅

| 区域 | 可编辑？ | 说明 |
|------|---------|------|
| 剧目标识区 | ❌ | 海报缩略图+剧名+剧场（海报是视觉标识） |
| 场次信息 | ❌ | 日期、时间，只读 |
| 卡司 | ❌ | 角色+演员，只读 |
| 票根 | ✅ | 可添加/删除票根 |
| 待办清单 | ✅ | 可添加/勾选/删除待办项 |

右上角星星：未标记→想看→已买，是唯一的状态入口。

**设计约束：**
- 区块间不用实线分割，用间距+光晕分隔
- 文字层级：一级(剧名)→二级(剧场/时间)→三级(卡司角色)→四级(辅助)
- 可编辑区域右上角有小的添加按钮（暖色光点风格）

### 5.5 管理台

**核心概念：** 海报即入口——满屏海报铺开，视觉冲击；管理台是剧目/场次全量资料库，与排期流互相独立又可双向流转。

**布局：**
- 2列网格，海报3:4比例
- 卡片叠加信息层，文字直接压在海报上
- Header年月选择器（◀ 2026年6月 ▶）

**海报卡片信息结构：**

```
┌─────────────────────────┐
│                         │
│          海报            │
│                         │
│              排期中 3/5场 │
│                         │
│  女巫                    │
│  上海大剧院              │
│  7.23-8.2               │
└─────────────────────────┘
```

- **右上角**：状态 + 已排期场次/总场次
  - 待排期：`待排期 0/5场`
  - 排期中：`排期中 3/5场`
- **左下角**：固定三行，缺失字段留白占位，不挤占其他行
  - 第一行：剧目名称（必显）
  - 第二行：剧院（无则留空）
  - 第三行：起止月日，如 `7.3-7.5`、`7.23-8.2`（无则留空）
- **左上角**：无角标

**交互：**
- 点击海报 → 进入场次管理/编辑页
- +直接跳转添加页
- 左右滑动页面切换月份
- 排期流中的「删除」操作文案统一为「移出排期流」，操作后场次回到管理台，不真正删除

**数据流转：**
1. 导入/OCR/手动添加的剧目和场次，默认全部进入管理台，状态为「待排期」
2. 用户在管理台中挑选场次「加入排期流」，进入排期流/日历视图
3. 在排期流中「移出排期流」的场次，回到管理台，可再次加入排期流
4. 管理台中的「删除」才是真正从数据库移除

**空状态：** 中央微弱光圈 + "这个月还没有排期"

---

## 6. 数据模型

```dart
// 剧目
class Show {
  final int? id;
  final String name;      // 剧目名
  final String theater;   // 剧场
  final String createdAt;
}

// 场次
class Performance {
  final int? id;
  final int showId;
  final String date;      // YYYY-MM-DD
  final String time;      // HH:MM
  final String seat;      // 座位号
  final double? price;    // 票面价
  final double? actualPrice; // 实付价
  final String status;    // unmarked / want_to_see / bought
}

// 卡司
class CastMember {
  final int? id;
  final int performanceId;
  final String role;      // 角色名
  final String actorName; // 演员名
  final bool isFeatured;  // 是否重点标注（甘特图优先显示）
}

// 演员
class Actor {
  final int? id;
  final String name;
  final String? note;
}
```

---

## 7. 设计规范

详见 `DESIGN.md`，核心要点：

| 元素 | 规范 |
|------|------|
| **背景层级** | Canvas `#121212` → Surface-1 `#181818` → Surface-2 `#1F1F1F` |
| **品牌色** | `#6B5BCD`（紫） |
| **想看** | `#811FE2` |
| **已买** | `#34D399` |
| **今日** | `#F54A45` |
| **按钮** | 胶囊形 `StadiumBorder` |
| **卡片** | 8px 圆角，无阴影，hover 变亮 |
| **字体** | NotoSansSC |

---

## 8. 当前开发状态

| 模块 | 状态 | 备注 |
|------|------|------|
| 用户系统 | ✅ 完成 | 注册/登录/多用户隔离 |
| 日历视图 | ✅ 完成 | 农历、年历、筛选 |
| 排期甘特图 | ✅ 完成 | 周视图、手势、今天线 |
| OCR 识别 | ✅ 完成 | 双引擎 + 排期/卡司解析 |
| 知识库纠错 | ✅ 完成 | 四级纠错 + 模糊匹配 |
| 演员手动入库 | ✅ 完成 | 2026-05-28 完成 |
| 数据备份 | ✅ 完成 | JSON 导入/导出 |
| 日视图溢出修复 | ✅ 完成 | 窄格子 Row 溢出 |
| **年历视图** | ✅ 完成 | 全屏页面、3×4 Table 网格、全年数据、状态色块（金/绿/紫）、数量标注、透明占位、无溢出 |
| **排期页 UI 优化** | ✅ 完成 | 左侧占位增大、加号放大、整行可点击 |
| **甘特图模式切换** | ✅ 完成 | 3日/7日 双模式、ValueKey 强制重建防缓存、月份实时跟随滚动 |
| **月度管理工作台** | ✅ 完成 | 按月聚合剧目卡片、场次列表、点击进入全量编辑、保存自动刷新 |
| 日历页滑动切换 | ✅ 完成 | 全屏上下滑动切换月/双周/周、胶囊形分割条手柄 |
| **日历页UI打磨** | ✅ 完成 | 已看筛选(金色)、非本月日期隐藏、rowHeight64更舒展、星期标题缩写、header精简无箭头无格式按钮、已看图标(visibility) |
| **个人中心画廊墙** | ✅ 完成 | 总场次/总花费/票面价/省钱额/追踪剧目数/Top3演员 |
| **设置页拆分** | ✅ 完成 | OCR配置、备份恢复、退出登录独立页面 |
| **AddShowScreen 溢出修复** | ✅ 完成 | 表头 Row 0.5px 像素舍入溢出修复 |
| **排期板灯光秀设计** | 🔄 打磨中（第一阶段视觉已落地） | Header节目单风格、今日暖金光效、空日期暗化、海报质感、字体重排、农历标签；双指缩放/边缘侧光待第二阶段 |
| **详情页重构设计** | ✅ 完成 | 展示+编辑分离、待办清单、海报作为视觉标识、状态星星循环切换、光岛卡片风格 |
| **管理台重构设计** | 📋 已设计 | 海报网格画廊、月份筛选、点击进入管理 |
| **月历首页打磨** | ✅ 完成 | 固定头部、右上角筛选、满屏月历、折叠聚焦行、跨月日期显示 |
| **个人中心重构** | ✅ 完成 | 数据仪表盘+时间切片+Hero指标+管理入口聚合+指标/图表下钻月历 |
| **可视化图表** | ✅ 完成 | 月度柱状/演员排名/剧场分布/时段环形，月度柱状图支持下钻 |
| 演出提醒 | ❌ 砍掉/延后 | 应用内看到就行 |
| 观演记录 | ❌ 砍掉 | 不是排期管理的核心 |

---

## 9. 后续发展方向 (Roadmap)

### Phase 1：体验打磨（近期，1-2 周）

完成已规划但未落地的 UI/UX 优化：

1. **日历页重构**
   - 顶部日期选择器改为年历视图（12 月迷你网格），显示已买/想看/已观演标记
   - 月历下方区域支持滑动快速切换月/双周/周视图
   - 增加分割条拖拽指示器
   - 农历显示已接入 `lunar` 包，需完善渲染

2. **排期页重构**
   - 页面标题从"排期甘特图"简化为"排期"，删除顶部大标题
   - 左侧剧目栏占位增大（上下 padding 增加）
   - 添加剧目的 `+` 按钮移至右上角，放大尺寸
   - 删除左侧剧目栏旁的 `+` 号
   - **核心交互变更**：点击剧目占位框 → 弹出管理面板，显示该剧目总表（所有场次列表）、支持批量修改状态、编辑剧目信息、删除

3. **全局交互**
   - 统一页面转场动画（已部分实现 `SlideFadeRoute`）
   - 统一底部弹窗高度和圆角
   - 列表空状态设计

### Phase 2：功能增强（中期，1-2 月）

#### 2.1 观演提醒系统
- **目标**：提前 N 小时/天提醒用户即将观演
- **实现**：`flutter_local_notifications`（移动端）/ 浏览器 Notification API（Web）
- **配置**：支持全局默认提醒时间 + 单场自定义

#### 2.2 演员追踪
- **目标**：追踪喜爱演员的出场场次
- **功能**：
  - 演员页标记"关注"
  - 新录入场次若包含关注演员，自动提示
  - 演员出场日历（只看该演员的排期）

#### 2.3 统计与可视化
- **目标**：让数据控用户有成就感
- **功能**：
  - 年度观剧报告（观剧数量、总花费、最常去剧场、最常看演员）
  - 月度/年度趋势图表（使用已引入的 `fl_chart`）
  - 剧场分布饼图
  - 导出分享图片

#### 2.4 票务信息完善
- **目标**：更完整的票务管理
- **功能**：
  - 购票渠道记录（大麦/猫眼/剧院官网/闲鱼等）
  - 订单号/取票码备注
  - 票根拍照存档

### Phase 3：生态建设（长期，3-6 月）

#### 3.1 数据同步（可选云端）
- **现状**：纯本地存储，数据绑定单设备
- **方向**：
  - 自建轻量后端（如 Supabase / Firebase）或
  - WebDAV 同步（坚果云等）或
  - 局域网 P2P 同步
- **原则**：数据主权归用户，云端仅作为同步通道

#### 3.2 社区与共享
- **剧目模板市场**：用户可分享剧目模板（角色列表），新用户一键导入
- **排期共享**：生成分享图（卡司排期海报），支持微信分享
- **卡司变动通知**：订阅特定剧目的卡司变动（需接入官方数据源或社区维护）

#### 3.3 多平台扩展
- **iOS**：Flutter 本身支持，需配置 Xcode 签名
- **macOS**：Flutter Desktop 支持
- **小程序**：可考虑 Flutter 转小程序方案或独立开发

#### 3.4 智能化升级
- **OCR 模型自训练**：积累足够数据后，训练专用于剧场排期表的轻量模型
- **智能冲突检测**：添加新场次时，自动检测时间冲突
- **智能推荐**：基于观剧历史推荐同类型剧目/演员

---

## 10. 技术债务与重构建议

| 优先级 | 事项 | 影响 | 建议方案 |
|-------|------|------|---------|
| 中 | 状态管理 | 页面间数据同步依赖手动刷新 | 迁移至 Riverpod，全局管理当前用户、剧目列表 |
| 低 | 数据库迁移 | Schema 变更时需手写 migration | 引入 `drift` 或 `floor` 生成迁移代码 |
| 低 | Web 端持久化 | 当前 localStorage 有容量限制 (~5MB) | 评估 IndexedDB / `idb_sqflite` |
| 低 | 测试覆盖 | 当前无单元测试/Widget 测试 | 为核心业务逻辑（OCR 解析、模糊匹配、备份恢复）补充测试 |

---

## 总结

排期天菜已完成 MVP 核心闭环（录入 → 管理 → 查看 → 备份），当前处于 **UI/UX 打磨阶段**。产品方向明确：**排期的事，交给排期天菜。**

短期以体验优化为主，中期围绕"提醒-追踪-统计"增强用户粘性，长期考虑数据同步和社区化。技术栈选型务实，Flutter 跨平台覆盖目标场景，OCR + 知识库是核心差异化壁垒。
