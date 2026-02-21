# SourceMod Map Loader Plugin

SourceMod plugin developed for a Counter-Strike: Source bhop server that lets you download and load maps on demand via a menu-driven interface, without needing the maps pre-installed on the server.

## Dependencies

- [ripext](https://github.com/ErikMinekus/sm-ripext) — HTTP requests for downloading map files
- [bzip2](https://github.com/epsilonbsp/sm_bzip2/) — async bz2 decompression

## Usage

```
sm_loadmap            — opens a category browser menu
sm_loadmap <query>    — opens a filtered map list matching the query
```

When a map is selected, confirm the change via a yes/no menu. The plugin then:

1. Checks if the `.bsp` is already present in the `maps/` directory
2. If not, downloads `<mapname>.bsp.bz2` from the configured FastDL URL
3. Decompresses the archive and removes the `.bz2` file
4. Begins a 5-second countdown before changing the level

## Configuration

**Map list:** `addons/sourcemod/configs/maploader_maps.txt`

One map name per line (without `.bsp` extension). Blank lines and lines starting with `#` or `//` are ignored.

**FastDL URL:** hardcoded in the plugin as `DOWNLOAD_BASE_URL`. Default is `http://main.fastdl.me/maps/`. Maps are fetched as `<base_url><mapname>.bsp.bz2`.

## Map Categories

Maps are automatically sorted into categories by prefix:

| Category | Prefix |
|----------|--------|
| bhop | `bhop_` |
| kz_bhop | `kz_bhop_` |
| kz | `kz_` |
| surf | `surf_` |
| xc | `xc_` |
| trikz | `trikz_` |
| (other) | anything else |