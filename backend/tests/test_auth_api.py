from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.api.auth import router as auth_router
from backend.app.core.security import hash_otp


class AuthApiTests(unittest.TestCase):
    def _client(self) -> TestClient:
        app = FastAPI()
        app.include_router(auth_router, prefix="/api/v1/auth")
        return TestClient(app)

    def test_send_otp_returns_debug_code_when_enabled(self) -> None:
        client = self._client()
        with (
            patch("backend.app.api.auth.get_otp", new=AsyncMock(return_value=None)),
            patch("backend.app.api.auth.save_otp", new=AsyncMock()),
            patch("backend.app.api.auth._send_sms", new=AsyncMock()),
            patch("backend.app.api.auth.generate_otp", return_value="123456"),
        ):
            response = client.post("/api/v1/auth/send-otp", json={"phoneNumber": "9876543210"})

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertEqual(payload["data"]["phoneNumber"], "9876543210")
        self.assertEqual(payload["data"]["debugOtp"], "123456")

    def test_verify_otp_returns_access_token(self) -> None:
        client = self._client()
        phone = "9876543210"
        expires_at = (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
        stored_otp = {
            "otp_hash": hash_otp(phone, "123456"),
            "attempts": 0,
            "expires_at": expires_at,
        }
        with (
            patch("backend.app.api.auth.get_otp", new=AsyncMock(return_value=stored_otp)),
            patch("backend.app.api.auth.delete_otp", new=AsyncMock()),
        ):
            response = client.post(
                "/api/v1/auth/verify-otp",
                json={"phoneNumber": phone, "otp": "123456"},
            )

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertTrue(payload["success"])
        self.assertIn("token", payload["data"])

    def test_verify_otp_rejects_invalid_code(self) -> None:
        client = self._client()
        phone = "9876543210"
        expires_at = (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
        stored_otp = {
            "otp_hash": hash_otp(phone, "123456"),
            "attempts": 0,
            "expires_at": expires_at,
        }
        with (
            patch("backend.app.api.auth.get_otp", new=AsyncMock(return_value=stored_otp)),
            patch("backend.app.api.auth.increment_otp_attempts", new=AsyncMock()),
        ):
            response = client.post(
                "/api/v1/auth/verify-otp",
                json={"phoneNumber": phone, "otp": "999999"},
            )

        self.assertEqual(response.status_code, 401)
        self.assertIn("Invalid or expired OTP", response.text)


if __name__ == "__main__":
    unittest.main()
