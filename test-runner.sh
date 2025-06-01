#!/bin/bash

echo "Running specific tests to verify Defaults MainActor fixes..."

# Navigate to project directory
cd "$(dirname "$0")"

# Run the specific test that was failing
echo "Testing IntegrationTests.testSettingsPersistenceIntegration..."
swift test --filter "testSettingsPersistenceIntegration" 2>&1 | tail -20

echo ""
echo "Testing RuleExecutionTests..."
swift test --filter "RuleExecutionTests" 2>&1 | tail -20

echo ""
echo "Done. Check output above for any MainActor-related crashes."