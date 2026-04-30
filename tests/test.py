#!/usr/bin/env python3

from __future__ import annotations

import difflib
import shutil
import subprocess
import sys
from pathlib import Path

# Colors for output
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[0;33m"
NC = "\033[0m"  # No Color

# Get the directory where this script is located
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
MAIN_PL = PROJECT_ROOT / "main.pl"

# Define test order from simplest to most complex
TESTS = [
    "test_quit.in",
    "fail_darkness.in",
    "fail_quicksand.in",
    "test_victory.in",
    "test_details.in",
]


def normalize_output(text: str) -> str:
    # Bash command substitution strips trailing newlines
    return text.rstrip("\n")


def run_syntax_check() -> int:
    print("Checking Prolog syntax...")

    # First run: match the Bash behavior of letting output go directly to the terminal
    first = subprocess.run(
        ["swipl", "-q", "-t", "halt", "-s", "main.pl"],
        cwd=PROJECT_ROOT,
        stdout=None,
        stderr=subprocess.STDOUT,
    )

    if first.returncode != 0:
        # Second run: capture output for reporting, like the Bash script does
        second = subprocess.run(
            ["swipl", "-q", "-t", "halt", "-s", "main.pl"],
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        syntax_output = normalize_output(second.stdout or "")

        if syntax_output:
            print(f"{RED}Syntax warnings/errors found:{NC}")
            print(syntax_output)

        # Only fail on actual errors, not warnings
        if "ERROR" in syntax_output:
            return 1

    return 0


def expected_exit_code_for(test_name: str) -> int:
    if test_name == "fail_darkness":
        return 1  # Darkness is a hard failure
    return 0  # Victory, quit, or normal termination


def print_diff(expected_output: str, actual_output: str) -> None:
    diff_lines = list(
        difflib.unified_diff(
            expected_output.splitlines(),
            actual_output.splitlines(),
            fromfile="expected",
            tofile="actual",
            lineterm="",
        )
    )

    if diff_lines:
        for line in diff_lines[:20]:
            print(f"    {line}")
        return

    # Fallback detail
    print("    First difference:")
    expected_lines = len(expected_output.splitlines())
    actual_lines = len(actual_output.splitlines())
    print(f"    Expected {expected_lines} lines, got {actual_lines} lines")

    print()
    print("    First 10 lines of expected output:")
    for line in expected_output.splitlines()[:10]:
        print(f"      {line}")

    print()
    print("    First 10 lines of actual output:")
    for line in actual_output.splitlines()[:10]:
        print(f"      {line}")


def main() -> int:
    # print("Checking for SWI-Prolog...")
    # if shutil.which("swipl") is None:
    #     print(f"{RED}SWI-Prolog not found{NC}")
    #     return 1

    # if not MAIN_PL.is_file():
    #     print(f"{RED}main.pl not found{NC}")
    #     return 1

    syntax_status = run_syntax_check()
    if syntax_status != 0:
        return syntax_status

    # Verify all test input files exist
    for test_in_name in TESTS:
        test_in_path = SCRIPT_DIR / test_in_name
        if not test_in_path.is_file():
            print(f"Warning: Test file {test_in_name} not found")

    total = 0
    passed = 0
    failed = 0

    # Process each test
    for test_in_name in TESTS:
        test_name = Path(test_in_name).stem
        test_in_path = SCRIPT_DIR / test_in_name
        test_out_path = SCRIPT_DIR / f"{test_name}.out"

        if not test_out_path.is_file():
            print(f"{YELLOW}⚠ SKIP{NC}  {test_name} (missing .out file)")
            continue

        total += 1
        expected_exit_code = expected_exit_code_for(test_name)

        if not test_in_path.is_file():
            print(f"{RED}✗ FAIL{NC}  {test_name}")
            print("  Missing input file")
            failed += 1
            continue

        test_input = test_in_path.read_text(encoding="utf-8", errors="replace")
        expected_output = normalize_output(
            test_out_path.read_text(encoding="utf-8", errors="replace")
        )

        result = subprocess.run(
            ["swipl", "-q", "-s", str(MAIN_PL), "-g", "main", "-t", "halt"],
            cwd=SCRIPT_DIR,
            input=test_input,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        actual_output = normalize_output(result.stdout or "")
        actual_exit_code = result.returncode

        if (
            actual_output == expected_output
            and actual_exit_code == expected_exit_code
        ):
            print(f"{GREEN}✓ PASS{NC}  {test_name}")
            passed += 1
        else:
            print(f"{RED}✗ FAIL{NC}  {test_name}")
            failed += 1

            if actual_output != expected_output:
                print("  Output mismatch:")
            if actual_exit_code != expected_exit_code:
                print(
                    f"  Exit code mismatch: expected {expected_exit_code}, "
                    f"got {actual_exit_code}"
                )

            if actual_output != expected_output:
                print_diff(expected_output, actual_output)

    # Print summary
    print()
    print("=========================================")
    print(f"Test Results: {passed} passed, {failed} failed out of {total} tests")
    print("=========================================")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())