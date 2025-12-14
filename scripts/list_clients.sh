jq '
  {
    active: [.inbounds[].settings.clients[]?.email],
    disabled: [.inbounds[].settings.disabled_clients[]?.email]
  }
' /app/xray/config.json
