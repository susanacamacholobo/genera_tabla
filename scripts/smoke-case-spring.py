"""Exercise CASE XMI import and Spring ZIP download against a running server."""

import argparse
from io import BytesIO
from pathlib import Path
from zipfile import ZipFile

import httpx


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xmi", type=Path)
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    with httpx.Client(base_url=args.base_url, timeout=30.0) as client:
        with args.xmi.open("rb") as source:
            imported = client.post(
                "/projects/xmi/import",
                files={"file": (args.xmi.name, source, "application/xml")},
            )
        imported.raise_for_status()
        project_id = imported.json()["project_id"]
        try:
            response = client.get(f"/projects/{project_id}/spring.zip")
            response.raise_for_status()
            if not response.headers["content-type"].startswith("application/zip"):
                raise AssertionError("La respuesta no es un ZIP.")
            with ZipFile(BytesIO(response.content)) as archive:
                names = set(archive.namelist())
                required = {"pom.xml", "metadata/domain-model.json", "openapi/openapi.json"}
                if not required.issubset(names):
                    raise AssertionError(f"Faltan archivos generados: {required - names}")
                print(f"CASE a Spring ZIP OK: {len(names)} archivos.")
        finally:
            deleted = client.delete(f"/projects/{project_id}")
            deleted.raise_for_status()
            print("Proyecto temporal de la prueba eliminado.")


if __name__ == "__main__":
    main()
