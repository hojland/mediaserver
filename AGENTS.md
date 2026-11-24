# AGENTS.md

Docker media stack on a Raspberry Pi. Reach it with `ssh pi` on the home LAN or `ssh tailpi`
over Tailscale. Run the stack with `make up` / `make down` (wraps `docker-compose-plex.yml`).
Read `STORAGE-HARDLINKS.md` before touching storage: `/mnt/storage` is exFAT, so there are no
hardlinks and imports are copies.

## Containers

| Container | Port | Mounts | Network |
|---|---|---|---|
| plex | 32400 | `media/Movies` -> `/data/Movies`, `media/TV Shows` -> `/data/TVShows` | `mediaserver_default` |
| radarr | 7878 | `/mnt/storage` -> `/data` | `discovery` |
| sonarr | 8989 | `/mnt/storage` -> `/data` | `discovery` |
| jackett | 9117 | | `discovery` |
| qbittorrent | 7503 (inside `vpn`) | `/mnt/storage/downloads` -> `/downloads` | shares `vpn` container |

Configs live in `/mnt/storage/config/<app>/`. Arr API keys and ports are in
`config/<app>/config.xml`; the Plex token is `PlexOnlineToken` in
`config/plex/Library/Application Support/Plex Media Server/Preferences.xml`.
Never write keys or tokens into this repo, it has a remote.

## Plex scanning (set up 24/11/2026)

Plex should never need a manual scan. If new media is slow to appear, check both paths:

1. Plex folder watching. `GET http://localhost:32400/:/prefs?X-Plex-Token=...` must show
   `FSEventLibraryUpdatesEnabled` and `FSEventLibraryPartialScanEnabled` as true. To re-enable:
   `PUT http://localhost:32400/:/prefs?FSEventLibraryUpdatesEnabled=1&FSEventLibraryPartialScanEnabled=1&X-Plex-Token=...`.
   Quick test: `mkdir "/mnt/storage/media/Movies/zz-watch-test"`, wait a few seconds, grep the
   Plex log (`Logs/Plex Media Server.log`, use `grep -a`) for `zz-watch-test`, then `rmdir` it.
   A working watcher logs `[Notify] New directory` immediately and a partial scan ~5 s later.
2. Arr Connect entries. Radarr and Sonarr each have a `PlexServer` notification named `Plex`
   (`GET /api/v3/notification`). Host `172.19.0.1`, port 32400, path map Radarr
   `/data/media/Movies/` -> `/data/Movies/`, Sonarr `/data/media/TV Shows/` -> `/data/TVShows/`.
   `POST /api/v3/notification/test` with the entry's JSON returns `{}` when it works. A 401 from
   Plex means the token rotated: read the new `PlexOnlineToken` and `PUT` it into `authToken`.
   Check reachability with `docker exec radarr curl -s http://172.19.0.1:32400/identity`.

## Working on the Pi

- No `sqlite3` or `sysctl` binary; use `python3` (with its `sqlite3` module) and `/proc/sys`.
- The login shell mangles some characters in inline `ssh` strings. For anything longer than a
  one-liner, `scp` a script to `/tmp` and run it.
- LAN `ssh pi` sometimes resets and `tailpi` sometimes refuses; try the other one.
