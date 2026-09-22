import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import HTTPException  # noqa: E402

from app import main, quota  # noqa: E402


def _request(text="Il regardait par la fenetre."):
    return main.ExtractRequest(text=text, sourceLang="fr", targetLang="cs")


class QuotaTest(unittest.TestCase):
    def setUp(self):
        self.quota = quota.Quota(":memory:")

    def test_allows_up_to_the_daily_limit(self):
        for _ in range(3):
            self.quota.consume("device-a", daily_limit=3)
        with self.assertRaises(quota.QuotaExceeded):
            self.quota.consume("device-a", daily_limit=3)

    def test_devices_are_tracked_separately(self):
        for _ in range(3):
            self.quota.consume("device-a", daily_limit=3)
        # device-b has its own, still-fresh allowance.
        self.quota.consume("device-b", daily_limit=3)

    def test_zero_or_negative_limit_disables_the_quota(self):
        for _ in range(50):
            self.assertEqual(self.quota.consume("device-a", daily_limit=0), 0)

    def test_returns_how_many_pages_are_left(self):
        self.assertEqual(self.quota.consume("device-a", daily_limit=5), 4)
        self.assertEqual(self.quota.consume("device-a", daily_limit=5), 3)

    def test_a_rejected_call_does_not_get_registered(self):
        self.quota.consume("device-a", daily_limit=1)
        with self.assertRaises(quota.QuotaExceeded):
            self.quota.consume("device-a", daily_limit=1)
        # Raising the limit afterwards shows only the one page really used.
        self.assertEqual(self.quota.consume("device-a", daily_limit=2), 0)


class ExtractAuthAndQuotaTest(unittest.TestCase):
    def setUp(self):
        self._original_quota = main._quota
        self._original_app_key = main.APP_KEY
        self._original_limit = main.DAILY_PAGE_LIMIT
        main._quota = quota.Quota(":memory:")
        main.APP_KEY = ""
        main.DAILY_PAGE_LIMIT = 20
        main.EXTRACTORS[main.PROVIDER] = lambda **_: []
        self.addCleanup(lambda: setattr(main, "_quota", self._original_quota))
        self.addCleanup(lambda: setattr(main, "APP_KEY", self._original_app_key))
        self.addCleanup(lambda: setattr(main, "DAILY_PAGE_LIMIT", self._original_limit))

    def test_missing_device_id_is_rejected(self):
        with self.assertRaises(HTTPException) as ctx:
            main.extract(_request(), x_device_id=None, x_app_key=None)
        self.assertEqual(ctx.exception.status_code, 401)
        self.assertEqual(ctx.exception.detail["reason"], "unauthorized")

    def test_a_device_id_is_enough_when_no_app_key_is_configured(self):
        main.extract(_request(), x_device_id="device-a", x_app_key=None)  # no exception

    def test_app_key_is_required_once_configured(self):
        main.APP_KEY = "s3cret"

        with self.assertRaises(HTTPException) as ctx:
            main.extract(_request(), x_device_id="device-a", x_app_key=None)
        self.assertEqual(ctx.exception.status_code, 401)

        with self.assertRaises(HTTPException) as ctx:
            main.extract(_request(), x_device_id="device-a", x_app_key="wrong")
        self.assertEqual(ctx.exception.status_code, 401)

        main.extract(_request(), x_device_id="device-a", x_app_key="s3cret")  # no exception

    def test_quota_exceeded_is_a_429_with_a_reason(self):
        main.DAILY_PAGE_LIMIT = 2
        main.extract(_request(), x_device_id="device-a", x_app_key=None)
        main.extract(_request(), x_device_id="device-a", x_app_key=None)

        with self.assertRaises(HTTPException) as ctx:
            main.extract(_request(), x_device_id="device-a", x_app_key=None)
        self.assertEqual(ctx.exception.status_code, 429)
        self.assertEqual(ctx.exception.detail["reason"], "quota_exceeded")

    def test_each_device_has_its_own_quota(self):
        main.DAILY_PAGE_LIMIT = 1
        main.extract(_request(), x_device_id="device-a", x_app_key=None)
        main.extract(_request(), x_device_id="device-b", x_app_key=None)  # different device, fine

    def test_zero_limit_means_unlimited(self):
        main.DAILY_PAGE_LIMIT = 0
        for _ in range(30):
            main.extract(_request(), x_device_id="device-a", x_app_key=None)


if __name__ == "__main__":
    unittest.main()
