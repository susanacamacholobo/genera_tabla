import json
from pathlib import Path
from typing import Any

import pytest


def load_fixture(name: str) -> dict[str, Any]:
    fixture = Path(__file__).parent / "fixtures" / name
    return json.loads(fixture.read_text(encoding="utf-8"))


@pytest.fixture
def simple_entity_model() -> dict[str, Any]:
    return load_fixture("simple_entity.json")


@pytest.fixture(params=["one_to_one.json", "one_to_many.json", "many_to_many.json"])
def association_model(request: pytest.FixtureRequest) -> dict[str, Any]:
    return load_fixture(str(request.param))


@pytest.fixture
def one_to_many_model() -> dict[str, Any]:
    return load_fixture("one_to_many.json")
