import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import HTTPException  # noqa: E402

from app import main, quota  # noqa: E402


class _ProviderError(Exception):
    def __init__(self, status_code):
        super().__init__(f"provider said {status_code}")
        self.status_code = status_code


def _request():
    return main.ExtractRequest(text="Il regardait par la fenetre.", sourceLang="fr", targetLang="cs")


class ParseItemsTest(unittest.TestCase):
    def test_skips_malformed_items_and_keeps_the_rest(self):
        good = {"original": "regarder", "translation": "dívat se", "type": "word", "exampleSentence": "x"}
        missing_example = {"original": "a", "translation": "b", "type": "word"}
        bad_type = {"original": "a", "translation": "b", "type": "expression", "exampleSentence": "x"}

        items = main._parse_items([good, missing_example, bad_type, "not even a dict"])

        self.assertEqual([i.original for i in items], ["regarder"])

    def test_none_gives_empty_list(self):
        self.assertEqual(main._parse_items(None), [])


class ExtractErrorsTest(unittest.TestCase):
    def setUp(self):
        # Isolated from both the real quota file and any auth requirement,
        # so this class can focus on how provider failures are translated.
        self._original_quota = main._quota
        self._original_app_key = main.APP_KEY
        main._quota = quota.Quota(":memory:")
        main.APP_KEY = ""
        self.addCleanup(lambda: setattr(main, "_quota", self._original_quota))
        self.addCleanup(lambda: setattr(main, "APP_KEY", self._original_app_key))

    def _run_with(self, extractor):
        original = main.EXTRACTORS.get(main.PROVIDER)
        main.EXTRACTORS[main.PROVIDER] = extractor
        try:
            return main.extract(_request(), x_device_id="test-device")
        finally:
            main.EXTRACTORS[main.PROVIDER] = original

    def _raiser(self, exc):
        def extractor(**_):
            raise exc
        return extractor

    def test_rate_limit_becomes_429_not_500(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run_with(self._raiser(_ProviderError(429)))
        self.assertEqual(ctx.exception.status_code, 429)

    def test_other_provider_failures_become_502(self):
        for exc in (_ProviderError(500), RuntimeError("boom"), ValueError("bad json")):
            with self.subTest(exc=exc), self.assertRaises(HTTPException) as ctx:
                self._run_with(self._raiser(exc))
            self.assertEqual(ctx.exception.status_code, 502)

    def test_http_exceptions_from_the_extractor_pass_through(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run_with(self._raiser(HTTPException(502, "Groq did not return structured vocabulary")))
        self.assertEqual(ctx.exception.status_code, 502)
        self.assertEqual(ctx.exception.detail, "Groq did not return structured vocabulary")

    def test_provider_busy_detail_has_a_reason(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run_with(self._raiser(_ProviderError(429)))
        self.assertEqual(ctx.exception.detail["reason"], "provider_busy")

    def test_provider_error_detail_has_a_reason(self):
        with self.assertRaises(HTTPException) as ctx:
            self._run_with(self._raiser(RuntimeError("boom")))
        self.assertEqual(ctx.exception.detail["reason"], "provider_error")

    def test_success_returns_the_items(self):
        item = main.VocabItem(original="a", translation="b", type="word", exampleSentence="x")
        response = self._run_with(lambda **_: [item])
        self.assertEqual(response.items, [item])


class GroqRetryTest(unittest.TestCase):
    def _bad_request(self, code):
        import httpx
        import openai

        response = httpx.Response(400, request=httpx.Request("POST", "http://groq.test"))
        return openai.BadRequestError("nope", response=response, body={"code": code})

    def _client_that(self, *outcomes):
        calls = []

        class _Completions:
            def create(_self, **kwargs):
                calls.append(kwargs)
                outcome = outcomes[len(calls) - 1]
                if isinstance(outcome, Exception):
                    raise outcome
                return outcome

        class _Chat:
            completions = _Completions()

        class _Client:
            chat = _Chat()

        return _Client(), calls

    def _with_client(self, client):
        original = main._groq_client
        main._groq_client = lambda: client
        self.addCleanup(setattr, main, "_groq_client", original)

    def test_retries_tool_use_failed_then_succeeds(self):
        client, calls = self._client_that(
            self._bad_request("tool_use_failed"), self._bad_request("tool_use_failed"), "ok"
        )
        self._with_client(client)

        self.assertEqual(main._groq_create_with_retry(model="m"), "ok")
        self.assertEqual(len(calls), 3)

    def test_gives_up_after_three_attempts(self):
        import openai

        error = self._bad_request("tool_use_failed")
        client, calls = self._client_that(error, error, error)
        self._with_client(client)

        with self.assertRaises(openai.BadRequestError):
            main._groq_create_with_retry(model="m")
        self.assertEqual(len(calls), 3)

    def test_other_bad_requests_are_not_retried(self):
        import openai

        client, calls = self._client_that(self._bad_request("invalid_api_key"), "ok")
        self._with_client(client)

        with self.assertRaises(openai.BadRequestError):
            main._groq_create_with_retry(model="m")
        self.assertEqual(len(calls), 1)


if __name__ == "__main__":
    unittest.main()
