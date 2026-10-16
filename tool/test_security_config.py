"""Regression tests for repository-managed web and Firebase hardening."""

from __future__ import annotations

import json
import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class SecurityConfigTest(unittest.TestCase):
    """Guards security-sensitive configuration against permissive drift."""

    def test_storage_cors_has_no_wildcard_and_lists_known_origins(self) -> None:
        entries = json.loads((ROOT / "cors.json").read_text(encoding="utf-8"))
        origins = {origin for entry in entries for origin in entry["origin"]}

        self.assertNotIn("*", origins)
        self.assertTrue(
            {
                "https://heldensync-ccf0b.web.app",
                "https://heldensync-test.web.app",
                "http://localhost:5000",
                "http://127.0.0.1:5000",
            }.issubset(origins)
        )

    def test_storage_uploads_accept_only_explicit_image_mime_types(self) -> None:
        rules = (ROOT / "storage.rules").read_text(encoding="utf-8")

        self.assertNotIn("image/.*", rules)
        self.assertIn("image/png", rules)
        self.assertIn("image/jpeg", rules)
        self.assertIn("image/webp", rules)

    def test_each_hosting_target_sets_required_security_headers(self) -> None:
        config = json.loads((ROOT / "firebase.json").read_text(encoding="utf-8"))
        required = {
            "Content-Security-Policy",
            "X-Content-Type-Options",
            "Referrer-Policy",
            "Permissions-Policy",
            "X-Frame-Options",
        }

        for hosting in config["hosting"]:
            headers = {
                item["key"]
                for rule in hosting["headers"]
                if rule["source"] == "**"
                for item in rule["headers"]
            }
            self.assertTrue(required.issubset(headers), hosting["target"])

    def test_index_html_is_never_cached_for_each_hosting_target(self) -> None:
        config = json.loads((ROOT / "firebase.json").read_text(encoding="utf-8"))

        for hosting in config["hosting"]:
            index_rules = [
                rule for rule in hosting["headers"] if rule["source"] == "/index.html"
            ]
            self.assertEqual(len(index_rules), 1, hosting["target"])
            values = {item["key"]: item["value"] for item in index_rules[0]["headers"]}
            self.assertEqual(
                values.get("Cache-Control"),
                "no-cache, no-store, must-revalidate",
                hosting["target"],
            )

    def test_release_builds_require_app_check_and_explicit_hosting_target(self) -> None:
        workflow = (ROOT / ".github/workflows/flutter-tests.yml").read_text(
            encoding="utf-8"
        )
        deploy_script = (ROOT / "tool/deploy_web.ps1").read_text(encoding="utf-8")

        self.assertIn("FIREBASE_APP_CHECK_SITE_KEY", workflow)
        self.assertIn("--dart-define=FIREBASE_APP_CHECK_SITE_KEY", workflow)
        self.assertIn("[ValidateSet('test', 'production')]", deploy_script)
        self.assertIn("--only \"hosting:$Target\"", deploy_script)
        self.assertIn("feedbackApiTest", deploy_script)
        self.assertIn("feedbackApi", deploy_script)
        self.assertIn("--dart-define=FEEDBACK_API_URL", deploy_script)
        self.assertIn("REGISTRATION_INVITE_API_URL", workflow)
        self.assertIn("--dart-define=REGISTRATION_INVITE_API_URL", workflow)
        self.assertIn("registrationInviteApi", deploy_script)
        for variable in (
            "LEGAL_RESPONSIBLE_NAME",
            "LEGAL_STREET_ADDRESS",
            "LEGAL_POSTAL_CODE",
            "LEGAL_CITY",
            "LEGAL_COUNTRY",
            "LEGAL_CONTACT_EMAIL",
        ):
            self.assertIn(variable, workflow)
            self.assertIn(f"--dart-define={variable}", workflow)
            self.assertIn(variable, deploy_script)
        self.assertNotIn("firebase deploy --only hosting\n", deploy_script)


if __name__ == "__main__":
    unittest.main()
