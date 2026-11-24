https://github.com/marchah/pi-htpc-download-box

https://github.com/sebgl/htpc-download-box/blob/master/docker-compose.yml


# maybe make folders env variables together with ports as in

https://gist.github.com/khongi/52a22b8ef40de052ac0e8ccd38063433#file-download-automation-docker-compose-yml
## Plex library updates

New files show up in Plex within seconds, with no manual scan. Set up 24/11/2026.

Plex watches the library folders itself. In Plex, Settings -> Library has "Scan my library
automatically" and "Run a partial scan when changes are detected" switched on
(`FSEventLibraryUpdatesEnabled` and `FSEventLibraryPartialScanEnabled` in Preferences.xml).
This uses Linux inotify, so it also catches files copied in by hand.

Radarr and Sonarr also tell Plex when they import. Each has a Settings -> Connect -> Plex Media
Server entry named `Plex`, triggered on import, upgrade, rename and delete:

| | Radarr | Sonarr |
|---|---|---|
| Host | `172.19.0.1:32400` | `172.19.0.1:32400` |
| Map from (arr path) | `/data/media/Movies/` | `/data/media/TV Shows/` |
| Map to (Plex path) | `/data/Movies/` | `/data/TVShows/` |

The arr apps run on the `discovery` Docker network and Plex on `mediaserver_default`, so they
reach Plex through the `discovery` gateway (`172.19.0.1`) on the published port 32400. The
path mapping is needed because the arr apps mount all of `/mnt/storage` as `/data`, while Plex
mounts the two library folders directly.

The arr notification matters on this drive: exFAT has no hardlinks, so every import is a full
copy, and the arr app only notifies Plex once the copy has finished.

The auth token in both Connect entries is the Plex server's own `PlexOnlineToken` from
`config/plex/Library/Application Support/Plex Media Server/Preferences.xml`. If the server is
signed out or re-claimed, the token changes and both entries need the new one (Connect -> Plex
-> paste token or sign in again -> Test -> Save).
