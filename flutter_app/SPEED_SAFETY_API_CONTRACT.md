# Speed safety REST contract

The Flutter client writes all safety evidence offline first. Journey completion
uses a stable local identifier plus an `Idempotency-Key`. The Supabase
`app-api` owns authorization, deterministic classification, and persistence.

## Deterministic classification boundary

- Flutter records speed, limit, time, coordinates, accuracy, and motion state.
- A local violation episode requires three consecutive moving samples more
  than 2 km/h above the journey's frozen admin-configured limit. It ends at the
  first sample within that tolerance. One sustained period counts once; the
  backend independently reconstructs the authoritative episode set.
- Journey and agency statuses are produced by versioned deterministic backend
  rules from accepted evidence. The backend records reasons, thresholds, and
  confidence with each result.
- Optional OpenAI summaries are generated only after those fields exist.
  Summary text never sets or overrides a classification.

## Writes

### `POST /api/journeys/complete-safety`

Authenticated and idempotent. Flutter sends journey metadata and its locally
stored samples in one atomic completion request:

```json
{
  "journey": {
    "localId": "UUID",
    "mode": "bus",
    "endTime": "2026-08-26T21:00:00.000Z"
  },
  "samples": [{
    "recordedAt": "2026-08-26T20:58:00.000Z",
    "speedKph": 64.2,
    "accuracyM": 5.1,
    "latitude": 4.05,
    "longitude": 9.7
  }]
}
```

The backend reloads the admin limit for the journey mode, rejects invalid or
low-quality samples, reconstructs sustained episodes, writes the assessment,
and publishes the Speed Board entry transactionally. Flutter uses one stable
`complete_journey_safety:<localId>` operation key.

## Reads

- `GET /api/speed-board` supplies published violator and within-limit entries.
- `GET /api/agency-safety-rollups` supplies trusted and avoid agency results.
- `GET /api/notifications` returns deduplicated `agency_trusted` and
  `agency_avoid` events. Flutter shows these only to registered users and stores
  `<notice-id>:<version>` after display so repeated fetches do not repeat a
  popup. It then marks the backend notification read when online.

Guests can record and view their local journey-end evidence summary. They
cannot open Speed Board or retrieve safety notices, and their queue is not
uploaded without an authenticated session.
