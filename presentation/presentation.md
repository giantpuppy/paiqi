---
marp: true
theme: default
paginate: true
backgroundColor: '#0F0F0F'
color: '#FFFFFF'
class: invert
style: |
  @import url('https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;700;900&display=swap');

  :root {
    --color-background: #0F0F0F;
    --color-foreground: #FFFFFF;
    --color-purple: #8B5CF6;
    --color-green: #34D399;
    --color-gray: #B0B0B0;
  }

  section {
    font-family: 'Noto Sans SC', sans-serif;
    background-color: #0F0F0F;
    color: #FFFFFF;
    padding: 60px;
  }

  h1 {
    color: #8B5CF6;
    font-weight: 900;
    font-size: 2.8em;
    margin-bottom: 0.3em;
  }

  h2 {
    color: #34D399;
    font-weight: 700;
    font-size: 1.8em;
    margin-top: 0;
  }

  h3 {
    color: #FFFFFF;
    font-weight: 700;
  }

  strong {
    color: #34D399;
  }

  code {
    background-color: #1A1A1A;
    color: #34D399;
    padding: 2px 6px;
    border-radius: 4px;
  }

  ul li::marker {
    color: #8B5CF6;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9em;
  }

  th {
    background-color: #8B5CF6;
    color: #FFFFFF;
    padding: 12px;
    text-align: left;
  }

  td {
    border-bottom: 1px solid #333;
    padding: 12px;
    color: #E0E0E0;
  }

  tr:nth-child(even) {
    background-color: #1A1A1A;
  }

  section.lead {
    text-align: center;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
  }

  .lead h1 {
    font-size: 4em;
    margin-bottom: 0.2em;
  }

  .lead p {
    font-size: 1.4em;
    color: #B0B0B0;
  }

  .slogan {
    color: #34D399;
    font-size: 1.6em;
    font-weight: 700;
    margin-top: 1em;
  }

  .tagline {
    color: #8B5CF6;
    font-size: 1.2em;
    font-weight: 700;
    letter-spacing: 0.1em;
  }

  .placeholder {
    background-color: #1A1A1A;
    border: 2px dashed #8B5CF6;
    border-radius: 12px;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #8B5CF6;
    font-size: 1.2em;
    font-weight: 700;
    min-height: 300px;
    text-align: center;
  }

  .placeholder-small {
    min-height: 180px;
  }

  .two-column {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 40px;
    align-items: center;
  }

  .two-column-wide {
    display: grid;
    grid-template-columns: 1.2fr 0.8fr;
    gap: 40px;
    align-items: center;
  }

  .three-column {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 24px;
    margin-top: 30px;
  }

  .card {
    background-color: #1A1A1A;
    border-radius: 16px;
    padding: 24px;
    border-left: 4px solid #8B5CF6;
  }

  .card h3 {
    color: #34D399;
    margin-top: 0;
    font-size: 1.3em;
  }

  .card p {
    color: #E0E0E0;
    line-height: 1.6;
  }

  .painpoint-card {
    background-color: #1A1A1A;
    border-radius: 12px;
    padding: 20px 24px;
    margin-bottom: 16px;
    border-left: 4px solid #8B5CF6;
  }

  .painpoint-card h3 {
    color: #34D399;
    margin-top: 0;
    margin-bottom: 8px;
  }

  .painpoint-card p {
    margin: 0;
    color: #E0E0E0;
  }

  footer {
    color: #666;
    font-size: 0.7em;
  }

  .page-number {
    color: #8B5CF6;
  }

  blockquote {
    font-size: 1.2em;
    color: #B0B0B0;
    font-style: italic;
    border-left: 4px solid #34D399;
    padding-left: 20px;
    margin: 24px 0;
  }

  blockquote p {
    margin: 0;
  }
---

<!-- _class: lead -->

# 排期天菜

<p class="tagline">排期的事，交给排期天菜。</p>

<p class="slogan">专为中国音乐剧观众打造的排期管理 App</p>

<p style="margin-top: 60px; color: #666;">Paiqi Release</p>

<!-- 封面视觉：Logo 大图居中，黑底紫绿渐变光效 -->

---

## 排剧期，记场次，存票根

