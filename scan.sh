#!/bin/bash

# This script uses git-secrets to scan the repository for sensitive information.
# It's designed to be run within a CI/CD pipeline.

echo "Starting git-secrets scan..."

# Install git-secrets if it's not already present.
# This part is crucial for the GitHub Actions runner.
# The `make install` command places git-secrets in /usr/local/bin by default.
if ! command -v git-secrets &> /dev/null
then
    echo "git-secrets not found, installing..."
    # Clone the git-secrets repository
    git clone https://github.com/awslabs/git-secrets.git /tmp/git-secrets
    cd /tmp/git-secrets
    # Install using the Makefile
    sudo make install
    # Register common AWS patterns (optional, but good practice)
    git secrets --register-aws --global
    cd - # Go back to the original directory
    echo "git-secrets installed."
fi

# Ensure git-secrets hooks are installed for the current repository.
# This is important for `git-secrets --scan-history` to work correctly.
git secrets --install

# Run the scan. We'll scan the entire history for this project.
# The `--scan-history` option is powerful but can be slow on large repos.
# For a fresher project, it's a good demonstration.
# The `|| true` ensures the script doesn't exit immediately on failure,
# allowing us to capture the output and then decide to fail the GitHub Action.
# We redirect stderr to stdout to capture all output.
SCAN_OUTPUT=$(git secrets --scan-history 2>&1 || true)
SCAN_EXIT_CODE=$?

echo "--- git-secrets Scan Results ---"
echo "$SCAN_OUTPUT"
echo "--------------------------------"

# Check the exit code of git-secrets.
# git-secrets exits with a non-zero code if secrets are found.
if [ $SCAN_EXIT_CODE -ne 0 ]; then
    echo "!!! SECRETS FOUND !!!"
    echo "Please review the scan output above. The build will fail."
    # We'll output the detected secrets to a specific file that the GitHub Action can read.
    echo "$SCAN_OUTPUT" > detected_secrets.txt
    exit 1 # Exit with a non-zero code to fail the GitHub Action
else
    echo "No secrets detected. Good job!"
    exit 0 # Exit with a zero code for success
fi
