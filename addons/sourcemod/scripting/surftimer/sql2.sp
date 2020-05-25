// sm_pr command
public void db_viewPlayerPr(int client, char szSteamId[32], char szMapName[128])
{
	char szQuery[1024];
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamId);

	char szUpper[128];
	char szUpper2[128];
	Format(szUpper, 128, "%s", szMapName);
	Format(szUpper2, 128, "%s", g_szMapName);
	StringToUpper(szUpper);
	StringToUpper(szUpper2);

	if (StrEqual(szUpper, szUpper2)) // is the mapname the current map?
	{
		WritePackString(pack, szMapName);
		WritePackCell(pack, g_TotalStages);
		WritePackCell(pack, g_mapZoneGroupCount);
		// first select map time
		Format(szQuery, sizeof(szQuery), "SELECT steamid, name, mapname, runtimepro, (select count(name) FROM ck_playertimes WHERE mapname = '%s' AND style = 0) as total FROM ck_playertimes WHERE runtimepro <= (SELECT runtimepro FROM ck_playertimes WHERE steamid = '%s' AND mapname = '%s' AND runtimepro > -1.0 AND style = 0) AND mapname = '%s' AND runtimepro > -1.0 AND style = 0 ORDER BY runtimepro;", szMapName, szSteamId, szMapName, szMapName);
		g_hDb.Query(SQL_ViewPlayerPrMaptimeCallback, szQuery, pack);
	}
	else
	{
		Format(szQuery, sizeof(szQuery), "SELECT mapname FROM ck_maptier WHERE mapname LIKE '%c%s%c' LIMIT 1;", PERCENT, szMapName, PERCENT);
		g_hDb.Query(SQL_ViewMapNamePrCallback, szQuery, pack);
	}
}

public void SQL_ViewMapNamePrCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_ViewMapNamePrCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	ReadPackString(pack, szSteamId, 32);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szMapName[128];
		SQL_FetchString(hndl, 0, szMapName, 128);
		WritePackString(pack, szMapName);

		char szQuery[1024];
		Format(szQuery, sizeof(szQuery), "SELECT mapname, (SELECT COUNT(1) FROM ck_zones WHERE zonetype = '3' AND mapname = '%s') AS stages, (SELECT COUNT(DISTINCT zonegroup) FROM ck_zones WHERE mapname = '%s' AND zonegroup > 0) AS bonuses FROM ck_maptier WHERE mapname = '%s';", szMapName, szMapName, szMapName);
		g_hDb.Query(SQL_ViewPlayerPrMapInfoCallback, szQuery, pack);
	}
	else
	{
		delete pack;
		CPrintToChat(client, "%t", "SQLTwo1", g_szChatPrefix);
	}
}

public void SQL_ViewPlayerPrMapInfoCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_ViewPlayerPrMapInfoCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char szMapName[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, szMapName, 128);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_totalStagesPr[client] = SQL_FetchInt(hndl, 1);
		g_totalBonusesPr[client] = SQL_FetchInt(hndl, 2);

		if (g_totalStagesPr[client] != 0)
			g_totalStagesPr[client]++;

		if (g_totalBonusesPr[client] != 0)
			g_totalBonusesPr[client]++;

		char szQuery[1024];
		Format(szQuery, sizeof(szQuery), "SELECT steamid, name, mapname, runtimepro, (select count(name) FROM ck_playertimes WHERE mapname = '%s' AND style = 0) as total FROM ck_playertimes WHERE runtimepro <= (SELECT runtimepro FROM ck_playertimes WHERE steamid = '%s' AND mapname = '%s' AND runtimepro > -1.0 AND style = 0) AND mapname = '%s' AND runtimepro > -1.0 AND style = 0 ORDER BY runtimepro;", szMapName, szSteamId, szMapName, szMapName);
		g_hDb.Query(SQL_ViewPlayerPrMaptimeCallback, szQuery, pack);
	}
	else
	{
		delete pack;
	}
}

public void SQL_ViewPlayerPrMaptimeCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_ViewPlayerPrMaptimeCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char szMapName[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, szMapName, 128);

	float time = -1.0;
	int total;
	int rank = 0;
	if (SQL_HasResultSet(hndl) && IsValidClient(client))
	{
		int i = 1;
		char szSteamId2[32];
		while (SQL_FetchRow(hndl))
		{
			if (i == 1)
				total = SQL_FetchInt(hndl, 4);
			i++;
			rank++;

			SQL_FetchString(hndl, 0, szSteamId2, 32);
			if (StrEqual(szSteamId, szSteamId2))
			{
				time = SQL_FetchFloat(hndl, 3);
				break;
			}
			else
				continue;
		}
	}
	else
	{
		time = -1.0;
	}

	// CPrintToChat(client, "total: %i , runtimepro: %f", total, time);

	WritePackFloat(pack, time);
	WritePackCell(pack, total);
	WritePackCell(pack, rank);

	char szQuery[1024];

	Format(szQuery, sizeof(szQuery), "SELECT db1.steamid, db1.name, db1.mapname, db1.runtimepro, db1.stage, (SELECT count(name) FROM ck_wrcps WHERE style = 0 AND mapname = db1.mapname AND stage = db1.stage AND runtimepro > -1.0 AND runtimepro <= db1.runtimepro) AS rank, (SELECT count(name) FROM ck_wrcps WHERE style = 0 AND mapname = db1.mapname AND stage = db1.stage AND runtimepro > -1.0) AS total FROM ck_wrcps db1 WHERE db1.mapname = '%s' AND db1.steamid = '%s' AND db1.runtimepro > -1.0 AND db1.style = 0 ORDER BY stage ASC", szMapName, szSteamId);
	g_hDb.Query(SQL_ViewPlayerPrMaptimeCallback2, szQuery, pack);
}

public void SQL_ViewPlayerPrMaptimeCallback2(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_ViewPlayerPrMaptimeCallback2): %s ", error);
	}

	char szSteamId[32];
	char szMapName[128];

	ResetPack(pack);
	int client = ReadPackCell(pack);
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, szMapName, 128);
	float time = ReadPackFloat(pack);
	int total = ReadPackCell(pack);
	int rank = ReadPackCell(pack);
	delete pack;

	int target = g_iPrTarget[client];
	int stage;
	int stagerank[CPLIMIT];
	int totalcompletes[CPLIMIT];
	int totalstages = 0;
	float stagetime[CPLIMIT];

	for (int i = 1; i < CPLIMIT; i++)
	{
		stagetime[i] = -1.0;
		stagerank[i] = 0;
		totalcompletes[i] = 0;
	}

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			totalstages++;
			stage = SQL_FetchInt(hndl, 4);
			stagetime[stage] = SQL_FetchFloat(hndl, 3);
			stagerank[stage] = SQL_FetchInt(hndl, 5);
			totalcompletes[stage] = SQL_FetchInt(hndl, 6);
		}
	}

	char szMapInfo[256];
	char szRuntimepro[64];
	char szStageInfo[CPLIMIT][256];
	char szRuntimestages[CPLIMIT][64];
	char szBonusInfo[MAX_ZONEGROUPS][256];

	Menu menu;
	menu = CreateMenu(PrMenuHandler);
	char szName[MAX_NAME_LENGTH];
	GetClientName(target, szName, sizeof(szName));

	SetMenuTitle(menu, "Personal Record for %s\n%s\n \n", szName, szMapName);
	if (time != -1.0)
	{
		FormatTimeFloat(0, time, 3, szRuntimepro, 64);
		Format(szMapInfo, 256, "Map Time: %s\nRank: %i/%i\n \n", szRuntimepro, rank, total);
	}
	else
	{
		Format(szMapInfo, 256, "Map Time: None\n \n", szRuntimepro, rank, total);
	}
	AddMenuItem(menu, "map", szMapInfo);

	if (StrEqual(szMapName, g_szMapName))
	{
		g_totalBonusesPr[client] = g_mapZoneGroupCount;

		if (g_bhasStages)
			g_totalStagesPr[client] = g_TotalStages;
		else
			g_totalStagesPr[client] = 0;
	}

	if (g_totalStagesPr[client] > 0)
	{
		for (int i = 1;i <= g_totalStagesPr[client]; i++)
		{
			if (stagetime[i] != -1.0)
			{
				FormatTimeFloat(0, stagetime[i], 3, szRuntimestages[i], 64);
				Format(szStageInfo[i], 256, "Stage %i: %s\nRank: %i/%i\n \n", i, szRuntimestages[i], stagerank[i], totalcompletes[i]);
			}
			else
			{
				Format(szStageInfo[i], 256, "Stage %i: None\n \n", i);
			}

			AddMenuItem(menu, "stage", szStageInfo[i]);
		}
	}

	if (g_totalBonusesPr[client] > 1)
	{
		for (int i = 1; i < g_totalBonusesPr[client]; i++)
		{
			if (g_fPersonalRecordBonus[i][client] != 0.0)
				Format(szBonusInfo[i], 256, "Bonus %i: %s\nRank: %i/%i\n \n", i, g_szPersonalRecordBonus[i][target], g_MapRankBonus[i][target], g_iBonusCount[i]);
			else
				Format(szBonusInfo[i], 256, "Bonus %i: None\n \n", i);

			AddMenuItem(menu, "bonus", szBonusInfo[i]);
		}
	}

	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return;
}

