from __future__ import annotations

from typing import Any, List
from urllib.parse import urlparse

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SaatDin API"
    app_version: str = "0.2.0"
    app_environment: str = "development"

    base_rate: float = 45.0
    jwt_secret: str = "replace-me-in-env"
    jwt_algorithm: str = "HS256"
    jwt_expiration_minutes: int = 60 * 24

    otp_ttl_seconds: int = 300
    otp_max_attempts: int = 5
    otp_send_cooldown_seconds: int = 30
    expose_debug_otp: bool = True
    sms_provider: str = "stub"

    supabase_db_url: str = ""

    # External API keys (optional; graceful fallback if missing)
    waqi_api_key: str = ""
    tomtom_api_key: str = ""
    news_api_key: str = ""

    trigger_poll_minutes: int = 15
    trigger_window_sample_slack: int = 1
    allow_static_trigger_fallback: bool = False

    # Fraud scoring (Isolation Forest)
    fraud_scoring_enabled: bool = True
    fraud_model_path: str = ""
    fraud_anomaly_threshold: float = -0.05
    fraud_fail_open: bool = True
    fraud_metrics_log_every_n: int = 25

    # Ambiguous-case LLM fallback (LangGraph + provider failover)
    fraud_llm_fallback_enabled: bool = True
    fraud_llm_ambiguity_margin: float = 0.07
    fraud_llm_trigger_confidence_min: float = 0.35
    fraud_llm_trigger_confidence_max: float = 0.75
    fraud_llm_provider_order: str = "groq,gemini"
    fraud_llm_request_timeout_seconds: int = 8
    fraud_llm_max_retries_per_provider: int = 1
    fraud_llm_max_output_tokens: int = 350
    groq_api_key: str = ""
    groq_model: str = "llama-3.3-70b-versatile"
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"

    # Co-claim cluster graph detection
    co_claim_graph_enabled: bool = True
    co_claim_graph_schedule_hours: int = 24
    co_claim_graph_lookback_days: int = 30
    co_claim_graph_time_bucket_minutes: int = 10
    co_claim_graph_min_edge_support: int = 2
    co_claim_graph_recency_half_life_days: float = 7.0
    co_claim_graph_min_cluster_members: int = 3
    co_claim_graph_medium_risk_threshold: float = 0.50
    co_claim_graph_high_risk_threshold: float = 0.75
    co_claim_graph_max_clusters_per_run: int = 250

    # Cell-tower validation signal
    tower_validation_enabled: bool = True
    tower_signal_freshness_minutes: int = 30
    tower_signal_max_neighbors: int = 8
    tower_validation_score_weight: float = 0.12
    tower_validation_adjustment_cap: float = 0.12
    tower_validation_distance_match_km: float = 3.0
    tower_validation_distance_mismatch_km: float = 12.0

    # Motion signal validation
    motion_validation_enabled: bool = True
    motion_signal_freshness_minutes: int = 30
    motion_min_window_seconds: int = 60
    motion_min_sample_count: int = 12
    motion_min_distance_meters: float = 25.0
    motion_max_speed_mps: float = 33.0
    motion_validation_score_weight: float = 0.10
    motion_validation_adjustment_cap: float = 0.10
    motion_signal_retention_days: int = 14

    # Admin review surface
    admin_token: str = "saatdin-admin-local"
    admin_username: str = "admin"
    admin_password: str = "saatdin-local"

    # Payout sandbox / Razorpay
    payout_provider_mode: str = "sandbox"
    razorpay_key_id: str = ""
    razorpay_key_secret: str = ""
    allow_client_reported_premium_payments: bool = True

    # Authoritative Spring billing service
    billing_service_enabled: bool = False
    billing_service_url: str = "http://localhost:8082"
    billing_service_api_key: str = ""
    billing_request_timeout_seconds: float = 2.0
    billing_allow_private_http: bool = False

    # Adversarial defense — claim velocity spike detection
    claim_velocity_spike_threshold: int = 15
    claim_velocity_spike_window_minutes: int = 10
    # Adversarial defense — new account velocity hold
    new_account_hold_days: int = 7

    cors_origins: List[str] = [
        "http://localhost",
        "http://localhost:3000",
        "http://localhost:8080",
    ]
    cors_allow_origin_regex: str = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    model_config = SettingsConfigDict(env_file=(".env", "backend/.env"), extra="ignore")

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_cors_origins(cls, value: Any) -> List[str]:
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @field_validator("fraud_llm_provider_order", mode="before")
    @classmethod
    def _normalize_llm_provider_order(cls, value: Any) -> str:
        if not isinstance(value, str):
            return "groq,gemini"
        parts = [item.strip().lower() for item in value.split(",") if item.strip()]
        if not parts:
            return "groq,gemini"
        deduped: list[str] = []
        for item in parts:
            if item in {"groq", "gemini"} and item not in deduped:
                deduped.append(item)
        return ",".join(deduped or ["groq", "gemini"])

    @field_validator(
        "co_claim_graph_schedule_hours",
        "co_claim_graph_lookback_days",
        "co_claim_graph_time_bucket_minutes",
        "co_claim_graph_min_edge_support",
        "co_claim_graph_min_cluster_members",
        "co_claim_graph_max_clusters_per_run",
        "tower_signal_freshness_minutes",
        "tower_signal_max_neighbors",
        "motion_signal_freshness_minutes",
        "motion_min_window_seconds",
        "motion_min_sample_count",
        "motion_signal_retention_days",
        "trigger_poll_minutes",
        "trigger_window_sample_slack",
        mode="before",
    )
    @classmethod
    def _coerce_positive_ints(cls, value: Any) -> int:
        parsed = int(value)
        return max(1, parsed)

    @field_validator(
        "co_claim_graph_recency_half_life_days",
        "tower_validation_score_weight",
        "tower_validation_adjustment_cap",
        "tower_validation_distance_match_km",
        "tower_validation_distance_mismatch_km",
        "motion_min_distance_meters",
        "motion_max_speed_mps",
        "motion_validation_score_weight",
        "motion_validation_adjustment_cap",
        "billing_request_timeout_seconds",
        mode="before",
    )
    @classmethod
    def _coerce_positive_float(cls, value: Any) -> float:
        parsed = float(value)
        return max(0.1, parsed)

    @field_validator("co_claim_graph_medium_risk_threshold", "co_claim_graph_high_risk_threshold", mode="before")
    @classmethod
    def _coerce_threshold(cls, value: Any) -> float:
        parsed = float(value)
        return max(0.0, min(1.0, parsed))

    @property
    def fraud_model_file_path(self):
        from pathlib import Path

        if self.fraud_model_path:
            configured = Path(self.fraud_model_path)
            if configured.is_absolute():
                return configured

            project_root = Path(__file__).resolve().parents[3]
            backend_root = Path(__file__).resolve().parents[2]
            candidates = [
                project_root / configured,
                backend_root / configured,
            ]
            for candidate in candidates:
                if candidate.exists():
                    return candidate
            return candidates[0]

        project_root = Path(__file__).resolve().parents[3]
        backend_root = Path(__file__).resolve().parents[2]
        candidates = [
            backend_root / "models" / "fraud" / "fraud_iforest_latest.joblib",
            backend_root / "models" / "fraud" / "fraud_iforest_v1.joblib",
            project_root / "backend" / "models" / "fraud" / "fraud_iforest_latest.joblib",
            project_root / "backend" / "models" / "fraud" / "fraud_iforest_v1.joblib",
        ]
        for candidate in candidates:
            if candidate.exists():
                return candidate
        return candidates[0]

    @property
    def fraud_llm_provider_sequence(self) -> List[str]:
        parts = [item.strip().lower() for item in self.fraud_llm_provider_order.split(",") if item.strip()]
        sequence: list[str] = []
        for item in parts:
            if item in {"groq", "gemini"} and item not in sequence:
                sequence.append(item)
        if sequence:
            return sequence
        return ["groq", "gemini"]

    @property
    def co_claim_high_threshold(self) -> float:
        return max(self.co_claim_graph_medium_risk_threshold, self.co_claim_graph_high_risk_threshold)

    @property
    def co_claim_medium_threshold(self) -> float:
        return min(self.co_claim_graph_medium_risk_threshold, self.co_claim_high_threshold)


