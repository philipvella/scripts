#!/bin/bash
# Usage: ./clearAttemptsForUser.sh <user_id>

# Assign the first command line argument to a variable
USER_ID=$1

# Use the variable in the curl command
curl --location 'https://qasvc-paydev1.betagy.co//api/finance/User/DailyWithdrawals' \
--header 'X-BRAND-ID: 1901' \
--header 'Content-Type: application/json' \
--data '{
    "userId": '"$USER_ID"',
    "AutoClearingTotalWithdrawalNumberOfAttempts": 0,
    "AutoClearingTotalWithdrawalValueOfAttempts":0,
    "TotalWithdrawalNumberOfAttempts": 0,
    "TotalWithdrawalValueOfAttempts":0
}'