public int PrMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{

	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void db_checkCustomPlayerNameColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);
	WritePackString(pack, arg);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "SELECT `steamid` FROM `ck_vipadmins` WHERE `steamid` = '%s';", szSteamID);
	g_hDb.Query(SQL_checkCustomPlayerNameColourCallback, szQuery, pack);

}

public void SQL_checkCustomPlayerNameColourCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[surftimer] SQL Error (SQL_checkCustomPlayerTitleCallback): %s", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	char arg[128];
	ReadPackString(pack, szSteamID, 32);
	ReadPackString(pack, arg, 128);
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		db_updateCustomPlayerNameColour(client, szSteamID, arg);
	}
	else
	{
		CPrintToChat(client, "%t", "SQLTwo2", g_szChatPrefix);
	}
}

public void db_checkCustomPlayerTextColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);
	WritePackString(pack, arg);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "SELECT `steamid` FROM `ck_vipadmins` WHERE `steamid` = '%s';", szSteamID);
	g_hDb.Query(SQL_checkCustomPlayerTextColourCallback, szQuery, pack);

}

public void SQL_checkCustomPlayerTextColourCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[surftimer] SQL Error (SQL_checkCustomPlayerTextColourCallback): %s", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	char arg[128];
	ReadPackString(pack, szSteamID, 32);
	ReadPackString(pack, arg, 128);
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		db_updateCustomPlayerTextColour(client, szSteamID, arg);
	}
	else
	{
		CPrintToChat(client, "%t", "SQLTwo3", g_szChatPrefix);
	}
}

public void db_updateCustomPlayerNameColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `ck_vipadmins` SET `namecolour` = '%s' WHERE `steamid` = '%s';", arg, szSteamID);
	g_hDb.Query(SQL_updateCustomPlayerNameColourCallback, szQuery, pack);
}

public void SQL_updateCustomPlayerNameColourCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	ReadPackString(pack, szSteamID, 32);
	delete pack;

	PrintToServer("Successfully updated custom player colour");
	db_refreshCustomTitles(client);
}

public void db_updateCustomPlayerTextColour(int client, char[] szSteamID, char[] arg)
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szSteamID);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "UPDATE `ck_vipadmins` SET `textcolour` = '%s' WHERE `steamid` = '%s';", arg, szSteamID);
	g_hDb.Query(SQL_updateCustomPlayerTextColourCallback, szQuery, pack);
}

public void SQL_updateCustomPlayerTextColourCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamID[32];
	ReadPackString(pack, szSteamID, 32);
	delete pack;

	PrintToServer("Successfully updated custom player text colour");
	db_refreshCustomTitles(client);
}

public void db_updateColours(int client, char szSteamId[32], int newColour, int type)
{
	char szQuery[512];
	switch (type)
	{
		case 0: Format(szQuery, sizeof(szQuery), "UPDATE ck_vipadmins SET namecolour = %i WHERE steamid = '%s';", newColour, szSteamId);
		case 1: Format(szQuery, sizeof(szQuery), "UPDATE ck_vipadmins SET textcolour = %i WHERE steamid = '%s';", newColour, szSteamId);
	}

	g_hDb.Query(SQL_UpdatePlayerColoursCallback, szQuery, client);
}