一款专为中国音乐剧观众打造的排期管理 App。

从**关注一部剧的那一刻起**就把场次信息纳入排期计划，从"关注"到"复盘"，全流程一个 App 搞定。

> 排期的事，交给排期天菜。

<div class="two-column-wide" style="margin-top: 30px;">
  <div>
    <ul>
      <li><strong>排剧期：</strong>可视化对比剧目排期</li>
      <li><strong>记场次：</strong>已购/想看场次 + 待办提醒</li>
      <li><strong>存票根：</strong>月底年底数据复盘</li>
    </ul>
  </div>
  <div class="placeholder" style="min-height: 280px;">
    【截图位置】<br>App 月历首页 / 开屏页
  </div>
</div>

---

## 为谁而做

一个月需要关注几十场剧的中国音乐剧观众。

<div class="two-column-wide">
  <div>
    <ul>
      <li>女性占比 <strong>75.5%</strong>，"她经济"浓度最高的文娱品类</li>
      <li>核心年龄层 18-35 岁，一二线城市为主力</li>
      <li>人均消费 <strong>221 元</strong>，是电影的 5 倍</li>
      <li>跨城观演比例 <strong>30%+</strong>，愿意为审美付费</li>
    </ul>

> 2025 年全国音乐剧 1.97 万场、票房 18.07 亿、观众 818.59 万，增速 15.04%。
> 数据来源：中国演出行业协会
  </div>
  <div class="placeholder" style="min-height: 320px;">
    【截图位置】<br>用户场景拼贴：微信 / 大麦 / 小红书 / 日历
  </div>
</div>

---

## 痛点：为什么"排"在中国尤其痛

<div class="painpoint-card">
  <h3>🎭 演员卡司没出全，不敢买</h3>
  <p>开票时只公布剧目和日期，演员卡司要等后续分批官宣。但好位置不等人——等演员卡司出了再买，可能已售罄。</p>
</div>

<div class="painpoint-card">
  <h3>🚫 票不能退，出票很难</h3>
  <p>买错了只能自己在二手平台降价转手，亏钱不说还不一定出得掉。</p>
</div>

<div class="painpoint-card">
  <h3>💸 打折背刺原价观众</h3>
  <p>主办方临近放出折扣票，买早怕被背刺，买晚怕买不到。</p>
</div>

<div class="painpoint-card">
  <h3>📱 排期信息散落五六个平台</h3>
  <p>官宣在微博，排期在公众号，买票在大麦，讨论在小红书，剧评在豆瓣。每次决策都要手动拼凑。</p>
</div>

---

## 现有工具只管记，不管排

| 工具类型 | 代表 | 覆盖阶段 | 问题 |
|---------|------|---------|------|
| 售票类 | 大麦 / 猫眼 | 购票环节 | 只管买，不管排期规划 |
| 记录类 | 记录现场 / 剧在 | 看完之后 | 只管记，不管从关注到排 |
| 通用工具 | 日历 / Excel | 碎片记录 | 塞不下演员卡司、票版、场次对比 |

> 没有一个工具覆盖从「关注」到「排」的前半段路径。

---

## 解决方案：排 · 记 · 存

针对"排"和"记"的脱节，排期天菜围绕三个字构建完整闭环。

<div class="three-column">
  <div class="card">
    <h3>🟣 排 · 买哪场</h3>
    <p>从关注剧目那一刻起，场次信息就进入排期计划。</p>
    <p>可视化排期流横向纵向对比演员卡司和时间，想看的一键 mark，自动同步月历。</p>
  </div>
  <div class="card">
    <h3>🟢 记 · 买了什么</h3>
    <p>已购票场次集中管理。</p>
    <p>票根、座位、待办事项一场场列清楚。午场是 14:00 还是 14:30？不再靠临场记忆。</p>
  </div>
  <div class="card">
    <h3>🟣 存 · 看了多少</h3>
    <p>数据自动沉淀，不需要手动记录。</p>
    <p>月底年底，剧目次数、演员次数自动生成可视化图表和看剧报告。</p>
  </div>
</div>

---

<!-- 建议插入在第 6 页之后：现场 Demo 路线图 -->

