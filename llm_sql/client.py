import os
import requests
from dotenv import load_dotenv

# 强制重新加载.env文件（override=True 确保覆盖已有环境变量）
load_dotenv('.env', override=True)

# 禁用代理
os.environ['NO_PROXY'] = '*'
os.environ.pop('HTTP_PROXY', None)
os.environ.pop('HTTPS_PROXY', None)
os.environ.pop('http_proxy', None)
os.environ.pop('https_proxy', None)

class LLMClient:
    """统一LLM客户端封装 - 支持阿里百炼OpenAI兼容API"""

    def __init__(self, provider: str = "bailian"):
        self.provider = provider
        # 从.env读取配置
        self.api_key = os.getenv("DASHSCOPE_API_KEY", "")
        self.api_base = os.getenv("DASHSCOPE_API_BASE", "https://coding.dashscope.aliyuncs.com/v1")
        self.model = os.getenv("DASHSCOPE_MODEL", "glm-5")
        self.enable_thinking = os.getenv("ENABLE_THINKING", "false").lower() == "true"

    def generate(self, prompt: str) -> str:
        """生成响应"""
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        data = {
            "model": self.model,
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0,
            "max_tokens": 2000
        }

        # 如果启用thinking模式，添加extra_body参数
        if self.enable_thinking:
            data["enable_thinking"] = True

        try:
            response = requests.post(
                f"{self.api_base}/chat/completions",
                headers=headers,
                json=data,
                timeout=60
            )
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
        except Exception as e:
            print(f"API调用失败: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"响应内容: {e.response.text}")
            return ""

    def test_connection(self) -> bool:
        """测试连接"""
        if not self.api_key:
            print("请设置DASHSCOPE_API_KEY环境变量")
            return False
        try:
            result = self.generate("Hello")
            return bool(result)
        except:
            return False


class MockLLMClient:
    """Mock客户端（用于测试，不调用真实API）"""

    def __init__(self):
        self.call_count = 0

    def generate(self, prompt: str) -> str:
        self.call_count += 1
        # 返回简单的SQL（仅用于测试流程）
        return "SELECT * FROM Employee LIMIT 10;"