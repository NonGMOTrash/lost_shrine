#!/bin/bash
# Quick test to verify exit code checking works

echo "Testing that fail_darkness correctly returns exit code 1..."
../dist-newstyle/build/x86_64-linux/ghc-9.6.7/hello-codespaces-0.1.0.0/x/hello-codespaces/build/hello-codespaces/hello-codespaces < fail_darkness.in > /dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 1 ]; then
    echo "✓ fail_darkness exits with code 1 (correct)"
else
    echo "✗ fail_darkness exits with code $EXIT_CODE (expected 1)"
fi

echo ""
echo "Testing that test_quit correctly returns exit code 0..."
../dist-newstyle/build/x86_64-linux/ghc-9.6.7/hello-codespaces-0.1.0.0/x/hello-codespaces/build/hello-codespaces/hello-codespaces < test_quit.in > /dev/null 2>&1
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ test_quit exits with code 0 (correct)"
else
    echo "✗ test_quit exits with code $EXIT_CODE (expected 0)"
fi
