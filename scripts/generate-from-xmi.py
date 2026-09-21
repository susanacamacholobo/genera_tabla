"""Generate a Spring backend from XMI exported by the CASE tool or EA."""

import argparse
from pathlib import Path

from case_backend.importers.xmi import XMIImporter
from spring_generator import SpringGenerator


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xmi", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    model = XMIImporter().import_bytes(args.xmi.read_bytes())
    generated = SpringGenerator().generate(model.model_dump(by_alias=True))
    generated.write_to(args.output)
    print(f"Backend listo: {args.output} ({len(generated.files)} archivos)")


if __name__ == "__main__":
    main()
