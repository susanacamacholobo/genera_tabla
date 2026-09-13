import json
from pathlib import Path
from typing import Any

import pytest


@pytest.fixture
def simple_entity_model() -> dict[str, Any]:
    fixture = Path(__file__).parent / "fixtures" / "simple_entity.json"
    return json.loads(fixture.read_text(encoding="utf-8"))