public void SQL_UpdatePlayerColoursCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_UpdatePlayerColoursCallback): %s", error);
		return;
	}

	g_bUpdatingColours[client] = true;
	db_refreshCustomTitles(client);
}

// fluffys end custom titles

// WR Announcements

public void db_insertAnnouncement(char szName[MAX_NAME_LENGTH], char szMapName[128], char szTime[32])
{
	if (g_iServerID == -1)
		return;

	char szQuery[512];
	char szEscServerName[128];
	SQL_EscapeString(g_hDb, g_sServerName, szEscServerName, sizeof(szEscServerName));
	Format(szQuery, sizeof(szQuery), "INSERT INTO `ck_announcements` (`server`, `name`, `mapname`, `time`) VALUES ('%s', '%s', '%s', '%s');", szEscServerName, szName, szMapName, szTime);
	g_hDb.Query(SQL_CheckCallback, szQuery);
}

public void db_checkAnnouncements()
{
	char szQuery[512];
	char szEscServerName[128];
	SQL_EscapeString(g_hDb, g_sServerName, szEscServerName, sizeof(szEscServerName));
	Format(szQuery, sizeof(szQuery), "SELECT `id`, `server`, `name`, `mapname`, `time`, FROM `ck_announcements` WHERE `server` != '%s' AND `id` > %d;", szEscServerName, g_iLastID);
	g_hDb.Query(SQL_CheckAnnouncementsCallback, szQuery);
}

public void SQL_CheckAnnouncementsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_CheckAnnouncementsCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			int id = SQL_FetchInt(hndl, 0);
			char szServerName[256], szName[32], szMapName[128], szTime[32];
			SQL_FetchString(hndl, 1, szServerName, sizeof(szServerName));
			SQL_FetchString(hndl, 2, szName, sizeof(szName));
			SQL_FetchString(hndl, 3, szMapName, sizeof(szMapName));
			SQL_FetchString(hndl, 4, szTime, sizeof(szTime));

			if (id > g_iLastID)
			{
				// Send Server Announcement
				g_iLastID = id;
				CPrintToChatAll("%t", "SQLTwo4.1");
				CPrintToChatAll("%t", "SQLTwo4.2", g_szChatPrefix, szName, szMapName, szServerName, szTime);
				CPrintToChatAll("%t", "SQLTwo4.3");
			}
		}
	}
}

public void db_selectCPR(int client, int rank, const char szMapName[128], const char szSteamId[32])
{
	Handle pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, rank);
	WritePackString(pack, szSteamId);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `steamid` = '%s' AND `mapname` LIKE '%c%s%c' AND style = 0", g_szSteamID[client], PERCENT, szMapName, PERCENT);
	g_hDb.Query(SQL_SelectCPRTimeCallback, szQuery, pack);
}

public void SQL_SelectCPRTimeCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_SelectCPRTimeCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 2, g_szCPRMapName[client], 128);
		g_fClientCPs[client][0] = SQL_FetchFloat(hndl, 3);

		char szQuery[512];
		Format(szQuery, sizeof(szQuery), "SELECT cp1, cp2, cp3, cp4, cp5, cp6, cp7, cp8, cp9, cp10, cp11, cp12, cp13, cp14, cp15, cp16, cp17, cp18, cp19, cp20, cp21, cp22, cp23, cp24, cp25, cp26, cp27, cp28, cp29, cp30, cp31, cp32, cp33, cp34, cp35 FROM ck_checkpoints WHERE steamid = '%s' AND mapname LIKE '%c%s%c' AND zonegroup = 0;", g_szSteamID[client], PERCENT, g_szCPRMapName[client], PERCENT);
		g_hDb.Query(SQL_SelectCPRCallback, szQuery, pack);
	}
	else
	{
		CPrintToChat(client, "%t", "SQLTwo7", g_szChatPrefix);
		delete pack;
	}
}

public void SQL_SelectCPRCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_SelectCPRCallback): %s", error);
		delete pack;
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		ResetPack(pack);
		int client = ReadPackCell(pack);

		for (int i = 1; i < 36; i++)
		{
			g_fClientCPs[client][i] = SQL_FetchFloat(hndl, i - 1);
		}
		db_selectCPRTarget(pack);
	}
}

