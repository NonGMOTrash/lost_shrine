#!/usr/bin/env python3
import argparse
import difflib
import os
import subprocess
import sys
from pathlib import Path


def normalize_newlines(text: str) -> str:
    return text.replace("\r\n", "\n").replace("\r", "\n")


def strip_trailing_whitespace(text: str) -> str:
    lines = text.splitlines()
    trailing_newline = text.endswith("\n")
    cleaned = "\n".join(line.rstrip() for line in lines)
    if trailing_newline:
        cleaned += "\n"
    return cleaned


def compare_output(actual: str, expected: str, ignore_trailing_whitespace: bool) -> bool:
    actual = normalize_newlines(actual)
    expected = normalize_newlines(expected)

    if ignore_trailing_whitespace:
        actual = strip_trailing_whitespace(actual)
        expected = strip_trailing_whitespace(expected)

    return actual == expected


def make_diff(actual: str, expected: str, ignore_trailing_whitespace: bool, fromfile: str, tofile: str) -> str:
    actual = normalize_newlines(actual)
    expected = normalize_newlines(expected)

    if ignore_trailing_whitespace:
        actual = strip_trailing_whitespace(actual)
        expected = strip_trailing_whitespace(expected)

    diff = difflib.unified_diff(
        expected.splitlines(keepends=True),
        actual.splitlines(keepends=True),
        fromfile=fromfile,
        tofile=tofile,
    )
    return "".join(diff)


def find_test_cases(tests_dir: Path):
    cases = []
    for input_path in sorted(tests_dir.glob("*.in")):
        output_path = input_path.with_suffix(".out")
        if output_path.exists():
            cases.append((input_path, output_path))
    return cases


def run_case(command, input_path: Path, timeout: float):
    input_text = input_path.read_text(encoding="utf-8")
    result = subprocess.run(
        command,
        input=input_text,
        text=True,
        capture_output=True,
        timeout=timeout,
    )
    return result


def main():
    parser = argparse.ArgumentParser(
        description="Run an executable against all .in files in a directory and compare stdout to matching .out files."
    )
    parser.add_argument(
        "--tests",
        type=Path,
        default=Path("."),
        help="Directory containing matching .in/.out test files (default: current directory).",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=0.5,
        help="Timeout in seconds for each test case (default: 5).",
    )
    parser.add_argument(
        "--ignore-trailing-whitespace",
        action="store_true",
        help="Ignore trailing spaces at the ends of lines when comparing output.",
    )
    parser.add_argument(
        "--show-stderr",
        action="store_true",
        help="Print stderr for failed test cases.",
    )
    parser.add_argument(
        "command",
        nargs=argparse.REMAINDER,
        help="Executable to run, plus any arguments. Use '--' before the command if needed.",
    )

    args = parser.parse_args()

    if not args.command:
        parser.error("missing executable command. Example: python run_tests.py --tests . -- ./my_program")

    command = args.command
    if command and command[0] == "--":
        command = command[1:]

    if not command:
        parser.error("missing executable command after '--'.")

    tests_dir = args.tests
    if not tests_dir.is_dir():
        print(f"error: test directory not found: {tests_dir}", file=sys.stderr)
        sys.exit(2)

    cases = find_test_cases(tests_dir)
    if not cases:
        print(f"No matching .in/.out test pairs found in {tests_dir}")
        sys.exit(1)

    passed = 0
    failed = 0
    had_error = False

    for input_path, output_path in cases:
        test_name = input_path.stem

        try:
            result = run_case(command, input_path, args.timeout)
        except subprocess.TimeoutExpired:
            failed += 1
            print(f"[FAIL] {test_name}: timed out after {args.timeout} seconds")
            continue
        except FileNotFoundError:
            print(f"error: executable not found: {command[0]}", file=sys.stderr)
            sys.exit(2)
        except Exception as exc:
            failed += 1
            had_error = True
            print(f"[FAIL] {test_name}: error while running test: {exc}")
            continue

        expected = output_path.read_text(encoding="utf-8")
        actual = result.stdout

        ok = (
            result.returncode == 0
            and compare_output(actual, expected, args.ignore_trailing_whitespace)
        )

        if ok:
            passed += 1
            print(f"[PASS] {test_name}")
            continue

        failed += 1
        print(f"[FAIL] {test_name}")

        if result.returncode != 0:
            print(f"  return code: {result.returncode}")

        diff = make_diff(
            actual,
            expected,
            args.ignore_trailing_whitespace,
            fromfile=f"{output_path.name} (expected)",
            tofile=f"{input_path.stem}.actual (got)",
        )

        if diff:
            print(diff, end="" if diff.endswith("\n") else "\n")
        else:
            print("  Output differs, but no line-level diff was produced.")

        if args.show_stderr and result.stderr:
            print("  stderr:")
            print(result.stderr, end="" if result.stderr.endswith("\n") else "\n")

    total = passed + failed
    print(f"\nSummary: {passed}/{total} passed, {failed}/{total} failed")

    sys.exit(0 if failed == 0 and not had_error else 1)


if __name__ == "__main__":
    main()
