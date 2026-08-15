from __future__ import annotations

import os
import unittest
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from backend.app.core.config import Settings, validate_runtime_settings
from backend.app.main import lifespan


class RuntimeConfigurationTests(unittest.IsolatedAsyncioTestCase):
    async def test_production_requires_authoritative_billing_service(self) -> None:
        production_settings = SimpleNamespace(
            app_environment="production",
            supabase_db_url="postgresql://example.invalid/saatdin",
            jwt_secret="x" * 64,
            expose_debug_otp=False,
            sms_provider="twilio",
            admin_username="operations",
            admin_password="pbkdf2_sha256$1$salt$digest",
            allow_client_reported_premium_payments=False,
            allow_static_trigger_fallback=False,
            payout_provider_mode="sandbox",
            cors_origins=["https://app.example.com"],
            cors_allow_origin_regex=r"^https://app\.example\.com$",
            billing_service_enabled=False,
        )

        with self.assertRaisesRegex(RuntimeError, "BILLING_SERVICE_ENABLED"):
            validate_runtime_settings(production_settings)

    async def test_production_rejects_short_billing_key_and_public_http_url(self) -> None:
        production_settings = SimpleNamespace(
            app_environment="production",
            supabase_db_url="postgresql://example.invalid/saatdin",
            jwt_secret="x" * 64,
            expose_debug_otp=False,
            sms_provider="twilio",
            admin_username="operations",
            admin_password="pbkdf2_sha256$1$salt$digest",
            allow_client_reported_premium_payments=False,
            allow_static_trigger_fallback=False,
            payout_provider_mode="sandbox",
            cors_origins=["https://app.example.com"],
            cors_allow_origin_regex=r"^https://app\.example\.com$",
            billing_service_enabled=True,
            billing_service_url="http://billing.example.com",
            billing_service_api_key="short",
            billing_allow_private_http=False,
        )

        with self.assertRaisesRegex(RuntimeError, "BILLING_SERVICE_API_KEY"):
            validate_runtime_settings(production_settings)

    async def test_cors_origins_load_from_documented_json_environment_value(self) -> None:
        with patch.dict(
            os.environ,
            {"CORS_ORIGINS": '["https://app.example.com","https://admin.example.com"]'},
        ):
            loaded = Settings(_env_file=None)

        self.assertEqual(
            loaded.cors_origins,
            ["https://app.example.com", "https://admin.example.com"],
        )

    async def test_production_rejects_named_but_unimplemented_sms_provider(self) -> None:
        production_settings = SimpleNamespace(
            app_environment="production",
            supabase_db_url="postgresql://example.invalid/saatdin",
            jwt_secret="x" * 64,
            expose_debug_otp=False,
            sms_provider="twilio",
            admin_username="operations",
            admin_password="pbkdf2_sha256$1$salt$digest",
            allow_client_reported_premium_payments=False,
            allow_static_trigger_fallback=False,
            payout_provider_mode="sandbox",
            cors_origins=["https://app.example.com"],
            cors_allow_origin_regex=r"^https://app\.example\.com$",
        )

        with self.assertRaisesRegex(RuntimeError, "no implemented adapter"):
            validate_runtime_settings(production_settings)

    async def test_production_rejects_insecure_defaults_before_startup(self) -> None:
        unsafe_settings = SimpleNamespace(
            app_environment="production",
            supabase_db_url="",
            jwt_secret="replace-me-in-env",
            expose_debug_otp=True,
            sms_provider="stub",
            admin_username="admin",
            admin_password="saatdin-local",
            allow_client_reported_premium_payments=True,
            allow_static_trigger_fallback=True,
            payout_provider_mode="sandbox",
            cors_origins=["http://localhost:3000"],
            cors_allow_origin_regex=r"^https?://localhost$",
        )
        with (
            patch("backend.app.main.settings", unsafe_settings),
            patch("backend.app.main.init_db", new=AsyncMock()),
            patch("backend.app.main.refresh_zone_cache", new=AsyncMock()),
            patch("backend.app.main.initialize_premium_model"),
            patch("backend.app.main.initialize_fraud_model"),
            patch("backend.app.main.initialize_api_client", new=AsyncMock()),
            patch("backend.app.main.trigger_monitor.start", new=AsyncMock()),
            patch("backend.app.main.co_claim_cluster_monitor.start", new=AsyncMock()),
            patch("backend.app.main.co_claim_cluster_monitor.stop", new=AsyncMock()),
            patch("backend.app.main.trigger_monitor.stop", new=AsyncMock()),
            patch("backend.app.main.close_api_client", new=AsyncMock()),
            patch("backend.app.main.close_db", new=AsyncMock()),
        ):
            with self.assertRaisesRegex(RuntimeError, "Unsafe production configuration"):
                async with lifespan(None):
                    pass


if __name__ == "__main__":
    unittest.main()
