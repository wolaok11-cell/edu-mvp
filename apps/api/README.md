# 业务后端 API

建议按领域拆模块，而不是按数据库表平铺：

```text
src/
├── modules/
│   ├── auth/
│   ├── users/
│   ├── tutors/
│   ├── lesson-products/
│   ├── orders/
│   ├── payments/
│   ├── disputes/
│   ├── reviews/
│   ├── notifications/
│   ├── admin/
│   └── webhooks/
├── common/
└── infrastructure/
```

优先落地的业务约束：

- 订单状态机校验
- 用户角色和资源权限校验
- 链上交易幂等回写
- 争议流程的冻结和裁决状态控制
