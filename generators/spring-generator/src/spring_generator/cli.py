import argparse
import json
from pathlib import Path
from typing import Any

from spring_generator.generator import SpringGenerator
from spring_generator.mapping import SpringModelMapper


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Genera un backend Spring Boot desde un modelo canónico GeneraTabla."
    )
    parser.add_argument("model", type=Path, help="Archivo JSON con el modelo canónico.")
    parser.add_argument("output", type=Path, help="Directorio de salida vacío.")
    parser.add_argument("--group-id", default="com.example", help="Group ID y paquete Java base.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    model: dict[str, Any] = json.loads(args.model.read_text(encoding="utf-8"))
    generator = SpringGenerator(mapper=SpringModelMapper(group_id=args.group_id))
    generated = generator.generate(model)
    generated.write_to(args.output)
    print(f"Proyecto generado en {args.output.resolve()} ({len(generated.files)} archivos).")


if __name__ == "__main__":
    main()
