#!/usr/bin/env python3
"""
Text-to-SQL Prompt Engineering Benchmark

运行方式:
1. 设置环境变量: export DASHSCOPE_API_KEY="your-key"
2. 运行: python3 run_benchmark.py

可选参数:
--mock: 使用Mock客户端（不调用真实API，用于测试流程）
--method: 只运行指定方法 (zero_shot/few_shot/cot)
"""

import argparse
import sys
import os

# 添加项目路径
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from llm_sql.benchmark import BenchmarkRunner, print_results_table
from llm_sql.client import LLMClient, MockLLMClient


def main():
    parser = argparse.ArgumentParser(description="Text-to-SQL Benchmark - 阿里百炼API")
    parser.add_argument("--mock", action="store_true", help="使用Mock客户端测试流程")
    parser.add_argument("--method", type=str, choices=["zero_shot", "few_shot", "cot"], help="只运行指定方法")
    parser.add_argument("--output", type=str, default="results", help="结果输出目录")
    args = parser.parse_args()

    print("="*50)
    print("Text-to-SQL Prompt Engineering Benchmark")
    print("使用阿里百炼API (glm-5)")
    print("="*50)

    # 初始化
    runner = BenchmarkRunner("tests/benchmark_data.json")

    # 设置LLM客户端
    if args.mock:
        print("使用Mock客户端（测试模式）")
        runner.set_llm_client(MockLLMClient())
    else:
        client = LLMClient()
        if not client.api_key:
            print("错误: 请设置DASHSCOPE_API_KEY环境变量")
            print("示例: export DASHSCOPE_API_KEY='your-key'")
            print("或使用 --mock 参数测试流程")
            sys.exit(1)
        runner.set_llm_client(client)
        print(f"LLM客户端已连接: {client.api_base} / {client.model}")

    # 运行实验
    print(f"\n测试集: {len(runner.test_cases)} 个问题")

    if args.method:
        print(f"只运行方法: {args.method}")
        if not runner.evaluator.connect():
            print("数据库连接失败")
            sys.exit(1)
        result = runner.run_method(args.method)
        runner.evaluator.close()
        results = [result]
    else:
        skip_db = args.mock  # Mock模式跳过数据库评估
        results = runner.run_all_methods(skip_db_eval=skip_db)

    # 显示结果
    if not args.mock:
        print_results_table(results)
    else:
        print("\n=== Prompt生成测试结果 ===")
        for r in results:
            print(f"{r['method']}: {r['total_cases']} prompts generated")

    # 保存结果
    runner.save_results(results, args.output)

    print("\n实验完成!")
    return results


if __name__ == "__main__":
    main()