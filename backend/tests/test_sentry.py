import json
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import sentry_sdk  # noqa: E402
from fastapi import HTTPException  # noqa: E402

from app import main, quota  # noqa: E402


class ConfigureSentryTest(unittest.TestCase):
    def setUp(self):
        # Isolates each test from whatever client an earlier one (in this
        # file or another) left initialized.
        sentry_sdk.get_global_scope().set_client(None)

    def tearDown(self):
        sentry_sdk.get_global_scope().set_client(None)

    def test_empty_dsn_does_not_initialize_the_client(self):
        main.configure_sentry("")
        self.assertFalse(sentry_sdk.is_initialized())

    def test_a_dsn_initializes_the_client(self):
        main.configure_sentry("http://public@localhost:9999/1")
        self.assertTrue(sentry_sdk.is_initialized())

    def test_performance_tracing_is_off_and_pii_is_not_sent(self):
        main.configure_sentry("http://public@localhost:9999/1")
        options = sentry_sdk.get_client().options
        self.assertEqual(options["traces_sample_rate"], 0.0)
        self.assertFalse(options["send_default_pii"])
        self.assertEqual(options["max_request_body_size"], "never")
        # Regression check: local-variable capture on stack frames leaks the
        # scanned page text (it's a local in extract()) into every captured
        # exception, regardless of max_request_body_size -- verified by
        # hand before this option was added. See the comment in
        # configure_sentry().
        self.assertFalse(options["include_local_variables"])

    def test_a_failure_does_not_leak_the_scanned_text_into_the_event(self):
        main.configure_sentry("http://public@localhost:9999/1")
        captured = []
        sentry_sdk.get_client().options["before_send"] = (
            lambda event, hint: captured.append(event) or None
        )
        original_quota, original_key = main._quota, main.APP_KEY
        original_extractor = main.EXTRACTORS.get(main.PROVIDER)
        main._quota = quota.Quota(":memory:")
        main.APP_KEY = ""
        # Built at runtime, not a literal, so it can't appear in the *source
        # code* Sentry also attaches around each frame -- that would be a
        # false positive here, not the runtime-data leak this test targets.
        secret_text = "".join(reversed("etavirp namor nom ed etxet nu"))
        main.EXTRACTORS[main.PROVIDER] = lambda **_: (_ for _ in ()).throw(RuntimeError("boom"))
        try:
            with self.assertRaises(HTTPException):
                main.extract(
                    main.ExtractRequest(text=secret_text, sourceLang="fr", targetLang="cs"),
                    x_device_id="dev-a",
                    x_app_key=None,
                )
        finally:
            main._quota, main.APP_KEY = original_quota, original_key
            main.EXTRACTORS[main.PROVIDER] = original_extractor

        self.assertEqual(len(captured), 1)
        self.assertNotIn(secret_text, json.dumps(captured[0]))


class ScrubBeforeSendTest(unittest.TestCase):
    def test_removes_the_app_key_header_case_insensitively(self):
        event = {"request": {"headers": {"X-App-Key": "s3cret", "X-Device-Id": "dev-a"}}}

        scrubbed = main._scrub_before_send(event, {})

        self.assertEqual(scrubbed["request"]["headers"]["X-App-Key"], "[Filtered]")
        # Not sensitive -- kept, it's what makes issues groupable by device.
        self.assertEqual(scrubbed["request"]["headers"]["X-Device-Id"], "dev-a")

    def test_tolerates_an_event_with_no_request_or_headers(self):
        self.assertEqual(main._scrub_before_send({}, {}), {})
        self.assertEqual(
            main._scrub_before_send({"request": {}}, {}), {"request": {}}
        )


if __name__ == "__main__":
    unittest.main()
