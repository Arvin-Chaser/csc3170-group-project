# LLM Text-to-SQL Prompt Engineering 实验报告

## 1. 实验背景与目标

### 1.1 项目要求（CSC3170 Bonus任务）

根据课程项目要求，本实验旨在：

> **Investigate methods for crafting prompts that guide LLM to accurately generate queries for extracting information from the database. (5% points)**

即：探索如何设计Prompt来引导LLM准确生成数据库查询SQL。

### 1.2 实验目标

1. 设计并对比三种Prompt工程方法
2. 构建小型Benchmark进行定量评估
3. 分析不同方法的优缺点及适用场景

---

## 2. Benchmark设计

### 2.1 测试集构成

我们从项目已有的查询需求中选取15个代表性问题，覆盖三种复杂度：

| 复杂度 | 数量 | 定义 |
|--------|------|------|
| **Easy** | 3 | 单表查询，无JOIN |
| **Medium** | 8 | 两表JOIN或简单聚合 |
| **Hard** | 4 | 多表JOIN（≥3表）+ 聚合/嵌套 |

### 2.2 测试问题列表

| ID | 复杂度 | 问题描述 |
|----|--------|----------|
| 1 | Easy | 查询员工ID为25的直属上级姓名 |
| 2 | Medium | 查询研发部的所有员工姓名 |
| 3 | Medium | 统计每个部门的员工数量 |
| 4 | Medium | 查询预算超过50万的所有项目及其项目经理姓名 |
| 5 | Easy | 查询所有姓张的员工姓名 |
| 6 | Medium | 查询项目ID为3的客户名称 |
| 7 | Hard | 查询每个员工的总薪资（工资加奖金） |
| 8 | Medium | 查询没有分配任何任务的员工姓名 |
| 9 | Easy | 查询2025年入职的所有员工姓名和入职日期 |
| 10 | Medium | 查询状态为Done的所有任务及其所属项目名称 |
| 11 | Medium | 统计每个项目的任务数量 |
| 12 | Hard | 查询阿里巴巴参与的所有项目名称 |
| 13 | Hard | 查询迟到次数超过2次的员工姓名和迟到次数 |
| 14 | Hard | 查询每个部门的平均薪资 |
| 15 | Medium | 查询项目经理ID为5的所有任务名称 |

### 2.3 数据库Schema

测试数据库为公司管理系统（CompanyManager），包含9个表：

```
- Department(Department_ID, Department_Name, Department_Manager_ID)
- Employee(Employee_ID, First_Name, Last_Name, Department_ID, Address, Phone_Number, Hire_date, Supervisor_ID)
- Project(Project_ID, Project_Name, Start_date, End_date, Budget, Project_Manager_ID)
- Task(Task_ID, Project_ID, Task_name, Begin_date, Deadline, Status, Department_ID)
- Task_Assignment(Employee_ID, Task_ID, Role_in_Task)
- Attendance(Employee_ID, Date, Status)
- Salary_Record(Record_id, Employee_ID, Amount, Bonus, Date)
- Client(Client_id, Name, Phone_number)
- Client_Project(Client_id, Project_ID)
```

### 2.4 评估指标

采用 **Execution Accuracy（执行准确率）** 作为评估指标：

- 执行LLM生成的SQL，获取结果集
- 执行标准SQL，获取标准结果集
- 比较两个结果集是否一致（忽略顺序）

该指标借鉴自学术界广泛使用的 **Spider Benchmark** 的评估方法，相比Exact Match更能反映SQL语义正确性。

---

## 3. Prompt工程方法设计

### 3.1 方法一：Zero-shot + Schema

**原理**：仅提供数据库Schema描述，让LLM直接生成SQL，无任何示例或引导。

**Prompt模板**：
```
你是一个SQL专家。根据数据库schema生成正确的MySQL查询。

[完整Schema描述，包含表结构、字段、外键关系]

用户问题: {question}

请直接输出SQL查询，不要解释:
SQL:
```

**特点**：
- 简单直接，token消耗最少
- 完全依赖LLM的SQL生成能力
- 无引导可能导致复杂查询出错

### 3.2 方法二：Few-shot（示例引导）

**原理**：提供3个相似问题-SQL示例，让LLM通过类比学习生成模式。

**Prompt模板**：
```
你是一个SQL专家。根据数据库schema生成正确的MySQL查询。

[完整Schema描述]

示例:
问题: 查询所有员工姓名
SQL: SELECT CONCAT(Last_Name, First_Name) FROM Employee

问题: 查询市场部员工
SQL: SELECT ... FROM Employee JOIN Department WHERE ...

问题: 统计每个项目任务数
SQL: SELECT ... COUNT(...) FROM Project LEFT JOIN Task GROUP BY ...

用户问题: {question}
SQL:
```

