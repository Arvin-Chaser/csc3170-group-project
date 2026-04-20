import mysql.connector
from .config import DB_CONFIG

class SQLEvaluator:
    """基于Execution Accuracy的SQL评估器"""

    def __init__(self):
        self.conn = None

    def connect(self):
        """建立数据库连接"""
        try:
            self.conn = mysql.connector.connect(**DB_CONFIG)
            return True
        except Exception as e:
            print(f"数据库连接失败: {e}")
            return False

    def execute_sql(self, sql: str) -> list:
        """执行SQL并返回结果"""
        if self.conn is None:
            print("数据库未连接!")
            return None
        try:
            cursor = self.conn.cursor()
            # 清理SQL中的多余空白
            clean_sql = ' '.join(sql.split())
            cursor.execute(clean_sql)
            result = cursor.fetchall()
            cursor.close()
            return result
        except Exception as e:
            print(f"SQL执行失败: {e}")
            print(f"SQL内容: {sql[:100]}")
            # 尝试重新连接
            try:
                self.connect()
            except:
                pass
            return None

    def normalize_result(self, result: list) -> list:
        """标准化结果用于比较（处理浮点数精度问题）"""
        if result is None:
            return None
        normalized = []
        for row in result:
            normalized_row = []
            for val in row:
                if isinstance(val, float):
                    normalized_row.append(round(val, 2))
                else:
                    normalized_row.append(val)
            normalized.append(tuple(normalized_row))
        return sorted(normalized)

    def compare_results(self, result1: list, result2: list) -> bool:
        """比较两个查询结果是否相同"""
        if result1 is None or result2 is None:
            return False
        # 标准化后比较
        return self.normalize_result(result1) == self.normalize_result(result2)

    def evaluate(self, predicted_sql: str, gold_sql: str) -> dict:
        """评估预测SQL的正确性"""
        pred_result = self.execute_sql(predicted_sql)
        gold_result = self.execute_sql(gold_sql)

        execution_success = pred_result is not None
        result_match = self.compare_results(pred_result, gold_result)

        return {
            "execution_success": execution_success,
            "result_match": result_match,
            "accuracy": 1 if result_match else 0,
            "predicted_result": pred_result,
            "gold_result": gold_result
        }

    def close(self):
        if self.conn:
            self.conn.close()