# 去中心化家教平台 MVP Starter Pack

这个仓库把你提供的 PRD 落成了一套可以直接开工的基础工程资产，目标不是一次性把整站写完，而是先把研发边界、数据库、接口和合约骨架固定下来，方便前端、后端、合约三条线并行推进。

## 当前已落地内容

- `docs/architecture.md`
  系统边界、服务拆分、核心状态流和推荐开发顺序
- `docs/openapi.yaml`
  覆盖 P0/P1 的 REST API 设计
- `infra/db/init.sql`
  PostgreSQL 初始化脚本，包含核心业务表、索引、审计与链上事件去重表
- `contracts/src/*.sol`
  TutorRegistry、LessonEscrow、ReputationManager、DisputeResolver、Treasury 合约骨架
- `preview/*.html`
  可直接试运行的静态产品预览，覆盖首页、教师广场、教师详情、下单、订单、后台页
- `scripts/run_preview.py`
  Python 本地预览服务器
- `apps/web`
  前台用户端职责约定
- `apps/admin`
  运营后台职责约定
- `apps/api`
  业务后端职责约定

## 推荐工程结构

```text
.
├── apps
│   ├── admin
│   ├── api
│   └── web
├── contracts
│   └── src
├── docs
├── infra
│   └── db
└── README.md
```

## 建议技术栈

- 前台 `apps/web`：Next.js + React + TypeScript
- 后台 `apps/admin`：Next.js + React + TypeScript
- API `apps/api`：NestJS 或 Fastify
- 数据库：PostgreSQL
- 链上交互：viem / wagmi
- 合约：Solidity + Foundry
- 链上事件同步：watcher / worker 服务

## 核心闭环

1. 学生浏览教师并创建订单
2. 学生支付稳定币，订单进入托管
3. 教师上课后提交完课
4. 学生确认完成，或超时自动放款
5. 若发生争议，订单冻结并进入人工裁决
6. 结算完成后沉淀评价和可验证信誉

## 建议开发顺序

1. 先把 `docs/openapi.yaml` 作为前后端契约定下来
2. 用 `infra/db/init.sql` 建本地数据库并生成 ORM model
3. 优先完成订单、支付、争议三条状态链路
4. 按 `contracts/src/LessonEscrow.sol` 和 `contracts/src/DisputeResolver.sol` 继续补完合约逻辑与测试
5. 最后再补推荐、通知、收入统计等 P1 能力

## 关键实现约定

- 用户面尽量弱化 Web3 术语，统一使用“托管、确认、结算”等文案
- 链上只存资金与关键事实状态，复杂展示信息留在数据库
- 监听器需要基于 `tx_hash + log_index` 做幂等写入
- 争议证据默认链下存储，链上只保留轻量摘要
- 数据库时间字段优先使用 `TIMESTAMPTZ`

## 下一步最值得做的事

- 为 `apps/api` 补真实项目脚手架与模块代码
- 为 `contracts` 增加 Foundry 配置与测试
- 为 `apps/web` 先实现 4 个关键页面：首页、教师详情、下单页、订单详情页
- 为 watcher 增加链上事件消费和状态回写任务

## 现在怎么试运行

当前机器没有 Node、Forge 和 PostgreSQL，但有 Python，所以可以先直接跑静态预览：

```powershell
cd C:\Users\WANG\Desktop\edu
python scripts\run_preview.py
```

然后打开：

```text
http://127.0.0.1:8000/
```

这个预览版适合先看页面结构和核心转化链路，不涉及真实数据库、钱包和合约执行。
