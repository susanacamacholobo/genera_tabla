import json
import sys
from pathlib import Path
from typing import Any

import pytest

from spring_generator.cli import main


def test_cli_generates_to_an_empty_directory(
    simple_entity_model: dict[str, Any], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    model_path = tmp_path / "model.json"
    output = tmp_path / "output"
    model_path.write_text(json.dumps(simple_entity_model), encoding="utf-8")
    monkeypatch.setattr(
        sys,
        "argv",
        ["spring-generator", str(model_path), str(output), "--group-id", "bo.edu.demo"],
    )

    main()

    application = output / "src/main/java/bo/edu/demo/veterinaria/VeterinariaApplication.java"
    assert application.exists()
    assert "package bo.edu.demo.veterinaria;" in application.read_text(encoding="utf-8")
