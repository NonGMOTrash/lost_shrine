#!/bin/bash

# Test script for Lost Shrine game
# Runs input/output tests and reports success/failure with details

# Note: Don't use set -e because tests may return non-zero exit codes intentionally

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if SWI-Prolog is available
echo "Checking for SWI-Prolog..."
if ! command -v swipl &> /dev/null; then
    echo -e "${RED}SWI-Prolog not found${NC}"
    exit 1
fi

# Check if main.pl exists
if [ ! -f "$PROJECT_ROOT/main.pl" ]; then
    echo -e "${RED}main.pl not found${NC}"
    exit 1
fi

# Syntax check
echo "Checking Prolog syntax..."
cd "$PROJECT_ROOT"
if ! swipl -q -t halt -s main.pl 2>&1; then
    SYNTAX_OUTPUT=$(swipl -q -t halt -s main.pl 2>&1)
    if [ -n "$SYNTAX_OUTPUT" ]; then
        echo -e "${RED}Syntax warnings/errors found:${NC}"
        echo "$SYNTAX_OUTPUT"
    fi
    # Only fail on actual errors, not warnings
    if echo "$SYNTAX_OUTPUT" | grep -q "ERROR"; then
        exit 1
    fi
fi

# Change to test directory
cd "$SCRIPT_DIR"

# Define test order from simplest to most complex
TESTS="test_quit.in fail_darkness.in fail_quicksand.in test_victory.in test_details.in"

# Verify all test files exist
for TEST_IN in $TESTS; do
    if [ ! -f "$TEST_IN" ]; then
        echo "Warning: Test file $TEST_IN not found"
    fi
done

TOTAL=0
PASSED=0
FAILED=0

# Process each test
for TEST_IN in $TESTS; do
    TEST_NAME="${TEST_IN%.in}"
    TEST_OUT="${TEST_NAME}.out"
    
    if [ ! -f "$TEST_OUT" ]; then
        echo -e "${YELLOW}⚠ SKIP${NC}  $TEST_NAME (missing .out file)"
        continue
    fi
    
    TOTAL=$((TOTAL + 1))
    
    # Determine expected exit code based on test name
    case "$TEST_NAME" in
        fail_darkness)
            EXPECTED_EXIT_CODE=1  # Darkness is a hard failure
            ;;
        *)
            EXPECTED_EXIT_CODE=0  # Victory, quit, or normal termination
            ;;
    esac
    
    # Run the test and capture exit code
    ACTUAL_OUTPUT=$(cat "$TEST_IN" | swipl -q -s "$PROJECT_ROOT/main.pl" -g main -t halt 2>&1)
    ACTUAL_EXIT_CODE=$?
    EXPECTED_OUTPUT=$(cat "$TEST_OUT")
    
    # Compare outputs and exit codes
    if [ "$ACTUAL_OUTPUT" = "$EXPECTED_OUTPUT" ] && [ "$ACTUAL_EXIT_CODE" -eq "$EXPECTED_EXIT_CODE" ]; then
        echo -e "${GREEN}✓ PASS${NC}  $TEST_NAME"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC}  $TEST_NAME"
        FAILED=$((FAILED + 1))
        
        # Show what failed
        if [ "$ACTUAL_OUTPUT" != "$EXPECTED_OUTPUT" ]; then
            echo "  Output mismatch:"
        fi
        if [ "$ACTUAL_EXIT_CODE" -ne "$EXPECTED_EXIT_CODE" ]; then
            echo "  Exit code mismatch: expected $EXPECTED_EXIT_CODE, got $ACTUAL_EXIT_CODE"
        fi
        
        # Create temporary files for diff
        EXPECTED_TEMP=$(mktemp)
        ACTUAL_TEMP=$(mktemp)
        
        echo "$EXPECTED_OUTPUT" > "$EXPECTED_TEMP"
        echo "$ACTUAL_OUTPUT" > "$ACTUAL_TEMP"
        
        # Show first few differences
        if ! diff -u "$EXPECTED_TEMP" "$ACTUAL_TEMP" 2>/dev/null | head -20 | sed 's/^/    /'; then
            # If diff fails, show a more detailed comparison
            echo "    First difference:"
            EXPECTED_LINES=$(echo "$EXPECTED_OUTPUT" | wc -l)
            ACTUAL_LINES=$(echo "$ACTUAL_OUTPUT" | wc -l)
            echo "    Expected $EXPECTED_LINES lines, got $ACTUAL_LINES lines"
            
            # Show the actual vs expected
            echo ""
            echo "    First 10 lines of expected output:"
            echo "$EXPECTED_OUTPUT" | head -10 | sed 's/^/      /'
            echo ""
            echo "    First 10 lines of actual output:"
            echo "$ACTUAL_OUTPUT" | head -10 | sed 's/^/      /'
        fi
        
        rm -f "$EXPECTED_TEMP" "$ACTUAL_TEMP"
    fi
done

# Print summary
echo ""
echo "========================================="
echo "Test Results: $PASSED passed, $FAILED failed out of $TOTAL tests"
echo "========================================="

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
