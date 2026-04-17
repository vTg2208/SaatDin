from __future__ import annotations

import re
from typing import Iterable, Optional

_STOPWORDS = {
    "the",
    "and",
    "for",
    "with",
    "from",
    "that",
    "this",
    "into",
    "near",
    "after",
    "before",
    "road",
    "area",
    "zone",
    "city",
    "main",
    "street",
}

_CATEGORY_KEYWORDS = {
    "curfew": {"curfew", "police", "section144", "restriction"},
    "bandh": {"bandh", "shutdown", "closedown", "closure"},
    "strike": {"strike", "protest", "union", "demonstration"},
    "lockdown": {"lockdown", "sealed", "containment", "barricade"},
}


def _tokenize(text: str) -> list[str]:
    collapsed = re.sub(r"[^a-zA-Z0-9]+", " ", text.lower())
    return [token for token in collapsed.split() if len(token) > 2 and token not in _STOPWORDS]


def extract_event_keywords(text: str) -> list[str]:
    tokens = _tokenize(text)
    found: set[str] = set()
    for token in tokens:
        for category, keywords in _CATEGORY_KEYWORDS.items():
            if token in keywords:
                found.add(category)
        found.add(token)
    return sorted(found)


def classify_disruption_text(text: str) -> Optional[dict]:
    keywords = extract_event_keywords(text)
    if not keywords:
        return None

    best_category = None
    best_score = 0
    keyword_set = set(keywords)
    for category, members in _CATEGORY_KEYWORDS.items():
        overlap = len(keyword_set.intersection(members | {category}))
        if overlap > best_score:
            best_category = category
            best_score = overlap

    if best_category is None:
        return None

    confidence = min(0.95, 0.35 + (best_score * 0.2))
    return {
        "category": best_category,
        "keywords": keywords,
        "confidence": round(confidence, 3),
    }


def disruption_similarity(left_keywords: Iterable[str], right_keywords: Iterable[str]) -> float:
    left = {item.strip().lower() for item in left_keywords if str(item).strip()}
    right = {item.strip().lower() for item in right_keywords if str(item).strip()}
    if not left or not right:
        return 0.0
    overlap = left.intersection(right)
    union = left.union(right)
    return round(len(overlap) / max(1, len(union)), 3)
