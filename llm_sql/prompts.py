from .config import SCHEMA_DESCRIPTION

class PromptBuilder:
    """三种Prompt工程方法"""

    # 示例库（用于Few-shot）
    EXAMPLES = [
        {
            "question": "查询所有员工姓名",
            "sql": "SELECT CONCAT(Last_Name, First_Name) AS Employee_Name FROM Employee"
        },
        {
            "question": "查询市场部的员工",
            "sql": "SELECT CONCAT(e.Last_Name, e.First_Name) FROM Employee e JOIN Department d ON e.Department_ID = d.Department_ID WHERE d.Department_Name = '市场部'"
        },
        {
            "question": "统计每个项目的任务数",
            "sql": "SELECT p.Project_Name, COUNT(t.Task_ID) FROM Project p LEFT JOIN Task t ON p.Project_ID = t.Project_ID GROUP BY p.Project_ID, p.Project_Name"
        }
    ]

    @staticmethod
    def method1_zero_shot(question: str) -> str:
        """方法1: Zero-shot + Schema描述"""
        return f"""你是一个SQL专家。根据数据库schema生成正确的MySQL查询。

{SCHEMA_DESCRIPTION}

用户问题: {question}

请直接输出SQL查询，不要解释:
SQL:"""

    @staticmethod
    def method2_few_shot(question: str) -> str:
        """方法2: Few-shot (3个示例)"""
        examples_str = ""
        for ex in PromptBuilder.EXAMPLES:
            examples_str += f"\n问题: {ex['question']}\nSQL: {ex['sql']}\n"

        return f"""你是一个SQL专家。根据数据库schema生成正确的MySQL查询。

{SCHEMA_DESCRIPTION}

示例:
{examples_str}

用户问题: {question}
SQL:"""

    @staticmethod
    def method3_chain_of_thought(question: str) -> str:
        """方法3: Chain-of-Thought分解 - 改进版，避免过度推理"""
        return f"""你是一个SQL专家。根据数据库schema生成MySQL查询。

{SCHEMA_DESCRIPTION}

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

示例：
问题: 查询阿里巴巴参与的项目
【分析】
1. 涉及表: Project, Client_Project, Client
2. JOIN: Project.Project_ID = Client_Project.Project_ID, Client_Project.Client_id = Client.Client_id
3. SELECT: Project_Name
4. WHERE: Name = '阿里巴巴'（精确提取）
5. GROUP BY: 不需要
【SQL】
SELECT p.Project_Name FROM Project p JOIN Client_Project cp ON p.Project_ID = cp.Project_ID JOIN Client c ON cp.Client_id = c.Client_id WHERE c.Name = '阿里巴巴'
"""

    @staticmethod
    def get_all_methods() -> dict:
        """返回所有方法"""
        return {
            "zero_shot": PromptBuilder.method1_zero_shot,
            "few_shot": PromptBuilder.method2_few_shot,
            "cot": PromptBuilder.method3_chain_of_thought
        }