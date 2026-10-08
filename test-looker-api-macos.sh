MY_LOOKER_URL="https://YOUR_LOOKER.looker.app"
MY_LOOKER_CLIENT_ID="YOUR_CLIENT_ID"
MY_LOOKER_CLIENT_SECRET="YOUR_CLIENT_SECRET"

  MY_LOOKER_LOGIN_RESPONSE=$(
    curl -sS -X POST "$MY_LOOKER_URL/api/4.0/login" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      --data-urlencode "client_id=$MY_LOOKER_CLIENT_ID" \
      --data-urlencode "client_secret=$MY_LOOKER_CLIENT_SECRET"
  )

  echo "Login response:"
  echo "$MY_LOOKER_LOGIN_RESPONSE"

  MY_LOOKER_TOKEN=$(
    printf '%s' "$MY_LOOKER_LOGIN_RESPONSE" \
      | tr -d '\n' \
      | sed -nE 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p'
  )

  if [ -z "$MY_LOOKER_TOKEN" ]; then
    echo "No access token returned"
    exit 1
  fi

  echo
  echo "Authentication successful"
  echo "Calling all_oauth_client_apps..."
  echo

  curl -sS "$MY_LOOKER_URL/api/4.0/oauth_client_apps" \
    -H "Authorization: token $MY_LOOKER_TOKEN"

  echo