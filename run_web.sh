#!/bin/bash
export $(grep -v '^#' .env | xargs)

# Create a temporary file replacing the placeholder with the actual value from .env
cp web/index.html web/index.html.tmp
sed -e "s/{{CLEVERTAP_ACCOUNT_ID}}/$CLEVERTAP_ACCOUNT_ID/g" web/index.html.tmp > web/index.html

# Run flutter web
flutter run -d chrome

# Restore the original templated file after flutter finishes or fails
mv web/index.html.tmp web/index.html