## 现场演示：一位剧女的一天

<div class="two-column-wide">
  <div>
    <ol>
      <li><strong>打开月历</strong>：今天有哪些演出？</li>
      <li><strong>管理台收剧</strong>：把新剧先放进资料库</li>
      <li><strong>加入排期流</strong>：挑选场次进入可视排期</li>
      <li><strong>排期板对比</strong>：3天聚焦 ↔ 7天宏观切换</li>
      <li><strong>记录票根与待办</strong>：买完票不再失忆</li>
      <li><strong>个人中心复盘</strong>：数据自动生成报告</li>
    </ol>
  </div>
  <div class="placeholder" style="min-height: 360px;">
    【截图位置】<br>三张核心页面拼贴<br>月历 / 排期板 / 个人中心
  </div>
</div>

---

## 排：把排期表变成可视化排期流

<div class="two-column-wide">
  <div>
    <ul>
      <li>剧目宣排期一键查看</li>
      <li>横向纵向对比场次与卡司</li>
      <li>想看的场次手动 mark</li>
      <li>自动同步到月历首页</li>
    </ul>

> 不再翻相册、不再搜大麦，排期流上一眼盘清楚。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>排期板双密度视图
  </div>
</div>

---

## 记：保存 + 提醒，不再临场失忆

<div class="two-column-wide">
  <div>
    <ul>
      <li>已购票场次集中管理</li>
      <li>添加提醒和备注事项</li>
      <li>换物料、帮人取票、面交、买周边</li>
      <li>领鸡蛋规则地点一一记录</li>
    </ul>

> 剧场门口不再手忙脚乱，打开 App 就知道今天要干嘛。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>详情页待办清单
  </div>
</div>

---

## 存：月底年底一键复盘

<div class="two-column-wide">
  <div>
    <ul>
      <li>看过的剧目次数统计</li>
      <li>看过的演员次数统计</li>
      <li>花费金额可视化</li>
      <li>一键生成年度看剧报告</li>
    </ul>

> 年底发小红书年度总结，素材直接从这里拿。
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>个人中心四张图表
  </div>
</div>

---

## 视觉设计：像素风 + 星之果实紫绿

<div class="two-column-wide">
  <div>
    <ul>
      <li>黑底 <code>#0F0F0F</code>，护眼不刺眼</li>
      <li>紫 <code>#8B5CF6</code> + 绿 <code>#34D399</code>，星之果实感</li>
      <li>像素字体与图标，致敬剧场票根 / 街机复古感</li>
      <li>Logo 字谜：「非」+ 横线 +「菜」= <strong>韭</strong>，其余为紫</li>
    </ul>
  </div>
  <div class="placeholder" style="min-height: 340px;">
    【截图位置】<br>Logo 拆解图 + 色板展示
  </div>
</div>

---

## 总结

<div class="three-column">
  <div class="card">
    <h3>品类空白</h3>
    <p>现有工具只管记不管排，从「关注」到「排」的前半段路径没有任何工具覆盖。</p>
  </div>
  <div class="card">
    <h3>行业痛点</h3>
    <p>票不能退、演员卡司不确定、打折背刺——观众被迫自己做排期规划。</p>
  </div>
  <div class="card">
    <h3>排 · 记 · 存</h3>
    <p>从关注剧目到看完复盘，全流程一个 App 搞定。</p>
  </div>
</div>

> 排期的事，交给排期天菜。

---

<!-- _class: lead -->

# 排期天菜

<p class="slogan">排期的事，交给排期天菜。</p>

<p style="margin-top: 80px; font-size: 1.5em; color: #34D399;">看剧的快乐不该被排期吃掉。</p>

<p style="margin-top: 40px; color: #666;">Paiqi · 排期天菜</p>

<div style="margin-top: 30px;">
  <img src="assets/qr_paiqi_preview.png" width="160" height="160" alt="在线预览二维码" style="border-radius: 12px;" />
  <p style="margin-top: 12px; font-size: 0.9em; color: #B0B0B0;">扫码体验：giantpuppy.github.io/leeks-genius</p>
</div>

<!-- 结尾页：Logo + 结语 + 紫绿光效 + 在线预览二维码 -->
