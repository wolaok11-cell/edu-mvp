# Contracts

当前合约目录提供的是 MVP 骨架，不是最终可审计版本。重点是先把状态机、事件和模块边界稳定下来。

建议部署顺序：

1. `Treasury`
2. `TutorRegistry`
3. `ReputationManager`
4. `LessonEscrow`
5. `DisputeResolver`
6. 回填 `LessonEscrow.setDisputeResolver`
7. 回填 `ReputationManager.setWriter`

当前假设：

- 支付代币为 ERC-20 稳定币
- 争议证据保存在链下，只把摘要或哈希写上链
- 平台手续费在放款时切分
- 全额退款时平台不收手续费
- 部分退款时手续费按最终 tutor 实收比例线性计算

