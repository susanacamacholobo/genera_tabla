from collections.abc import Callable
from copy import deepcopy
from typing import Any

import pytest

from spring_generator import GenerationValidationError, ModelValidator


def issue_codes(model: dict[str, Any]) -> set[str]:
    return {item.code for item in ModelValidator().validate(model).issues}


def test_accepts_a_simple_entity(simple_entity_model: dict[str, Any]) -> None:
    result = ModelValidator().validate(simple_entity_model)

    assert result.valid
    assert result.issues == ()


def test_rejects_relationships_until_phase_10(simple_entity_model: dict[str, Any]) -> None:
    model = deepcopy(simple_entity_model)
    model["relationships"] = [{"id": "relationship-1"}]

    assert "UNSUPPORTED_RELATIONSHIPS" in issue_codes(model)


@pytest.mark.parametrize(
    ("mutation", "expected_code"),
    [
        (lambda entity: entity["attributes"].pop(0), "INVALID_PRIMARY_KEY_COUNT"),
        (
            lambda entity: entity["attributes"][0].update({"dataType": "UUID"}),
            "UNSUPPORTED_PRIMARY_KEY_TYPE",
        ),
        (
            lambda entity: entity["attributes"][1].update({"dataType": "Money"}),
            "UNSUPPORTED_DATA_TYPE",
        ),
        (lambda entity: entity.update({"name": "class"}), "INVALID_CLASS_NAME"),
    ],
)
def test_rejects_models_outside_the_simple_entity_scope(
    simple_entity_model: dict[str, Any],
    mutation: Callable[[dict[str, Any]], object],
    expected_code: str,
) -> None:
    model = deepcopy(simple_entity_model)
    mutation(model["classes"][0])

    assert expected_code in issue_codes(model)


def test_assert_valid_exposes_all_issues(simple_entity_model: dict[str, Any]) -> None:
    model = deepcopy(simple_entity_model)
    model["classes"][0]["attributes"] = []

    with pytest.raises(GenerationValidationError) as caught:
        ModelValidator().assert_valid(model)

    assert caught.value.issues[0].code == "INVALID_PRIMARY_KEY_COUNT"
