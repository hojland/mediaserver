# Storage & Hardlinks - Important Caveat

**TL;DR:** `/mnt/storage` (the 1 TB `/dev/sda1`) is formatted **exFAT**, which supports
**neither hardlinks nor symlinks**. Sonarr/Radarr therefore always **copy** files from
`downloads/` into `media/` on import - so every release you keep AND seed is stored **twice**.
This is a filesystem limitation, not a config bug; no Docker or *arr setting can change it.

## Verified (2026-07-07)
- `df -T /mnt/storage` -> `exfat`
- On the host, both `ln` (hardlink) and `ln -s` (symlink) fail with `EPERM: Operation not permitted`.

## Current setup (staged so a future FS switch "just works")
- `sonarr`, `radarr` now mount a single parent: `/mnt/storage:/data`
  (previously separate `/downloads` + `/tv` or `/movies`, which alone would also block hardlinks).
- `qbittorrent` unchanged: `/mnt/storage/downloads:/downloads`.
- Remote Path Mapping added in Sonarr/Radarr: host `vpn`, `/downloads/` -> `/data/downloads/`.
- Root folders: `/data/media/TV Shows`, `/data/media/Movies`.
- DB backups from the migration: `config/{sonarr,radarr}/*.db.pre-hardlink.bak`.
- Benefit today: *arr imports are now instant renames within one mount (no temporary 2x copy).

## Options to stop double-storage
- **A. Move + do not seed (no reformat, works now):** enable "Remove Completed Downloads" in the
  *arr download-client settings so the download is deleted after import -> only the library copy
  remains. Loses seeding (fine for public trackers).
- **B. Reformat to ext4/btrfs (proper fix):** enables real hardlinks (seed + library share ONE
  copy, zero waste). Requires a spare >=1 TB drive and a few hours downtime.

## Migration to ext4 (future, Option B)
1. Attach a spare >=1 TB drive (USB), mounted at e.g. /mnt/tmpdrive.
2. `docker compose -f docker-compose-plex.yml down`
3. `rsync -aHAX --info=progress2 /mnt/storage/ /mnt/tmpdrive/`
4. `umount /mnt/storage && mkfs.ext4 -L storage /dev/sda1`
5. Update /etc/fstab (exfat -> ext4, drop the uid/gid/fmask/dmask opts) and `mount -a`
6. `rsync -aHAX --info=progress2 /mnt/tmpdrive/ /mnt/storage/`
7. `chown -R 1000:1000 /mnt/storage` (ext4 stores real ownership)
8. Bring the stack up. Verify Sonarr/Radarr -> Media Management -> "Use Hardlinks instead of Copy"
   is ON (default). Test: `ln` between /data/downloads and /data/media now succeeds.

Because the /data mount + root-folder paths already match what hardlinks need, no further app
reconfiguration is required after the reformat.

## ACTIVE: Option A enabled (2026-07-07)
Move-not-copy behaviour is now in effect so downloads no longer pile up:
- Sonarr & Radarr qBittorrent client: "Remove Completed Downloads" = ON (was already on).
- qBittorrent: `Session\GlobalMaxRatio=0` + `Session\ShareLimitAction=Stop`
  (set in qBittorrent.conf; backup at `qBittorrent.conf.pre-ratiolimit.bak`).

Flow: download completes -> qB stops it immediately (ratio 0) -> *arr imports (copies to
library) -> *arr removes the completed torrent + its files from downloads. Net: one copy.
No seeding (fine for public trackers). Raise GlobalMaxRatio if you want to seed.