settings = Settings()


def validate_runtime_settings(runtime_settings: Any = settings) -> None:
    environment = str(getattr(runtime_settings, "app_environment", "development")).strip().lower()
    payout_mode = str(getattr(runtime_settings, "payout_provider_mode", "sandbox")).strip().lower()
    errors: list[str] = []

    if payout_mode != "sandbox":
        errors.append("PAYOUT_PROVIDER_MODE must remain sandbox until a live payout adapter is implemented")

    if environment not in {"production", "prod"}:
        if errors:
            raise RuntimeError("Unsafe runtime configuration: " + "; ".join(errors))
        return

    jwt_secret = str(getattr(runtime_settings, "jwt_secret", ""))
    admin_password = str(getattr(runtime_settings, "admin_password", ""))
    cors_origins = [str(item).lower() for item in getattr(runtime_settings, "cors_origins", [])]
    cors_regex = str(getattr(runtime_settings, "cors_allow_origin_regex", "")).lower()

    if not str(getattr(runtime_settings, "supabase_db_url", "")).strip():
        errors.append("SUPABASE_DB_URL is required")
    if jwt_secret == "replace-me-in-env" or len(jwt_secret) < 32:
        errors.append("JWT_SECRET must be a unique value of at least 32 characters")
    if bool(getattr(runtime_settings, "expose_debug_otp", True)):
        errors.append("EXPOSE_DEBUG_OTP must be false")
    sms_provider = str(getattr(runtime_settings, "sms_provider", "stub")).strip().lower()
    errors.append(
        "a production SMS provider adapter must be implemented"
        if sms_provider == "stub"
        else f"SMS_PROVIDER={sms_provider!r} has no implemented adapter"
    )
    if str(getattr(runtime_settings, "admin_username", "admin")).strip().lower() == "admin":
        errors.append("ADMIN_USERNAME must not use the default")
    if not admin_password.startswith("pbkdf2_sha256$"):
        errors.append("ADMIN_PASSWORD must be stored as a PBKDF2 hash")
    if bool(getattr(runtime_settings, "allow_client_reported_premium_payments", True)):
        errors.append("ALLOW_CLIENT_REPORTED_PREMIUM_PAYMENTS must be false")
    if bool(getattr(runtime_settings, "allow_static_trigger_fallback", True)):
        errors.append("ALLOW_STATIC_TRIGGER_FALLBACK must be false")

    billing_enabled = bool(getattr(runtime_settings, "billing_service_enabled", False))
    if not billing_enabled:
        errors.append("BILLING_SERVICE_ENABLED must be true")
    else:
        billing_key = str(getattr(runtime_settings, "billing_service_api_key", ""))
        if len(billing_key) < 32:
            errors.append("BILLING_SERVICE_API_KEY must contain at least 32 characters")
        billing_url = str(getattr(runtime_settings, "billing_service_url", ""))
        parsed_billing_url = urlparse(billing_url)
        allow_private_http = bool(getattr(runtime_settings, "billing_allow_private_http", False))
        hostname = (parsed_billing_url.hostname or "").lower()
        private_hostname = bool(hostname) and ("." not in hostname or hostname.endswith(".internal"))
        if parsed_billing_url.scheme != "https" and not (allow_private_http and private_hostname):
            errors.append(
                "BILLING_SERVICE_URL must use HTTPS unless private HTTP is explicitly allowed"
            )
    if any("localhost" in origin or "127.0.0.1" in origin for origin in cors_origins):
        errors.append("CORS_ORIGINS must not contain local development origins")
    if "localhost" in cors_regex or "127\\.0\\.0\\.1" in cors_regex:
        errors.append("CORS_ALLOW_ORIGIN_REGEX must not allow local development origins")

    if errors:
        raise RuntimeError("Unsafe production configuration: " + "; ".join(errors))
