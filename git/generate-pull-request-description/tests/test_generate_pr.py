import contextlib
import importlib.util
import io
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx
from openai import AuthenticationError, BadRequestError, NotFoundError, RateLimitError


class GenerateDescriptionErrorTests(unittest.TestCase):
    def setUp(self):
        path = Path(__file__).resolve().parents[1] / "generate_pr.py"
        spec = importlib.util.spec_from_file_location("generate_pr", path)
        self.module = importlib.util.module_from_spec(spec)
        with patch("sys.argv", [str(path), "test-key"]):
            spec.loader.exec_module(self.module)
        self.addCleanup(self.module.client.close)

    def test_api_errors_include_diagnostics_and_recovery_guidance(self):
        cases = [
            (NotFoundError, 404, {"code": "model_not_found"},
             "not found or not accessible", "--model <enabled-model>"),
            (NotFoundError, 404, {"error": {"code": "model_not_found"}},
             "not found or not accessible", "--model <enabled-model>"),
            (BadRequestError, 400, {"code": "model_not_found"},
             "not found or not accessible", "--model <enabled-model>"),
            (NotFoundError, 404, None,
             "OpenAI API error", "verify OPENAI_BASE_URL"),
            (RateLimitError, 429, {"code": "insufficient_quota"},
             "quota exceeded", "Check billing/credits"),
            (RateLimitError, 429, {"code": "rate_limit_exceeded"},
             "Rate limited", "Retry shortly"),
            (AuthenticationError, 401, {"code": "invalid_api_key"},
             "authentication failed", "Verify OPENAI_API_KEY"),
            (BadRequestError, 400, {"code": "invalid_request"},
             "Invalid request", "Check the provider message"),
        ]
        for error_type, status, body, summary, guidance in cases:
            with self.subTest(status=status, body=body):
                request = httpx.Request("POST", "https://custom.example/v1/chat/completions")
                response = httpx.Response(
                    status, request=request, headers={"x-request-id": "req-test"}
                )
                error = error_type("Provider explanation", response=response, body=body)
                stderr = io.StringIO()
                stdout = io.StringIO()
                with patch.dict("os.environ", {"OPENAI_MODEL": "test-model"}), \
                        patch.object(self.module.client.chat.completions, "create", side_effect=error), \
                        contextlib.redirect_stderr(stderr), \
                        contextlib.redirect_stdout(stdout):
                    with self.assertRaises(SystemExit) as raised:
                        self.module.generate_description("example diff")
                self.assertEqual(raised.exception.code, 1)
                self.assertEqual(stdout.getvalue(), "")
                output = stderr.getvalue()
                for expected in (
                    summary, guidance, f"Status: {status}",
                    f"URL: {request.url}", "Model: test-model",
                    "Provider message: Provider explanation", "Request ID: req-test",
                ):
                    self.assertIn(expected, output)
                code = self.module._error_code_from_exception(error)
                if code:
                    self.assertIn(f"Error code: {code}", output)


if __name__ == "__main__":
    unittest.main()