public void db_selectCPRTarget(DataPack pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int rank = ReadPackCell(pack);
	rank = rank - 1;

	char szQuery[512];
	if (rank == -1)
	{
		char szSteamId[32];
		ReadPackString(pack, szSteamId, 32);
		Format(szQuery, sizeof(szQuery), "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `mapname` LIKE '%c%s%c' AND steamid = '%s' AND style = 0", PERCENT, g_szCPRMapName[client], PERCENT, szSteamId);
	}
	else
		Format(szQuery, sizeof(szQuery), "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `mapname` LIKE '%c%s%c' AND style = 0 ORDER BY `runtimepro` ASC LIMIT %i, 1;", PERCENT, g_szCPRMapName[client], PERCENT, rank);
	g_hDb.Query(SQL_SelectCPRTargetCallback, szQuery, pack);
}

public void SQL_SelectCPRTargetCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_SelectCPRTargetCallback): %s", error);
		delete pack;
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		ResetPack(pack);
		int client = ReadPackCell(pack);

		char szSteamId[32];
		SQL_FetchString(hndl, 0, szSteamId, sizeof(szSteamId));
		SQL_FetchString(hndl, 1, g_szTargetCPR[client], sizeof(g_szTargetCPR));
		g_fTargetTime[client] = SQL_FetchFloat(hndl, 3);
		db_selectCPRTargetCPs(szSteamId, pack);
	}
}

public void db_selectCPRTargetCPs(const char[] szSteamId, DataPack pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);

	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "SELECT cp1, cp2, cp3, cp4, cp5, cp6, cp7, cp8, cp9, cp10, cp11, cp12, cp13, cp14, cp15, cp16, cp17, cp18, cp19, cp20, cp21, cp22, cp23, cp24, cp25, cp26, cp27, cp28, cp29, cp30, cp31, cp32, cp33, cp34, cp35 FROM ck_checkpoints WHERE steamid = '%s' AND mapname LIKE '%c%s%c' AND zonegroup = 0;", szSteamId, PERCENT, g_szCPRMapName[client], PERCENT);
	g_hDb.Query(SQL_SelectCPRTargetCPsCallback, szQuery, pack);
}

public void SQL_SelectCPRTargetCPsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_SelectCPRTargetCPsCallback): %s", error);
		delete pack;
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		ResetPack(pack);
		int client = ReadPackCell(pack);
		int rank = ReadPackCell(pack);

		Menu menu = CreateMenu(CPRMenuHandler);
		char szTitle[256], szName[MAX_NAME_LENGTH];
		GetClientName(client, szName, sizeof(szName));
		Format(szTitle, sizeof(szTitle), "%s VS %s on %s\n \n", szName, g_szTargetCPR[client], g_szCPRMapName[client], rank);
		SetMenuTitle(menu, szTitle);

		float targetCPs, comparedCPs;
		char szCPR[32], szCompared[32], szItem[256];

		for (int i = 1; i < 36; i++)
		{
			targetCPs = SQL_FetchFloat(hndl, i - 1);
			comparedCPs = (g_fClientCPs[client][i] - targetCPs);

			if (targetCPs == 0.0 || g_fClientCPs[client][i] == 0.0)
				continue;
			FormatTimeFloat(client, targetCPs, 3, szCPR, sizeof(szCPR));
			FormatTimeFloat(client, comparedCPs, 6, szCompared, sizeof(szCompared));
			Format(szItem, sizeof(szItem), "CP %i: %s (%s)", i, szCPR, szCompared);
			AddMenuItem(menu, "", szItem, ITEMDRAW_DISABLED);
		}

		char szTime[32], szCompared2[32];
		float compared = g_fClientCPs[client][0] - g_fTargetTime[client];
		FormatTimeFloat(client, g_fClientCPs[client][0], 3, szTime, sizeof(szTime));
		FormatTimeFloat(client, compared, 6, szCompared2, sizeof(szCompared2));
		Format(szItem, sizeof(szItem), "Total Time: %s (%s)", szTime, szCompared2);
		AddMenuItem(menu, "", szItem, ITEMDRAW_DISABLED);
		SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}

	delete pack;
}

public int CPRMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
}
