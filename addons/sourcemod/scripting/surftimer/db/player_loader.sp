static float g_playerLoadStart[MAXPLAYERS + 1];
static float g_playerLoadTick[MAXPLAYERS + 1];
static PlayerLoadState g_playerLoadState[MAXPLAYERS + 1];
static int g_playerLoadStep[MAXPLAYERS + 1];
static int g_playerLoadUid[MAXPLAYERS + 1];
static int g_playerNextUid = 0;

void LoadPlayerStart(int client) {
	g_playerNextUid++;
	g_playerLoadUid[client] = g_playerNextUid;
	g_playerLoadState[client] = PLS_PENDING;
	LoadPlayerNext();
}
void LoadPlayerNext() {
	if (!IsMapLoaded()) {
		// map not loaded yet
		return;
	}
	int found = 0;
	for (int client = 1; client <= MaxClients; client++) {
		if (g_playerLoadState[client] == PLS_LOADING) {
			// some other player already loading
			return;
		} else if (g_playerLoadState[client] == PLS_PENDING && found == 0) {
			found = client;
		}
	}
	if (found > 0) {
		int client = found;
		g_playerLoadState[client] = PLS_LOADING;
		g_playerLoadStep[client] = 0;
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, MAX_NAME_LENGTH);
		LogToFileEx(g_szLogFile, "[surftimer] Starting to load player settings for %s", sName);
		g_playerLoadStart[client] = GetGameTime();
		LoadPlayerStep(client);
	}
}
void LoadPlayerStop(int client) {
	g_playerLoadUid[client] = 0;
	g_playerLoadState[client] = PLS_UNLOADED;
	LoadPlayerNext();
}
void LoadPlayerContinue(DataPack cb, bool error) {
	int client = cb.ReadCell();
	int completedPlayerUid = cb.ReadCell();
	int completedStep = cb.ReadCell();
	CloseHandle(cb);

	if (completedStep != g_playerLoadStep[client] || completedPlayerUid != g_playerLoadUid[client]) {
		// Outdated step -- just stop here
		return;
	}
	if (error) {
		g_playerLoadState[client] = PLS_ERROR;
		LoadPlayerNext();
		return;
	}

	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, sizeof(szName));
	float time = GetGameTime() - g_playerLoadTick[client];
	LogToFileEx(g_szLogFile, "[Surftimer] %s<%s>: Finished load step %i in %fs", szName, g_szSteamID[client], g_playerLoadStep[client], time);
	g_playerLoadStep[client]++;
	SetClanTag(client);

	LoadPlayerStep(client);
}
void LoadPlayerStep(int client) {
	CreateTimer(0.0, LoadPlayerStep2, client, TIMER_FLAG_NO_MAPCHANGE);
}
Action LoadPlayerStep2(Handle timer, int client) {
	Function step = INVALID_FUNCTION;
	switch(g_playerLoadStep[client]) {
		case 0: { step = db_refreshPlayerMapRecords; }
		case 1: { step = db_refreshPlayerPoints; }
		case 2: { step = db_GetPlayerRank; }
		case 3: { step = db_viewPlayerOptions; }
		case 4: { step = db_refreshCustomTitles; }
		case 5: { step = db_refreshCheckpoints; }
	}
	if (step != INVALID_FUNCTION) {
		g_playerLoadTick[client] = GetGameTime();
		DataPack cb = CreateDataPack();
		cb.WriteFunction(LoadPlayerContinue);
		cb.WriteCell(client);
		cb.WriteCell(g_playerLoadUid[client]);
		cb.WriteCell(g_playerLoadStep[client]);
		Call_StartFunction(null, step);
		Call_PushCell(client);
		Call_PushCell(cb);
		Call_Finish();
	} else if (g_playerLoadState[client] == PLS_LOADING) {
		LoadPlayerFinished(client);
	}
}
void LoadPlayerFinished(int client) {
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, MAX_NAME_LENGTH);
	float time = GetGameTime() - g_playerLoadStart[client];
	LogToFileEx(g_szLogFile, "[Surftimer] %s<%s>: Finished loading in %fs", szName, g_szSteamID[client], time);

	g_playerLoadState[client] = PLS_LOADED;
	db_UpdateLastSeen(client);

	if (GetConVarBool(g_hTeleToStartWhenSettingsLoaded) && IsPlayerAlive(client)) {
		Command_Restart(client, 1);
		CreateTimer(0.1, RestartPlayer, client);
	}

	LoadPlayerNext();
}
typedef SQLTPlayerCallback = function void (Handle hndl, const char[] error, int client, any data);
void SQL_PlayerQuery(const char[] query, SQLTPlayerCallback callback, int client, any data=0) {
	DataPack newData = CreateDataPack();
	newData.WriteFunction(callback);
	newData.WriteCell(client);
	newData.WriteCell(g_playerLoadUid[client]);
	newData.WriteCell(data);

	if (!IsValidClient(client)) {
		SQL_PlayerQueryCb(INVALID_HANDLE, INVALID_HANDLE, "Client is not valid", newData);
		return;
	}
	char query2[4096];
	strcopy(query2, sizeof(query2), query);
	if (StrContains(query2, "__name__")) {
		char szName[MAX_NAME_LENGTH];
		GetClientName(client, szName, sizeof(szName));
		char szNameEx[MAX_NAME_LENGTH*2+1];
		SQL_EscapeString(g_hDb, szName, szNameEx, sizeof(szNameEx));
		ReplaceString(query2, sizeof(query2), "__name__", szNameEx);
	}
	if (StrContains(query2, "__mapname__")) {
		char szNameEx[MAX_NAME_LENGTH*2+1];
		SQL_EscapeString(g_hDb, g_szMapName, szNameEx, sizeof(szNameEx));
		ReplaceString(query2, sizeof(query2), "__mapname__", szNameEx);
	}
	if (StrContains(query2, "__steamid__")) {
		if (StrEqual(g_szSteamID[client], "")) {
			SQL_PlayerQueryCb(INVALID_HANDLE, INVALID_HANDLE, "STEAMID not loaded for player", newData);
			return;
		}
		char szSteamidEx[MAX_STEAMID_LENGTH*2+1];
		SQL_EscapeString(g_hDb, g_szSteamID[client], szSteamidEx, sizeof(szSteamidEx));
		ReplaceString(query2, sizeof(query2), "__steamid__", szSteamidEx);
	}

	SQL_TQuery(g_hDb, SQL_PlayerQueryCb, query2, newData);
}
void SQL_PlayerQueryCb(Handle owner, Handle hndl, const char[] error, DataPack newData) {
	newData.Reset();
	Function callback = newData.ReadFunction();
	int client = newData.ReadCell();
	int olduid = newData.ReadCell();
	any data = newData.ReadCell();
	CloseHandle(newData);
	if (olduid != g_playerLoadUid[client]) {
		return;
	}
	Call_StartFunction(null, callback);
	Call_PushCell(hndl);
	Call_PushString(error);
	Call_PushCell(client);
	Call_PushCell(data);
	Call_Finish();
}

PlayerLoadState GetPlayerLoadState(int client) {
	return g_playerLoadState[client];
}
int GetPlayerLoadStep(int client) {
	return g_playerLoadStep[client];
}
int GetPlayerLoadStepMax() {
	return MAX_LOAD_STEPS;
}
bool IsPlayerLoaded(int client) {
	return g_playerLoadState[client] == PLS_LOADED;
}
