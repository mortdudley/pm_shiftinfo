# PM Shift Timer

A lightweight FiveM shift logger for ESX and QBCore. It automatically tracks player shifts per job, logs staff activity via ACE permissions, stores history in JSON, and posts summaries to Discord through a single server-side webhook.

## Features

- ESX or QBCore selectable via config
- Automatic job tracking (no job whitelist required)
- Automatic staff activity tracking using ACE (e.g., group.admin)
- Single, server-side Discord webhook (no client exposure)
- JSON persistence in `server/shifts.json`
- 30-day auto-prune on resource start
- Minimum 1-minute rounding for short shifts (embeds and JSON)
- Commands to summarize staff or per-job activity, and to add manual entries

## How it works

- Client initializes for ESX or QBCore and always tells the server when the player has loaded (even if job is unknown).
- Server starts tracking:
  - A job shift when a job is known and changes.
  - A staff shift for any player with the configured ACE permission.
- When a shift ends (job change, going off duty, or disconnect), the server:
  - Computes duration.
  - Sends a Discord embed via the single webhook.
  - Writes an entry to `server/shifts.json`.

## Installation

1. Place the `clockin` folder in your FiveM resources directory.
2. Edit `server/clockin.lua` and set the webhook at the top:
   ```lua
   DefaultWebhook = 'https://discord.com/api/webhooks/...' -- single catch-all webhook
   ```
3. Optionally set your framework and server name in `config.lua`:
   ```lua
   Config.Framework = 'ESX' -- or 'QBCore'
   Config.ServerName = 'My Server'
   Config.AcePerm    = 'group.admin' -- ACE permission for staff tracking and /shiftinfo
   ```
4. Ensure the resource:
   ```
   ensure clockin
   ```

## Configuration

- `config.lua`
  - `Config.Framework`: 'ESX' or 'QBCore'
  - `Config.ServerName`: Name shown in Discord embeds footer
  - `Config.AcePerm`: ACE permission used for staff auto-tracking and the `/shiftinfo` command
  - `Config.ShiftJobs`: Optional label/color per job, e.g.
    ```lua
    Config.ShiftJobs = {
      police = { label = 'Police', color = 3447003 },
      ambulance = { label = 'EMS',    color = 15158332 },
    }
    ```
    Notes:
    - Webhooks in `Config.ShiftJobs` are ignored for security. The server always uses `DefaultWebhook`.
    - Labels/colors are safe to keep here; they are used for embed titles/colors.
  - `Config.DiscordBotName`, `Config.DiscordAvatar`: Optional embed username/avatar

- `server/clockin.lua`
  - `DefaultWebhook`: Set your single Discord webhook here (server-side only)
  - `WebhookColor`: Default embed color if a job has no color override

## Commands

- `/shiftinfo staff <days>`
  - Aggregates staff shift minutes for the last `<days>` and posts a ranked list to Discord.
- `/shiftinfo times <job> <days>`
  - Aggregates per-character minutes for a given `<job>` over the last `<days>` and posts to Discord.
- `/shiftinfo <job> <character> <minutes>`
  - Adds a manual shift entry to the JSON history.

Permissions:
- By default, only console and players with `Config.AcePerm` can run `/shiftinfo`.

## Server events you can emit

- `pm_shifttimer:dutyChange (jobName, status)`
  - `status` false: end current shift for `jobName`
  - `status` true: start shift for `jobName` (replaces any in-progress entry)

The script internally also handles:
- `pm_shifttimer:userjoined (jobName)` — called automatically by the client on load.
- `pm_shifttimer:jobchanged (oldJob, newJob, method)` — called by the client on job updates.

## Data storage format

File: `server/shifts.json`

Structure:
```json
{
  "Jane Doe": [
    [ 1730000000, "license:abc123", "police", "42" ],
    [ 1730003600, "license:abc123", "staff",  "15" ]
  ],
  "John Smith": [
    [ 1730100000, "license:def456", "ambulance", "60" ]
  ]
}
```
- Key: Character name (string)
- Each entry: `[startTimestamp, identifier, jobName, "minutes"]`
- Minutes are strings for legacy compatibility.
- Old entries older than 30 days are pruned on resource start.

## Discord embeds

- The script uses a single server-side webhook for all messages (`DefaultWebhook`).
- Embed title is the job label (or capitalized job name) + "Shift".
- Durations under 60 seconds are displayed as "1 minute" and stored as 1 minute in JSON.

## Staff tracking and ACE permissions

- Any player with `Config.AcePerm` automatically starts a `staff` shift on load.
- Example (server.cfg) to make a user staff:
  ```
  # Replace with the player’s identifier
  add_principal identifier.license:xxxxxxxxxxxxxxxx group.admin
  ```
- You can change `Config.AcePerm` to a custom group if you prefer.

## Notifications

- When a player uses `/shiftinfo`, they receive an in-game notification:
  - ESX: `esx:showNotification`
  - QBCore: `QBCore:Notify`
  - Fallback: chat message
- Console usage prints to server console.

## Known limitations and notes

- Active shifts are kept in memory; if the resource stops/restarts, in-progress shifts are not automatically ended and written.
- Character names are used as top-level keys; if names change frequently, you may see multiple keys for the same identifier.
- The script de-duplicates shift starts to avoid multiple overlapping entries for a single player per job.
- On disconnect, all active shifts for the player (job + staff) are ended and written.

## Quick test flow

1. Set `DefaultWebhook` in `server/clockin.lua`.
2. Ensure your ACE is set for a test account (to test staff tracking).
3. Start the resource and join the server.
4. Change jobs once, then disconnect after ~20–40 seconds.
5. Check Discord: you should see 1-minute shifts logged.
6. Run `/shiftinfo staff 1` to see a daily summary posted to Discord.

## Troubleshooting

- No Discord messages
  - Make sure `DefaultWebhook` is set and valid.
  - Ensure the resource can reach Discord (server firewall outbound HTTPS).
- No staff entries
  - Verify your ACE principal is configured and `Config.AcePerm` matches.
  - Confirm the client fired `userjoined` (it does on load by default).
- Duplicate or missing entries
  - If you manually trigger events, ensure you don’t double-fire start events without ending.
  - Resource restarts will clear active timers; consider ending shifts manually when restarting.

## Version

- v1.0.0 — ESX/QBCore support, auto job and staff tracking, single webhook, JSON storage, 30-day prune, 1-minute minimum, summary commands.
