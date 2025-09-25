#!/bin/bash

echo "Building and testing amoca_insurance_package..."
cd /mnt/d/COGNITO/amoca-sui-move-programs/amoca_insurance_package

# First build to ensure no compilation errors
echo "Step 1: Building..."
if sui move build; then
    echo "Build successful!"
else
    echo "Build failed!"
    exit 1
fi

# Now run tests
echo "Step 2: Running tests..."
if timeout 120 sui move test; then
    echo "Tests passed!"
else
    echo "Tests failed or timed out!"
fi