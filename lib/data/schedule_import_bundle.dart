// GENERATED FILE - do not edit by hand
// Generated from 卡司排期汇总表.md

class ScheduleImportCast {
  final String role;
  final String actor;
  const ScheduleImportCast({required this.role, required this.actor});
}

class ScheduleImportPerformance {
  final String date; // YYYY-MM-DD
  final String time; // HH:MM
  final List<ScheduleImportCast> cast;
  const ScheduleImportPerformance({
    required this.date,
    required this.time,
    required this.cast,
  });
}

class ScheduleImportShow {
  final String name;
  final String theater;
  final List<ScheduleImportPerformance> performances;
  const ScheduleImportShow({
    required this.name,
    required this.theater,
    required this.performances,
  });
}

const List<ScheduleImportShow> scheduleImportBundle = [
  ScheduleImportShow(
    name: '红莲',
    theater: '中华剧院',
    performances: [
      ScheduleImportPerformance(
        date: '2026-08-01',
        time: '15:00',
        cast: [
          ScheduleImportCast(
            role: '「红莲」',
            actor: '邓贤凌',
          ),
          ScheduleImportCast(
            role: '「钵里公主」',
            actor: '徐梦',
          ),
          ScheduleImportCast(
            role: '「降临道令」',
            actor: '胡芳洲',
          ),
          ScheduleImportCast(
            role: '「日值」',
            actor: '李泽晨',
          ),
          ScheduleImportCast(
            role: '「月值」',
            actor: '李子涵',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '红莲',
    theater: '北京喜剧院',
    performances: [
      ScheduleImportPerformance(
        date: '2026-07-17',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「红莲」',
            actor: '刘乙萱',
          ),
          ScheduleImportCast(
            role: '「钵里公主」',
            actor: '徐梦',
          ),
          ScheduleImportCast(
            role: '「降临道令」',
            actor: '胡芳洲',
          ),
          ScheduleImportCast(
            role: '「日值」',
            actor: '诸葛北辰',
          ),
          ScheduleImportCast(
            role: '「月值」',
            actor: '李子涵',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-18',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「红莲」',
            actor: '刘乙萱',
          ),
          ScheduleImportCast(
            role: '「钵里公主」',
            actor: '徐梦',
          ),
          ScheduleImportCast(
            role: '「降临道令」',
            actor: '胡芳洲',
          ),
          ScheduleImportCast(
            role: '「日值」',
            actor: '诸葛北辰',
          ),
          ScheduleImportCast(
            role: '「月值」',
            actor: '李子涵',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '蝶变',
    theater: '北京天桥艺术中心·小剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-09-05',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「曼曼」',
            actor: '钱安琪',
          ),
          ScheduleImportCast(
            role: '「沈文君」',
            actor: '邓贤凌',
          ),
          ScheduleImportCast(
            role: '「齐治平」',
            actor: '刘泽星',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-09-05',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「曼曼」',
            actor: '胥子含',
          ),
          ScheduleImportCast(
            role: '「沈文君」',
            actor: '邓贤凌',
          ),
          ScheduleImportCast(
            role: '「齐治平」',
            actor: '刘泽星',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-09-06',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「曼曼」',
            actor: '叶嘉雯',
          ),
          ScheduleImportCast(
            role: '「沈文君」',
            actor: '丁辰西',
          ),
          ScheduleImportCast(
            role: '「齐治平」',
            actor: '付世刚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-09-06',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「曼曼」',
            actor: '叶嘉雯',
          ),
          ScheduleImportCast(
            role: '「沈文君」',
            actor: '赵嘉艳',
          ),
          ScheduleImportCast(
            role: '「齐治平」',
            actor: '付世刚',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '秘密花园',
    theater: '二七剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-07-02',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '程晨',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '林润欣',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-03',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '程晨',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '覃一凡',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-04',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '覃一凡',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-04',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '覃一凡',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-05',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '覃一凡',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-05',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「艾米&玛丽」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「黛娜&玛莎」',
            actor: '覃一凡',
          ),
          ScheduleImportCast(
            role: '「查理&科林」',
            actor: '孙天宇',
          ),
          ScheduleImportCast(
            role: '「比尔&迪肯」',
            actor: '张博俊',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '嫌疑人X的献身',
    theater: '北京天桥艺术中心·大剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-08-07',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「石神哲哉」',
            actor: '冒海飞',
          ),
          ScheduleImportCast(
            role: '「汤川学」',
            actor: '赵超凡',
          ),
          ScheduleImportCast(
            role: '「花岗靖子」',
            actor: '徐丽东',
          ),
          ScheduleImportCast(
            role: '「富樫&工藤」',
            actor: '桑可舟',
          ),
          ScheduleImportCast(
            role: '「花岗美里」',
            actor: '潘珏辰',
          ),
          ScheduleImportCast(
            role: '「草薙俊平」',
            actor: '钱蒙楠',
          ),
          ScheduleImportCast(
            role: '「内海薰」',
            actor: '邓茹月',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-08',
        time: '14:00',
        cast: [
          ScheduleImportCast(
            role: '「石神哲哉」',
            actor: '冒海飞',
          ),
          ScheduleImportCast(
            role: '「汤川学」',
            actor: '赵超凡',
          ),
          ScheduleImportCast(
            role: '「花岗靖子」',
            actor: '徐丽东',
          ),
          ScheduleImportCast(
            role: '「富樫&工藤」',
            actor: '桑可舟',
          ),
          ScheduleImportCast(
            role: '「花岗美里」',
            actor: '潘珏辰',
          ),
          ScheduleImportCast(
            role: '「草薙俊平」',
            actor: '钱蒙楠',
          ),
          ScheduleImportCast(
            role: '「内海薰」',
            actor: '邓茹月',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-08',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「石神哲哉」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「汤川学」',
            actor: '余笛',
          ),
          ScheduleImportCast(
            role: '「花岗靖子」',
            actor: '蒋倩如',
          ),
          ScheduleImportCast(
            role: '「富樫&工藤」',
            actor: '桑可舟',
          ),
          ScheduleImportCast(
            role: '「花岗美里」',
            actor: '潘珏辰',
          ),
          ScheduleImportCast(
            role: '「草薙俊平」',
            actor: '钱蒙楠',
          ),
          ScheduleImportCast(
            role: '「内海薰」',
            actor: '邓茹月',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-09',
        time: '14:00',
        cast: [
          ScheduleImportCast(
            role: '「石神哲哉」',
            actor: '冒海飞',
          ),
          ScheduleImportCast(
            role: '「汤川学」',
            actor: '余笛',
          ),
          ScheduleImportCast(
            role: '「花岗靖子」',
            actor: '蒋倩如',
          ),
          ScheduleImportCast(
            role: '「富樫&工藤」',
            actor: '桑可舟',
          ),
          ScheduleImportCast(
            role: '「花岗美里」',
            actor: '潘珏辰',
          ),
          ScheduleImportCast(
            role: '「草薙俊平」',
            actor: '钱蒙楠',
          ),
          ScheduleImportCast(
            role: '「内海薰」',
            actor: '邓茹月',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-09',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「石神哲哉」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「汤川学」',
            actor: '余笛',
          ),
          ScheduleImportCast(
            role: '「花岗靖子」',
            actor: '蒋倩如',
          ),
          ScheduleImportCast(
            role: '「富樫&工藤」',
            actor: '桑可舟',
          ),
          ScheduleImportCast(
            role: '「花岗美里」',
            actor: '潘珏辰',
          ),
          ScheduleImportCast(
            role: '「草薙俊平」',
            actor: '钱蒙楠',
          ),
          ScheduleImportCast(
            role: '「内海薰」',
            actor: '邓茹月',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '女巫',
    theater: '上海话剧艺术中心',
    performances: [
      ScheduleImportPerformance(
        date: '2026-07-23',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '余思冉',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '张沁丹',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '赵雨卉',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '付世刚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-24',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '陈恬',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁臻滢',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '王洁璐',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '曹洪远',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-25',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '余思冉',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁臻滢',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '王洁璐',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '覃威尔',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-26',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '陈恬',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '王洁璐',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '曹洪远',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-26',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '胥子含',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '张沁丹',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '赵雨卉',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '付世刚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-28',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '余思冉',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁臻滢',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '覃威尔',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-29',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '胥子含',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '张沁丹',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '赵雨卉',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '曹洪远',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-30',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁辰西',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '付世刚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-31',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '赵雨卉',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '曹洪远',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-01',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '叶嘉雯',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁辰西',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '覃威尔',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-01',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '陈玉婷',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '丁辰西',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '付世刚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-02',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「ABBEY」',
            actor: '叶嘉雯',
          ),
          ScheduleImportCast(
            role: '「MARGARET」',
            actor: '党韫葳',
          ),
          ScheduleImportCast(
            role: '「ELSPETH」',
            actor: '王洁璐',
          ),
          ScheduleImportCast(
            role: '「WITCH HUNTER」',
            actor: '覃威尔',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '初步举证',
    theater: '天桥艺术中心-中剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-08-27',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-28',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-29',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-08-30',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '初步举证',
    theater: '天津大剧院',
    performances: [
      ScheduleImportPerformance(
        date: '2026-09-04',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-09-05',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-09-06',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「泰莎」',
            actor: '陈昊宇',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '破墙',
    theater: '上海大世界4楼夭蛾剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-06-26',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '强东玥',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '黄思惟',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '周一男',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-27',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '强东玥',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '杨悦',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '乌丽雅苏',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-28',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '明家歆',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '谭茜',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '姚岚',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-03',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '钱可欣',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '徐天戈',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '张一铭',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-04',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '陈旭',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '俞王诗琪',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '刘宇希',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-05',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '陈旭',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '王韬翔',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '张一铭',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-06',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '强雯',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '陈旭',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '姚岚',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '雌雄',
    theater: '北京二七剧场',
    performances: [
      ScheduleImportPerformance(
        date: '2026-06-12',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '谭维维',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '卞佳平',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-13',
        time: '14:00',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '苗梦初',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '卞佳平',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-13',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '谭维维',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '苏锡凡',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '人间失格',
    theater: '北京保利剧院',
    performances: [
      ScheduleImportPerformance(
        date: '2026-07-03',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「大庭叶藏」',
            actor: '刘令飞',
          ),
          ScheduleImportCast(
            role: '「太宰治」',
            actor: '白举纲',
          ),
          ScheduleImportCast(
            role: '「祝子」',
            actor: '强东玥',
          ),
          ScheduleImportCast(
            role: '「堀木正雄」',
            actor: '翟李朔天',
          ),
          ScheduleImportCast(
            role: '「恒子」',
            actor: '张沁丹',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-04',
        time: '13:30',
        cast: [
          ScheduleImportCast(
            role: '「大庭叶藏」',
            actor: '叶麒圣',
          ),
          ScheduleImportCast(
            role: '「太宰治」',
            actor: '刘令飞',
          ),
          ScheduleImportCast(
            role: '「祝子」',
            actor: '徐梦迪',
          ),
          ScheduleImportCast(
            role: '「堀木正雄」',
            actor: '张玮伦',
          ),
          ScheduleImportCast(
            role: '「恒子」',
            actor: '张沁丹',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-04',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「大庭叶藏」',
            actor: '白举纲',
          ),
          ScheduleImportCast(
            role: '「太宰治」',
            actor: '刘令飞',
          ),
          ScheduleImportCast(
            role: '「祝子」',
            actor: '李炜铃',
          ),
          ScheduleImportCast(
            role: '「堀木正雄」',
            actor: '张玮伦',
          ),
          ScheduleImportCast(
            role: '「恒子」',
            actor: '张沁丹',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-05',
        time: '13:30',
        cast: [
          ScheduleImportCast(
            role: '「大庭叶藏」',
            actor: '刘令飞',
          ),
          ScheduleImportCast(
            role: '「太宰治」',
            actor: '叶麒圣',
          ),
          ScheduleImportCast(
            role: '「祝子」',
            actor: '李炜铃',
          ),
          ScheduleImportCast(
            role: '「堀木正雄」',
            actor: '王瑞',
          ),
          ScheduleImportCast(
            role: '「恒子」',
            actor: '蒋依敏',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-05',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「大庭叶藏」',
            actor: '叶麒圣',
          ),
          ScheduleImportCast(
            role: '「太宰治」',
            actor: '刘令飞',
          ),
          ScheduleImportCast(
            role: '「祝子」',
            actor: '李炜铃',
          ),
          ScheduleImportCast(
            role: '「堀木正雄」',
            actor: '王瑞',
          ),
          ScheduleImportCast(
            role: '「恒子」',
            actor: '张沁丹',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '雌雄',
    theater: '上海西岸大剧院',
    performances: [
      ScheduleImportPerformance(
        date: '2026-06-24',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '谭维维',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '卞佳平',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-25',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '苗梦初',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '刘岩',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '高天鹤',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-26',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '谭维维',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '马添龙',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '高天鹤',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-27',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '谭维维',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '李炜鹏',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '苏锡凡',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-06-28',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「沈不疑」',
            actor: '苗梦初',
          ),
          ScheduleImportCast(
            role: '「聂律师」',
            actor: '马添龙',
          ),
          ScheduleImportCast(
            role: '「公诉人」',
            actor: '卞佳平',
          ),
        ],
      ),
    ],
  ),
  ScheduleImportShow(
    name: '破墙',
    theater: '上海大世界4楼夭蛾剧场（补充场次）',
    performances: [
      ScheduleImportPerformance(
        date: '2026-07-10',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '范可妮',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '谭茜',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '马凯漪',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-11',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '左一平',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '徐天戈',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '李星葆',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-12',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '左一平',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '张烜尔',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '范可妮',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-15',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '强雯',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '薛钦元',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '钟子崴',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-16',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '钱可欣',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '薛钦元',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '钟子崴',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-17',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '明家歆',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '王韬翔',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '张觉一',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-18',
        time: '14:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '明家歆',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '俞王诗琪',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '刘宇希',
          ),
        ],
      ),
      ScheduleImportPerformance(
        date: '2026-07-18',
        time: '19:30',
        cast: [
          ScheduleImportCast(
            role: '「孟潼/小月」',
            actor: '钱可欣',
          ),
          ScheduleImportCast(
            role: '「薛临」',
            actor: '王韬翔',
          ),
          ScheduleImportCast(
            role: '「沈亮」',
            actor: '郑润琦',
          ),
        ],
      ),
    ],
  ),
];