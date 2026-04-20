import json
import csv
import os
import re
from .prompts import PromptBuilder
from .evaluator import SQLEvaluator

class BenchmarkRunner:
    """运行Benchmark对比实验"""

    def __init__(self, test_file: str):
        with open(test_file, 'r', encoding='utf-8') as f:
            self.test_cases = json.load(f)["test_cases"]
        self.evaluator = SQLEvaluator()
        self.prompt_builder = PromptBuilder()
        self.llm_client = None

    def set_llm_client(self, client):
        """设置LLM客户端"""
        self.llm_client = client

    def call_llm(self, prompt: str) -> str:
        """调用LLM API获取SQL"""
        if self.llm_client is None:
            raise ValueError("请先设置LLM客户端")

        response = self.llm_client.generate(prompt)
        return response

    def extract_sql(self, llm_output: str) -> str:
        """从LLM输出中提取SQL"""
        output = llm_output.strip()

        # 方式1: 匹配【SQL】标记后的内容（新CoT格式）
        if '【SQL】' in output:
            parts = output.split('【SQL】')
            if len(parts) > 1:
                sql = parts[1].strip().split('\n')[0].rstrip(';')
                return sql

        # 方式2: 匹配SQL:标记后的内容
        if 'SQL:' in output.upper():
            parts = output.split('SQL:')
            if len(parts) > 1:
                sql = parts[1].strip().split('\n')[0].rstrip(';')
                return sql

        # 方式3: 匹配完整的SELECT语句
        sql_match = re.search(r'(SELECT\s+.+?(?:;|$))', output, re.IGNORECASE | re.DOTALL)
        if sql_match:
            sql = sql_match.group(1).strip().rstrip(';')
            return sql

        # 方式4: 找代码块
        code_match = re.search(r'```(?:sql)?\s*(.*?)\s*```', output, re.IGNORECASE | re.DOTALL)
        if code_match:
            return code_match.group(1).strip().rstrip(';')

        return output.rstrip(';').strip()

    def run_method_prompt_only(self, method_name: str) -> dict:
        """仅生成prompt，不执行评估（用于测试流程）"""
        method_func = self.prompt_builder.get_all_methods()[method_name]
        results = []

        for case in self.test_cases:
            prompt = method_func(case["question"])
            llm_output = self.call_llm(prompt)
            predicted_sql = self.extract_sql(llm_output)

            results.append({
                "id": case["id"],
                "question": case["question"],
                "complexity": case["complexity"],
                "prompt": prompt,
                "llm_output": llm_output,
                "predicted_sql": predicted_sql,
                "gold_sql": case["gold_sql"],
                "execution_success": None,
                "result_match": None,
                "accuracy": None
            })

        return {
            "method": method_name,
            "total_cases": len(results),
            "correct": None,
            "accuracy_rate": None,
            "by_complexity": {},
            "details": results
        }

    def run_method(self, method_name: str) -> dict:
        """运行单一方法的评估"""
        method_func = self.prompt_builder.get_all_methods()[method_name]
        results = []

        for case in self.test_cases:
            prompt = method_func(case["question"])
            llm_output = self.call_llm(prompt)
            predicted_sql = self.extract_sql(llm_output)

            # 调试输出
            print(f"  Q{case['id']}: SQL提取长度={len(predicted_sql)}")

            eval_result = self.evaluator.evaluate(predicted_sql, case["gold_sql"])

            results.append({
                "id": case["id"],
                "question": case["question"],
                "complexity": case["complexity"],
                "predicted_sql": predicted_sql,
                "gold_sql": case["gold_sql"],
                "execution_success": eval_result["execution_success"],
                "result_match": eval_result["result_match"],
                "accuracy": eval_result["accuracy"]
            })

        # 计算整体指标
        total = len(results)
        correct = sum(r["accuracy"] for r in results)

        # 按复杂度分组统计
        by_complexity = {}
        for r in results:
            c = r["complexity"]
            if c not in by_complexity:
                by_complexity[c] = {"total": 0, "correct": 0}
            by_complexity[c]["total"] += 1
            by_complexity[c]["correct"] += r["accuracy"]

        return {
            "method": method_name,
            "total_cases": total,
            "correct": correct,
            "accuracy_rate": correct / total,
            "by_complexity": by_complexity,
            "details": results
        }

    def run_all_methods(self, skip_db_eval: bool = False) -> list:
        """运行所有方法对比"""
        if not skip_db_eval:
            if not self.evaluator.connect():
                raise RuntimeError("无法连接数据库")

        all_results = []
        for method_name in self.prompt_builder.get_all_methods().keys():
            print(f"\nRunning method: {method_name}")
            if skip_db_eval:
                # 仅测试prompt生成，不评估
                result = self.run_method_prompt_only(method_name)
            else:
                result = self.run_method(method_name)
            all_results.append(result)
            if not skip_db_eval:
                print(f"  Accuracy: {result['accuracy_rate']:.2%}")
            else:
                print(f"  Prompts generated: {result['total_cases']}")

        if not skip_db_eval:
            self.evaluator.close()
        return all_results

    def save_results(self, results: list, output_dir: str = "results"):
        """保存结果"""
        os.makedirs(output_dir, exist_ok=True)

        # 汇总表
        summary_file = os.path.join(output_dir, "comparison.csv")
        with open(summary_file, 'w', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow(["Method", "Total", "Correct", "Accuracy", "Easy", "Medium", "Hard"])
            for r in results:
                easy = r["by_complexity"].get("easy", {"correct": 0, "total": 0})
                med = r["by_complexity"].get("medium", {"correct": 0, "total": 0})
                hard = r["by_complexity"].get("hard", {"correct": 0, "total": 0})
                accuracy_str = f"{r['accuracy_rate']:.2%}" if r['accuracy_rate'] is not None else "N/A"
                writer.writerow([
                    r["method"],
                    r["total_cases"],
                    r["correct"] if r["correct"] is not None else "N/A",
                    accuracy_str,
                    f"{easy['correct']}/{easy['total']}" if easy['total'] > 0 else "N/A",
                    f"{med['correct']}/{med['total']}" if med['total'] > 0 else "N/A",
                    f"{hard['correct']}/{hard['total']}" if hard['total'] > 0 else "N/A"
                ])

        print(f"\nSummary saved to {summary_file}")

        # 详细结果
        for r in results:
            detail_file = os.path.join(output_dir, f"{r['method']}_details.json")
            with open(detail_file, 'w', encoding='utf-8') as f:
                json.dump(r["details"], f, ensure_ascii=False, indent=2)


def print_results_table(results: list):
    """打印格式化结果表"""
    print("\n" + "="*60)
    print("Benchmark Results Comparison")
    print("="*60)
    print(f"{'Method':<15} {'Accuracy':<10} {'Easy':<10} {'Medium':<10} {'Hard':<10}")
    print("-"*60)
    for r in results:
        easy = r["by_complexity"].get("easy", {"correct": 0, "total": 0})
        med = r["by_complexity"].get("medium", {"correct": 0, "total": 0})
        hard = r["by_complexity"].get("hard", {"correct": 0, "total": 0})
        print(f"{r['method']:<15} {r['accuracy_rate']:.2%}     {easy['correct']}/{easy['total']}      {med['correct']}/{med['total']}      {hard['correct']}/{hard['total']}")
    print("="*60)