# Community Hazard API Contract

The Flutter client supports optimistic reporting, local caching, and an offline sync queue. Deploy these endpoints in the production API to share reports and confirmations between drivers in realtime.

## List active incidents

`GET /api/incidents`

Return a JSON array. Each record should include:

```json
{
  "id": 481,
  "type": "pothole",
  "description": "Deep pothole in the left lane",
  "lat": 3.84812,
  "lng": 11.50228,
  "vehicleReg": null,
  "driverName": null,
  "timestamp": "2026-08-26T05:00:00Z",
  "status": "active",
  "confirmationCount": 3,
  "notThereCount": 0,
  "lastConfirmedAt": "2026-08-26T05:03:00Z",
  "resolvedAt": null
}
```

The client also accepts snake_case field names and legacy `active`, `resolved`, `closed`, `inactive`, or `removed` statuses.

## Create an incident

`POST /api/incidents`

Request:

```json
{
  "type": "accident",
  "description": "Vehicle stopped on the shoulder",
  "lat": 3.84812,
  "lng": 11.50228,
  "vehicleReg": null,
  "driverName": null
}
```

Return the created incident, including its positive server ID, timestamps, active status, and confirmation counters.

## Confirm or resolve an incident

`POST /api/incidents/{id}/confirm`

Still present:

```json
{ "stillThere": true }
```

No longer present:

```json
{ "stillThere": false }
```

For `true`, increment `confirmationCount`, retain `status: "active"`, and update `lastConfirmedAt`. For `false`, increment `notThereCount`, set `status: "resolved"`, and set `resolvedAt`. Return the updated incident.

## Realtime delivery

After each create or confirmation mutation, broadcast the updated incident to authenticated clients using the production push or websocket channel. Clients should remove incidents with a resolved status and refresh active markers without restarting the journey.

The API should authenticate writes, validate coordinate ranges, rate-limit duplicate reports, and make confirmation updates transactional.
