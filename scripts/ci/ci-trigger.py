from __future__ import annotations

import argparse


ALLOWED_TOKENS = {"build-action", "build-release", "run-championship"}


def contains_token(message: str, token: str) -> bool:
    if token not in ALLOWED_TOKENS:
        raise ValueError(f"Unsupported CI token: {token}")
    return f"[{token}]" in message


def main() -> None:
    parser = argparse.ArgumentParser(description="Match an exact bracketed CI token.")
    parser.add_argument("--message", required=True)
    parser.add_argument("--token", choices=sorted(ALLOWED_TOKENS), required=True)
    args = parser.parse_args()
    raise SystemExit(0 if contains_token(args.message, args.token) else 1)


if __name__ == "__main__":
    main()
