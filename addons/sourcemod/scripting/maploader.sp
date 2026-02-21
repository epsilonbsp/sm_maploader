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

void GetMapCategory(const char[] mapName, char[] category, int maxlen) {
    if (StrContains(mapName, "kz_bhop_", false) == 0) {
        strcopy(category, maxlen, "kz_bhop");
    } else if (StrContains(mapName, "bhop_", false) == 0) {
        strcopy(category, maxlen, "bhop");
    } else if (StrContains(mapName, "kz_", false) == 0) {
        strcopy(category, maxlen, "kz");
    } else if (StrContains(mapName, "surf_", false) == 0) {
        strcopy(category, maxlen, "surf");
    } else if (StrContains(mapName, "xc_", false) == 0) {
        strcopy(category, maxlen, "xc");
    } else if (StrContains(mapName, "trikz_", false) == 0) {
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

    char mapName[128];
    char cat[64];

    for (int i = 0; i < sizeof(g_CatKeys); i++) {
        for (int j = 0; j < g_MapList.Length; j++) {
            g_MapList.GetString(j, mapName, sizeof(mapName));
            GetMapCategory(mapName, cat, sizeof(cat));

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

    char mapName[128];
    char mapCat[64];

    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, mapName, sizeof(mapName));
        GetMapCategory(mapName, mapCat, sizeof(mapCat));

        if (StrEqual(mapCat, category, false))
            menu.AddItem(mapName, mapName);
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

    char mapName[128];

    for (int i = 0; i < g_MapList.Length; i++) {
        g_MapList.GetString(i, mapName, sizeof(mapName));

        if (StrContains(mapName, query, false) != -1) {
            menu.AddItem(mapName, mapName);
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
        char mapName[128];
        menu.GetItem(param2, mapName, sizeof(mapName));
        ShowConfirmMenu(param1, mapName);
    } else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack) {
        ShowCategoryMenu(param1);
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

public int MenuHandler_MapSelect(Menu menu, MenuAction action, int param1, int param2) {
    if (action == MenuAction_Select) {
        char mapName[128];
        menu.GetItem(param2, mapName, sizeof(mapName));
        ShowConfirmMenu(param1, mapName);
    } else if (action == MenuAction_End) {
        delete menu;
    }

    return 0;
}

void ShowConfirmMenu(int client, const char[] mapName) {
    Menu menu = new Menu(MenuHandler_Confirm);

    char title[160];
    Format(title, sizeof(title), "Change map to:\n%s", mapName);
    menu.SetTitle(title);

    menu.AddItem(mapName, "Yes, change map");
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

void ChangeToMap(int client, const char[] mapName) {
    char bspPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bspPath, sizeof(bspPath), "../../maps/%s.bsp", mapName);

    if (FileExists(bspPath)) {
        PrintToChatAll("[MapLoader] %N is changing map to \x04%s\x01.", client, mapName);
        MapCountdownTick(mapName, 5);

        return;
    }

    char url[512];
    Format(url, sizeof(url), "%s%s.bsp.bz2", DOWNLOAD_BASE_URL, mapName);

    char bz2Path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, bz2Path, sizeof(bz2Path), "../../maps/%s.bsp.bz2", mapName);

    PrintToChatAll("[MapLoader] Downloading %s, please wait...", mapName);
    PrintToServer("[MapLoader] Downloading %s -> %s", url, bz2Path);

    DataPack pack = new DataPack();
    pack.WriteString(mapName);

    HTTPRequest req = new HTTPRequest(url);
    req.DownloadFile(bz2Path, OnMapDownloaded, pack);
}

void OnMapDownloaded(HTTPStatus status, any value, const char[] error) {
    DataPack pack = view_as<DataPack>(value);
    pack.Reset();

    char mapName[128];
    pack.ReadString(mapName, sizeof(mapName));
    delete pack;

    if (status != HTTPStatus_OK) {
        PrintToChatAll("[MapLoader] Download failed for %s (HTTP %d).", mapName, status);
        PrintToServer("[MapLoader] Download failed for %s: HTTP %d - %s", mapName, status, error);

        return;
    }

    char gameFolder[64];
    GetGameFolderName(gameFolder, sizeof(gameFolder));

    char bz2Path[PLATFORM_MAX_PATH];
    Format(bz2Path, sizeof(bz2Path), "%s/maps/%s.bsp.bz2", gameFolder, mapName);

    char bspPath[PLATFORM_MAX_PATH];
    Format(bspPath, sizeof(bspPath), "%s/maps/%s.bsp", gameFolder, mapName);

    PrintToChatAll("[MapLoader] Decompressing %s...", mapName);
    PrintToServer("[MapLoader] Decompressing %s -> %s", bz2Path, bspPath);

    DataPack bz2Pack = new DataPack();
    bz2Pack.WriteString(mapName);

    BZ2_DecompressFileAsync(bz2Path, bspPath, OnMapDecompressed, bz2Pack);
}

void OnMapDecompressed(BZ2Error error, const char[] src, const char[] dest, any data) {
    DataPack pack = view_as<DataPack>(data);
    pack.Reset();

    char mapName[128];
    pack.ReadString(mapName, sizeof(mapName));
    delete pack;

    if (error != BZ2_OK) {
        PrintToChatAll("[MapLoader] Decompression failed for %s.", mapName);
        PrintToServer("[MapLoader] Decompression failed for %s (error %d)", mapName, error);

        return;
    }

    DeleteFile(src);

    MapCountdownTick(mapName, 5);
}

void MapCountdownTick(const char[] mapName, int count) {
    if (count == 0) {
        PrintToChatAll("[MapLoader] Changing map to \x04%s\x01!", mapName);
        ForceChangeLevel(mapName, "Admin map change");

        return;
    }

    PrintToChatAll("[MapLoader] Changing map in \x04%d\x01...", count);

    DataPack pack = new DataPack();
    pack.WriteString(mapName);
    pack.WriteCell(count - 1);

    CreateTimer(1.0, Timer_MapCountdown, pack, TIMER_DATA_HNDL_CLOSE);
}

public Action Timer_MapCountdown(Handle timer, DataPack pack) {
    pack.Reset();

    char mapName[128];
    pack.ReadString(mapName, sizeof(mapName));

    int nextCount = pack.ReadCell();

    MapCountdownTick(mapName, nextCount);

    return Plugin_Stop;
}
