"""Shared fixtures for backend tests."""
from __future__ import annotations

from unittest.mock import patch

import pytest
from backend.app.core import zone_cache


@pytest.fixture(autouse=True)
def _isolate_zone_cache():
    """Keep zone lookup deterministic across tests."""
    zone_map = {
        "560103": {
            "name": "Bellandur",
            "zone_risk_multiplier": 1.0,
            "dark_stores": {
                "Blinkit": True,
                "Zepto": True,
                "Swiggy_Instamart": True,
            },
        }
    }
    with (
        patch.object(zone_cache, "_ZONE_MAP", zone_map),
        patch.object(zone_cache, "_ZONE_NAME_INDEX", {"bellandur": "560103"}),
    ):
        yield
