// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 EpsilonBSP

#include <sourcemod>
#include <bzip2>
#include <ripext>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"
#define MAP_LIST_PATH "configs/maploader_maps.txt"
#define DOWNLOAD_BASE_URL "http://main.fastdl.me/maps/"

ArrayList g_MapList;

public Plugin myinfo = {
    name = "Map Loader",
    author = "EpsilonBSP",
    description = "Provides sm_loadmap command for downloading and loading maps on demand.",
    version = PLUGIN_VERSION,
    url = ""
};

public void OnPluginStart() {
    g_MapList = new ArrayList(ByteCountToCells(128));
    LoadMapList();

    RegAdminCmd("sm_loadmap", Command_LoadMap, ADMFLAG_CHANGEMAP, "Load a map. Usage: sm_loadmap [mapname]");
}

void LoadMapList() {
    g_MapList.Clear();

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), MAP_LIST_PATH);

    File f = OpenFile(path, "r");

    if (f == null) {
        LogError("[MapLoader] Could not open map list: %s", path);

        return;
    }

    char line[128];

    while (f.ReadLine(line, sizeof(line))) {
        TrimString(line);

        if (line[0] == '\0' || line[0] == '#' || (line[0] == '/' && line[1] == '/')) {
            continue;
        }

        g_MapList.PushString(line);
    }

    delete f;
    LogMessage("[MapLoader] Loaded %d maps from %s", g_MapList.Length, path);
}

void GetMapCategory(const char[] map_name, char[] category, int maxlen) {
    if (StrContains(map_name, "kz_bhop_", false) == 0) {
        strcopy(category, maxlen, "kz_bhop");
    } else if (StrContains(map_name, "bhop_", false) == 0) {
        strcopy(category, maxlen, "bhop");
    } else if (StrContains(map_name, "kz_", false) == 0) {
        strcopy(category, maxlen, "kz");
    } else if (StrContains(map_name, "surf_", false) == 0) {
        strcopy(category, maxlen, "surf");
    } else if (StrContains(map_name, "xc_", false) == 0) {
        strcopy(category, maxlen, "xc");
    } else if (StrContains(map_name, "trikz_", false) == 0) {
        strcopy(category, maxlen, "trikz");
    } else {
        strcopy(category, maxlen, "other");
    }
}

public Action Command_LoadMap(int client, int args) {
    if (client == 0) {
        ReplyToCommand(client, "[MapLoader] This command must be used in-game.");

        return Plugin_Handled;
    }

    if (g_MapList.Length == 0) {
        ReplyToCommand(client, "[MapLoader] Map list is empty. Check %s", MAP_LIST_PATH);

        return Plugin_Handled;
    }

    if (args >= 1) {
        char query[128];
        GetCmdArg(1, query, sizeof(query));
        ShowFilteredMapMenu(client, query);
    } else {
        ShowCategoryMenu(client);
    }

    return Plugin_Handled;
}

static const char g_CatKeys[][] = {
    "bhop",
    "kz_bhop",
    "kz",
    "surf",
    "xc",
    "trikz",
    "other"
};

static const char g_CatLabels[][] = {
    "bhop_",
    "kz_bhop_",
    "kz_",
    "surf_",
    "xc_",
    "trikz_",
    "(other)"
};