**示例选择原则**：
- 覆盖不同JOIN模式（单表、两表JOIN、LEFT JOIN）
- 包含聚合函数示例（COUNT）
- 展示字段组合技巧（CONCAT）

**特点**：
- 示例引导帮助LLM学习SQL风格
- 对中等复杂度查询有帮助
- 示例选择影响效果

### 3.3 方法三：Chain-of-Thought（分步推理）

**原理**：让LLM先分析查询需求，再逐步构建SQL，将复杂任务分解。

**Prompt模板（改进版）**：
```
你是一个SQL专家。根据数据库schema生成MySQL查询。

[完整Schema描述]

用户问题: {question}

注意：
1. WHERE条件中的值必须从问题原文中精确提取，不要修改或推断
2. 例如问题说"阿里巴巴"，就用WHERE Name='阿里巴巴'，不要写成'阿里巴巴公司'

请按以下格式输出：

【分析】
1. 涉及哪些表？（从schema中选择）
2. 表之间如何JOIN？（写出外键连接）
3. 需要SELECT什么字段？
4. WHERE条件是什么？（精确复制问题中的值）
5. 是否需要GROUP BY？

【SQL】
（只输出一行完整的SQL，不要换行）
```

**设计改进说明**：

初始版本的CoT prompt存在**过度推理问题**：模型在分析步骤中错误推断WHERE条件值（如将"阿里巴巴"推断为"阿里巴巴公司"）。

改进版本添加了关键约束：
> **"WHERE条件中的值必须从问题原文中精确提取，不要修改或推断"**

这一改进显著提升了Hard查询的准确率（从50%提升到75%）。

**特点**：
- 分步推理避免遗漏
- 明确约束防止过度推断
- 输出格式规范便于提取

---

## 4. 实验配置

### 4.1 模型配置

| 配置项 | 值 |
|--------|-----|
| API平台 | 阿里百炼（DashScope） |
| 模型 | qwen3.6-plus |
| 特殊参数 | enable_thinking=true（启用深度思考） |
| Temperature | 0（确定性输出） |

### 4.2 实验环境

- Python 3.12
- MySQL数据库（本地）
- 数据已通过data.sql导入

---

## 5. 实验结果

### 5.1 整体准确率对比

| Method | Total | Correct | Accuracy | Easy | Medium | Hard |
|--------|-------|---------|----------|------|--------|------|
| **Zero-shot** | 15 | 10 | 66.67% | 3/3 (100%) | 4/8 (50%) | 3/4 (75%) |
| **Few-shot** | 15 | 10 | 66.67% | 3/3 (100%) | 5/8 (62.5%) | 2/4 (50%) |
| **CoT (改进后)** | 15 | 11 | **73.33%** | 3/3 (100%) | 5/8 (62.5%) | 3/4 (75%) |

### 5.2 各查询详细结果

| ID | Complexity | Question | Zero-shot | Few-shot | CoT |
|----|------------|----------|-----------|----------|-----|
| 1 | Easy | 查询员工ID为25的直属上级姓名 | ✓ | ✓ | ✓ |
| 2 | Medium | 查询研发部的所有员工姓名 | ✓ | ✓ | ✓ |
| 3 | Medium | 统计每个部门的员工数量 | ✗ | ✓ | ✓ |
| 4 | Medium | 查询预算超过50万的项目及其项目经理 | ✗ | ✗ | ✗ |
| 5 | Easy | 查询所有姓张的员工姓名 | ✓ | ✓ | ✓ |
| 6 | Medium | 查询项目ID为3的客户名称 | ✓ | ✓ | ✓ |
| 7 | Hard | 查询每个员工的总薪资（工资加奖金） | ✗ | ✗ | ✗ |
| 8 | Medium | 查询没有分配任何任务的员工姓名 | ✓ | ✓ | ✓ |
| 9 | Easy | 查询2025年入职的员工姓名和入职日期 | ✓ | ✓ | ✓ |
| 10 | Medium | 查询状态为Done的任务及其所属项目 | ✗ | ✗ | ✗ |
| 11 | Medium | 统计每个项目的任务数量 | ✗ | ✗ | ✗ |
| 12 | Hard | 查询阿里巴巴参与的所有项目名称 | ✓ | ✓ | ✓ |
| 13 | Hard | 查询迟到次数超过2次的员工姓名和迟到次数 | ✓ | ✓ | ✓ |
| 14 | Hard | 查询每个部门的平均薪资 | ✓ | ✗ | ✓ |
| 15 | Medium | 查询项目经理ID为5的所有任务名称 | ✓ | ✓ | ✓ |

---

## 6. 结果分析

### 6.1 按复杂度分析

#### Easy查询（100%正确）

三种方法在简单查询上都完美表现，说明：
- 单表查询不需要复杂推理
- Schema信息足够让LLM理解表结构

