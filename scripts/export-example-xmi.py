"""Export a canonical JSON example to XMI for CASE/Enterprise Architect demos."""

import argparse
import json
from pathlib import Path

from case_backend.exporters.xmi import XMIExporter
from case_backend.schemas import CanonicalProjectModel


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("model", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    model = CanonicalProjectModel.model_validate(json.loads(args.model.read_text(encoding="utf-8")))
    if args.output.exists():
        parser.error(f"El archivo de salida ya existe: {args.output}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(XMIExporter().export_bytes(model))
    print(f"XMI listo: {args.output}")


if __name__ == "__main__":
    main()