void ShowCategoryMenu(int client) {
    Menu menu = new Menu(MenuHandler_Category);
    menu.SetTitle("Map Loader - Select Category");

    char map_name[128];
    char cat[64];

    for (int i = 0; i < sizeof(g_CatKeys); i++) {
        for (int j = 0; j < g_MapList.Length; j++) {
            g_MapList.GetString(j, map_name, sizeof(map_name));
            GetMapCategory(map_name, cat, sizeof(cat));

            if (StrEqual(cat, g_CatKeys[i], false)) {
                menu.AddItem(g_CatKeys[i], g_CatLabels[i]);

                break;
            }
        }
    }

    if (menu.ItemCount == 0) {
        PrintToChat(client, "[MapLoader] No maps loaded. Check %s", MAP_LIST_PATH);
        delete menu;

        return;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Category(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char prefix[64];
        menu.GetItem(param2, prefix, sizeof(prefix));
        ShowCategoryMapsMenu(param1, prefix);
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void ShowCategoryMapsMenu(int client, const char[] category) {
    char title[128];

    if (StrEqual(category, "other", false)) {
        Format(title, sizeof(title), "Maps - (other)");
    } else {
        Format(title, sizeof(title), "Maps - %s_", category);
    }

    Menu menu = new Menu(MenuHandler_CategoryMapSelect);
    menu.SetTitle(title);
    menu.ExitBackButton = true;

    char map_name[128];
    char mapCat[64];

    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, map_name, sizeof(map_name));
        GetMapCategory(map_name, mapCat, sizeof(mapCat));

        if (StrEqual(mapCat, category, false))
            menu.AddItem(map_name, map_name);
    }

    if (menu.ItemCount == 0) {
        PrintToChat(client, "[MapLoader] No maps found in this category.");
        delete menu;

        return;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

void ShowFilteredMapMenu(int client, const char[] query) {
    char title[160];
    Format(title, sizeof(title), "Maps matching \"%s\"", query);

    Menu menu = new Menu(MenuHandler_MapSelect);
    menu.SetTitle(title);

    char map_name[128];

    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, map_name, sizeof(map_name));

        if (StrContains(map_name, query, false) != -1) {
            menu.AddItem(map_name, map_name);
        }
    }

    if (menu.ItemCount == 0) {
        PrintToChat(client, "[MapLoader] No maps matching \"%s\" found.", query);
        delete menu;

        return;
    }

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_CategoryMapSelect(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char map_name[128];
        menu.GetItem(param2, map_name, sizeof(map_name));
        ShowConfirmMenu(param1, map_name);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowCategoryMenu(param1);
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

public int MenuHandler_MapSelect(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char map_name[128];
        menu.GetItem(param2, map_name, sizeof(map_name));
        ShowConfirmMenu(param1, map_name);
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void ShowConfirmMenu(int client, const char[] map_name) {
    Menu menu = new Menu(MenuHandler_Confirm);

    char title[160];
    Format(title, sizeof(title), "Change map to:\n%s", map_name);
    menu.SetTitle(title);

    menu.AddItem(map_name, "Yes, change map");
    menu.AddItem("", "No, cancel");

    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Confirm(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char info[128];
        menu.GetItem(param2, info, sizeof(info));

        if (info[0] != '\0') {
            ChangeToMap(param1, info);
        }
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void ChangeToMap(int client, const char[] map_name) {
    char bsp_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bsp_path, sizeof(bsp_path), "../../maps/%s.bsp", map_name);

    if (FileExists(bsp_path)) {
        PrintToChatAll("[MapLoader] %N is changing map to \x04%s\x01.", client, map_name);
        MapCountdownTick(map_name, 5);

        return;
    }

    char url[512];
    Format(url, sizeof(url), "%s%s.bsp.bz2", DOWNLOAD_BASE_URL, map_name);

    char bz2_path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bz2_path, sizeof(bz2_path), "../../maps/%s.bsp.bz2", map_name);

    PrintToChatAll("[MapLoader] Downloading %s, please wait...", map_name);
    PrintToServer("[MapLoader] Downloading %s -> %s", url, bz2_path);

    DataPack pack = new DataPack();
    pack.WriteString(map_name);

    HTTPRequest req = new HTTPRequest(url);
    req.DownloadFile(bz2_path, OnMapDownloaded, pack);
}

void OnMapDownloaded(HTTPStatus status, any value, const char[] error) {
    DataPack pack = view_as<DataPack>(value);
    pack.Reset();

    char map_name[128];
    pack.ReadString(map_name, sizeof(map_name));
    delete pack;

    if (status != HTTPStatus_OK) {
        PrintToChatAll("[MapLoader] Download failed for %s (HTTP %d).", map_name, status);
        PrintToServer("[MapLoader] Download failed for %s: HTTP %d - %s", map_name, status, error);

        return;
    }

    char game_folder[64];
    GetGameFolderName(game_folder, sizeof(game_folder));

    char bz2_path[PLATFORM_MAX_PATH];
    Format(bz2_path, sizeof(bz2_path), "%s/maps/%s.bsp.bz2", game_folder, map_name);

    char bsp_path[PLATFORM_MAX_PATH];
    Format(bsp_path, sizeof(bsp_path), "%s/maps/%s.bsp", game_folder, map_name);

    PrintToChatAll("[MapLoader] Decompressing %s...", map_name);
    PrintToServer("[MapLoader] Decompressing %s -> %s", bz2_path, bsp_path);

    DataPack bz2_pack = new DataPack();
    bz2_pack.WriteString(map_name);

    Bzip2_DecompressFileAsync(bz2_path, bsp_path, OnMapDecompressed, bz2_pack);
}

void OnMapDecompressed(Bzip2_Error error, const char[] src, const char[] dest, any data) {
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();

    char map_name[128];
    pack.ReadString(map_name, sizeof(map_name));
    delete pack;

    if (error != BZIP2_OK) {
        PrintToChatAll("[MapLoader] Decompression failed for %s.", map_name);
        PrintToServer("[MapLoader] Decompression failed for %s (error %d)", map_name, error);

        return;
    }

    DeleteFile(src);

    MapCountdownTick(map_name, 5);
}

void MapCountdownTick(const char[] map_name, int count) {
    if (count == 0) {
        PrintToChatAll("[MapLoader] Changing map to \x04%s\x01!", map_name);
        ForceChangeLevel(map_name, "Admin map change");

        return;
    }

    PrintToChatAll("[MapLoader] Changing map in \x04%d\x01...", count);

    DataPack pack = new DataPack();
    pack.WriteString(map_name);
    pack.WriteCell(count - 1);

    CreateTimer(1.0, Timer_MapCountdown, pack, TIMER_DATA_HNDL_CLOSE);
}

public Action Timer_MapCountdown(Handle timer, DataPack pack) {
    pack.Reset();

    char map_name[128];
    pack.ReadString(map_name, sizeof(map_name));

    int next_count = pack.ReadCell();

    MapCountdownTick(map_name, next_count);

    return Plugin_Stop;
}