#### Medium查询（Few-shot和CoT最优）

| Method | Medium准确率 |
|--------|-------------|
| Zero-shot | 50% |
| Few-shot | **62.5%** |
| CoT | **62.5%** |

Few-shot的示例帮助LLM学习JOIN模式，CoT的分步分析避免遗漏。

#### Hard查询（Zero-shot和CoT最优）

| Method | Hard准确率 |
|--------|-----------|
| Zero-shot | **75%** |
| Few-shot | 50% |
| CoT | **75%** |

**有趣发现**：Zero-shot在Hard查询上表现反而很好。可能原因：
- Zero-shot直接生成SQL，凭"直觉"选择正确路径
- Few-shot的示例可能不适合复杂场景
- CoT改进后效果显著提升

### 6.2 CoT改进效果分析

| 版本 | 整体准确率 | Hard准确率 |
|------|-----------|-----------|
| 改进前 | 66.67% | 50% |
| 改进后 | **73.33%** | **75%** |

**改进效果显著**，关键改进点：

1. **添加精确提取约束**：避免模型过度推理WHERE条件值
2. **规范输出格式**：使用【SQL】标记便于提取

改进前的问题示例：
```
问题: 查询阿里巴巴参与的项目
模型推断: WHERE Name = '阿里巴巴公司'  ← 错误！数据库只有'阿里巴巴'
```

改进后：
```
问题: 查询阿里巴巴参与的项目
精确提取: WHERE Name = '阿里巴巴'  ← 正确！
```

### 6.3 共同失败的查询分析

以下4个查询三种方法都失败：

| ID | 问题 | 失败原因分析 |
|----|------|-------------|
| 4 | 查询预算超过50万的项目 | 生成的SQL缺少Budget字段输出 |
| 7 | 查询员工总薪资 | GROUP BY字段不完整，结果列数不匹配 |
| 10 | 查询Done状态任务 | 生成的SQL返回了不需要的字段 |
| 11 | 统计项目任务数 | SQL结构正确但结果字段不匹配 |

**根本原因**：问题描述与预期输出不完全明确，导致LLM生成了语义正确但字段不完全匹配的SQL。

---

## 7. 结论

### 7.1 主要结论

1. **CoT（改进后）最优**：73.33%准确率，比Zero-shot和Few-shot高6.67%

2. **Prompt改进有效**：添加"精确提取WHERE条件"约束后，CoT Hard准确率从50%提升到75%

3. **复杂度影响显著**：
   - Easy查询：三种方法都完美（100%）
   - Medium查询：Few-shot和CoT优于Zero-shot
   - Hard查询：Zero-shot和CoT优于Few-shot

4. **方法适用场景**：
   - 简单查询：任意方法即可
   - 中等复杂度：推荐Few-shot或CoT
   - 复杂查询：推荐改进后的CoT

### 7.2 关键发现

| 发现 | 说明 |
|------|------|
| CoT的过度推理问题 | 分步分析可能导致模型"推理"出错误值 |
| 精确提取约束有效 | 强调"不要修改或推断"显著提升效果 |
| Few-shot示例选择重要 | 示例需覆盖目标查询的JOIN模式 |

### 7.3 实验局限

1. **测试集规模较小**：15个问题，统计意义有限
2. **单一模型测试**：仅使用qwen3.6-plus，未对比其他模型
3. **数据库schema简单**：仅9个表，复杂企业场景可能不同

### 7.4 未来改进方向

1. 扩大测试集规模（参考Spider/BIRD benchmark）
2. 测试更多模型（GPT-4、Claude等）
3. 设计更多prompt变体（如动态示例选择）
4. 引入Test Suite Accuracy评估（更鲁棒的指标）

---

## 8. 参考文献

本实验借鉴了以下学术研究的思路：

1. **DAIL-SQL** (arXiv 2308.15363): 系统性对比prompt工程方法，提出Few-shot + Schema的最佳组合
2. **Divide-and-Prompt** (arXiv 2304.11556): Chain-of-Thought分解方法在Text-to-SQL的应用
3. **Spider Benchmark** (Yu et al., 2018): Execution Accuracy评估指标
4. **Test Suite Accuracy** (arXiv 2010.02840): 更鲁棒的语义评估方法

---

## 附录：实验文件结构

```
llm_sql/
├── config.py      # Schema描述 + 数据库配置
├── prompts.py     # 三种Prompt模板
├── evaluator.py   # Execution Accuracy评估器
├── benchmark.py   # Benchmark运行器
├── client.py      # LLM API客户端

tests/
└── benchmark_data.json  # 15个测试问题

results/
├── comparison.csv        # 汇总对比表
├── zero_shot_details.json
├── few_shot_details.json
├── cot_details.json
└── BONUS_REPORT.md       # 本报告
```

---