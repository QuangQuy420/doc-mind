"""Print the OpenAPI schema to stdout.

`uv run --package docmind-api python -m app.export_openapi > openapi.json` feeds
`openapi-typescript` in apps/web, so the web client's types come from the API
instead of hand-copied shapes. Must work with no environment and no AWS.
"""

import json

from app.main import app


def main() -> None:
    print(json.dumps(app.openapi(), indent=2))


if __name__ == "__main__":
    main()
