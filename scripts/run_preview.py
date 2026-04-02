from __future__ import annotations

import argparse
import http.server
import os
import socketserver
from pathlib import Path


class PreviewServer(socketserver.TCPServer):
    allow_reuse_address = True


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the static MVP preview locally.")
    parser.add_argument("--host", default="127.0.0.1", help="Host to bind, default: 127.0.0.1")
    parser.add_argument("--port", type=int, default=8000, help="Port to bind, default: 8000")
    args = parser.parse_args()

    root = Path(__file__).resolve().parent.parent / "preview"
    if not root.exists():
        raise SystemExit(f"Preview directory not found: {root}")

    os.chdir(root)
    handler = http.server.SimpleHTTPRequestHandler
    with PreviewServer((args.host, args.port), handler) as httpd:
        print(f"Preview server running at http://{args.host}:{args.port}/")
        print(f"Serving directory: {root}")
        print("Press Ctrl+C to stop.")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nPreview server stopped.")


if __name__ == "__main__":
    main()
