# Oracle License Server (Lemon Squeezy)

## Setup

1. `cd license_server`
2. `npm install`
3. Copy `.env.example` to `.env` and fill values.
4. `export $(cat .env | xargs)`
5. `npm start`

## Endpoints

### POST /license/activate
Body:
```json
{
  "licenseKey": "XXXX-XXXX-XXXX",
  "deviceId": "ios-abc123",
  "instanceName": "Oracle iOS"
}
```

Behavior:
- 1 active device per license
- If new device and last switch < 24h -> returns `COOLDOWN_ACTIVE`
- Else old device is deactivated and new one activated

### POST /license/validate
Body:
```json
{
  "licenseKey": "XXXX-XXXX-XXXX",
  "deviceId": "ios-abc123"
}
```

Behavior:
- Denies if license is assigned to another device
- Checks Lemon Squeezy license status (`active/inactive/expired/disabled`)
