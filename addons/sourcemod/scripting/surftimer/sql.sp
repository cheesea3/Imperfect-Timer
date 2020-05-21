/*==================================
=          DATABASE SETUP          =
==================================*/

public void db_setupDatabase()
{
	/*===================================
	=    INIT CONNECTION TO DATABASE    =
	===================================*/
	char szError[255];
	g_hDb = SQL_Connect("surftimer", false, szError, 255);

	if (g_hDb == null)
	{
		SetFailState("[Surftimer] Unable to connect to database (%s)", szError);
		return;
	}

	SQL_SetCharset(g_hDb, "utf8mb4");

	char szIdent[8];
	SQL_ReadDriver(g_hDb, szIdent, 8);

	if (strcmp(szIdent, "mysql", false) == 0)
	{
		// https://github.com/nikooo777/ckSurf/pull/58
		//SQL_FastQuery(g_hDb, "SET sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''));");
		g_DbType = MYSQL;
	}
	else if (strcmp(szIdent, "sqlite", false) == 0)
	{
		SetFailState("[Surftimer] Sorry SQLite is not supported.");
		return;
	}
	else
	{
		SetFailState("[Surftimer] Invalid database type");
		return;
	}

	// If updating from a previous version
	SQL_LockDatabase(g_hDb);

	// If tables haven't been created yet.
	if (!SQL_FastQuery(g_hDb, "SELECT steamid FROM ck_playerrank LIMIT 1"))
	{
		SQL_UnlockDatabase(g_hDb);
		db_createTables();
		return;
	}

	// Check for db upgrades
	if (!SQL_FastQuery(g_hDb, "SELECT prespeed FROM ck_zones LIMIT 1"))
	{
		db_upgradeDatabase(0);
		return;
	}
	else if(!SQL_FastQuery(g_hDb, "SELECT ranked FROM ck_maptier LIMIT 1") || !SQL_FastQuery(g_hDb, "SELECT style FROM ck_playerrank LIMIT 1;"))
	{
		db_upgradeDatabase(1);
		return;
	}
	else if (!SQL_FastQuery(g_hDb, "SELECT wrcppoints FROM ck_playerrank LIMIT 1"))
	{
		db_upgradeDatabase(2);
	}
	else if (!SQL_FastQuery(g_hDb, "SELECT teleside FROM ck_playeroptions LIMIT 1"))
	{
		db_upgradeDatabase(3);
	}

	SQL_UnlockDatabase(g_hDb);
}

public void db_createTables()
{
	Transaction createTableTnx = SQL_CreateTransaction();

	SQL_AddQuery(createTableTnx, sql_createPlayertmp);
	SQL_AddQuery(createTableTnx, sql_createPlayertimes);
	SQL_AddQuery(createTableTnx, sql_createPlayertimesIndex);
	SQL_AddQuery(createTableTnx, sql_createPlayerRank);
	SQL_AddQuery(createTableTnx, sql_createPlayerOptions);
	SQL_AddQuery(createTableTnx, sql_createLatestRecords);
	SQL_AddQuery(createTableTnx, sql_createBonus);
	SQL_AddQuery(createTableTnx, sql_createBonusIndex);
	SQL_AddQuery(createTableTnx, sql_createCheckpoints);
	SQL_AddQuery(createTableTnx, sql_createSpawnLocations);
	SQL_AddQuery(createTableTnx, sql_createAnnouncements);
	SQL_AddQuery(createTableTnx, sql_createWrcps);
	SQL_AddQuery(createTableTnx, sql_createMapTier);
	SQL_AddQuery(createTableTnx, sql_createZones);

	SQL_ExecuteTransaction(g_hDb, createTableTnx, SQLTxn_CreateDatabaseSuccess, SQLTxn_CreateDatabaseFailed);
}

public void SQLTxn_CreateDatabaseSuccess(Handle db, any data, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("[Surftimer] Database tables succesfully created!");
}

public void SQLTxn_CreateDatabaseFailed(Handle db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	SetFailState("[Surftimer] Database tables could not be created! Error: %s", error);
}

public void db_upgradeDatabase(int ver)
{
	if (ver == 0)
	{
		// Surftimer v2.01 -> Surftimer v2.1
		char query[128];
		for (int i = 1; i < 11; i++)
		{
		Format(query, sizeof(query), "ALTER TABLE ck_maptier DROP COLUMN btier%i", i);
		SQL_FastQuery(g_hDb, query);
		}

		SQL_FastQuery(g_hDb, "ALTER TABLE ck_maptier ADD COLUMN maxvelocity FLOAT NOT NULL DEFAULT '3500.0';");
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_maptier ADD COLUMN announcerecord INT(11) NOT NULL DEFAULT '0';");
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_maptier ADD COLUMN gravityfix INT(11) NOT NULL DEFAULT '1';");
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_zones ADD COLUMN `prespeed` int(64) NOT NULL DEFAULT '250';");
		SQL_FastQuery(g_hDb, "CREATE INDEX tier ON ck_maptier (mapname, tier);");
		SQL_FastQuery(g_hDb, "CREATE INDEX mapsettings ON ck_maptier (mapname, maxvelocity, announcerecord, gravityfix);");
		SQL_FastQuery(g_hDb, "UPDATE ck_maptier a, ck_mapsettings b SET a.maxvelocity = b.maxvelocity WHERE a.mapname = b.mapname;");
		SQL_FastQuery(g_hDb, "UPDATE ck_maptier a, ck_mapsettings b SET a.announcerecord = b.announcerecord WHERE a.mapname = b.mapname;");
		SQL_FastQuery(g_hDb, "UPDATE ck_maptier a, ck_mapsettings b SET a.gravityfix = b.gravityfix WHERE a.mapname = b.mapname;");
		SQL_FastQuery(g_hDb, "UPDATE ck_zones a, ck_mapsettings b SET a.prespeed = b.startprespeed WHERE a.mapname = b.mapname AND zonetype = 1;");
		SQL_FastQuery(g_hDb, "DROP TABLE ck_mapsettings;");
	}
	else if (ver == 1)
	{
		// SurfTimer v2.1 -> v2.2
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_maptier ADD COLUMN ranked INT(11) NOT NULL DEFAULT '1';");
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playerrank DROP PRIMARY KEY, ADD COLUMN style INT(11) NOT NULL DEFAULT '0', ADD PRIMARY KEY (steamid, style);");
	}
	else if (ver == 2)
	{
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playerrank ADD COLUMN wrcppoints INT(11) NOT NULL DEFAULT 0 AFTER `wrbpoints`;");
	}
	else if (ver == 3)
	{
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playeroptions2 ADD COLUMN teleside INT(11) NOT NULL DEFAULT 0 AFTER centrehud;");
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_spawnlocations DROP PRIMARY KEY, ADD COLUMN teleside INT(11) NOT NULL DEFAULT 0 AFTER stage, ADD PRIMARY KEY (mapname, zonegroup, stage, teleside);");
	}

	// @IG database updates - @todo: optimize
	// hideweapons
	if (!SQL_FastQuery(g_hDb, "SELECT hideweapons FROM ck_playeroptions2 LIMIT 1"))
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playeroptions2 ADD COLUMN hideweapons INT(11) NOT NULL DEFAULT 0 AFTER teleside;");

	// player outline option
	if (!SQL_FastQuery(g_hDb, "SELECT outlines FROM ck_playeroptions2 LIMIT 1"))
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playeroptions2 ADD COLUMN outlines INT(11) NOT NULL DEFAULT 1 AFTER hideweapons;");

	// startspeeds
	if (!SQL_FastQuery(g_hDb, "SELECT startspeed FROM ck_playertimes LIMIT 1"))
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_playertimes ADD COLUMN startspeed INT(11) NOT NULL DEFAULT -1 AFTER runtimepro;");

	// bonus startspeeds
	if (!SQL_FastQuery(g_hDb, "SELECT startspeed FROM ck_bonus LIMIT 1"))
		SQL_FastQuery(g_hDb, "ALTER TABLE ck_bonus ADD COLUMN startspeed INT(11) NOT NULL DEFAULT -1 AFTER runtime;");

	SQL_UnlockDatabase(g_hDb);
}

/* Admin Delete Menu */

public void sql_DeleteMenuView(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = GetClientFromSerial(data);

	Menu editing = new Menu(callback_DeleteRecord);
	editing.SetTitle("%s %s Records - %s\nSelect a record to delete\n", g_szMenuPrefix, g_EditTypes[g_SelectedEditOption[client]], g_EditingMap[client]);

	char menuFormat[88];
	FormatEx(menuFormat, sizeof(menuFormat), "Style: %s", g_EditStyles[g_SelectedStyle[client]]);
	editing.AddItem("0", menuFormat);

	if(g_SelectedEditOption[client] > 0)
	{
		FormatEx(menuFormat, sizeof(menuFormat), "%s %i", g_SelectedEditOption[client] == 1 ? "Stage":"Bonus", g_SelectedType[client]);
		editing.AddItem("0", menuFormat);
	}

	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("Error %s", error);
	}
	else if (!SQL_GetRowCount(hndl))
	{
		editing.AddItem("1", "No records found", ITEMDRAW_DISABLED);
		editing.Display(client, MENU_TIME_FOREVER);
	}
	else
	{
		char playerName[32], steamID[32];
		float runTime;
		char menuFormatz[128];
		int i = 0;
		while (SQL_FetchRow(hndl))
		{
			i++;
			SQL_FetchString(hndl, 0, steamID, 32);
			SQL_FetchString(hndl, 1, playerName, 32);
			runTime = SQL_FetchFloat(hndl, 2);
			char szRunTime[128];
			FormatTimeFloat(data, runTime, 3, szRunTime, sizeof(szRunTime));
			FormatEx(menuFormat, sizeof(menuFormat), "#%d: %s - %s", i, szRunTime, playerName);
			ReplaceString(playerName, 32, ";;;", ""); // make sure the client dont has this in their name.

			FormatEx(menuFormatz, 128, "%s;;;%s;;;%s", playerName, steamID, szRunTime);
			editing.AddItem(menuFormatz, menuFormat);
		}
		editing.Display(client, MENU_TIME_FOREVER);
	}
}

public int callback_DeleteRecord(Menu menu, MenuAction action, int client, int key)
{
	if(action == MenuAction_Select)
	{
		if(key == 0)
		{
			if(g_SelectedStyle[client] < MAX_STYLES - 1)
				g_SelectedStyle[client]++;
			else
				g_SelectedStyle[client] = 0;

			char szQuery[512];

			switch(g_SelectedEditOption[client])
			{
				case 0:
				{
					FormatEx(szQuery, 512, sql_MainEditQuery, "runtimepro", "ck_playertimes", g_EditingMap[client], g_SelectedStyle[client], "", "runtimepro");
				}
				case 1:
				{
					char stageQuery[32];
					FormatEx(stageQuery, 32, "AND stage='%i' ", g_SelectedType[client]);
					FormatEx(szQuery, 512, sql_MainEditQuery, "runtimepro", "ck_wrcps", g_EditingMap[client], g_SelectedStyle[client], stageQuery, "runtimepro");
				}
				case 2:
				{
					char stageQuery[32];
					FormatEx(stageQuery, 32, "AND zonegroup='%i' ", g_SelectedType[client]);
					FormatEx(szQuery, 512, sql_MainEditQuery, "runtime", "ck_bonus", g_EditingMap[client], g_SelectedStyle[client], stageQuery, "runtime");
				}
			}


			PrintToServer(szQuery);
			SQL_TQuery(g_hDb, sql_DeleteMenuView, szQuery, GetClientSerial(client));
			return 0;
		}

		if(g_SelectedEditOption[client] > 0 && key == 1)
		{
			g_iWaitingForResponse[client] = 6;
			CPrintToChat(client, "%t", "DeleteRecordsNewValue", g_szChatPrefix);
			return 0;
		}


		char menuItem[128];
		menu.GetItem(key, menuItem, 128);

		char recordsBreak[3][32];
		ExplodeString(menuItem, ";;;", recordsBreak, sizeof(recordsBreak), sizeof(recordsBreak[]));

		Menu confirm = new Menu(callback_Confirm);
		confirm.SetTitle("%s Records - Confirm Deletion\nDeleting %s [%s] %s record\n ", g_szMenuPrefix, recordsBreak[0], recordsBreak[1], recordsBreak[2]);

		confirm.AddItem("0", "No");
		confirm.AddItem(recordsBreak[1], "Yes\n \nThis cannot be undone!");

		confirm.Display(client, MENU_TIME_FOREVER);

		return 0;
	}
	else if (action == MenuAction_Cancel)
	{
		if (key == MenuCancel_Exit)
			ShowMainDeleteMenu(client);
	}
	else if(action == MenuAction_End)
		delete menu;

	return 0;
}

public int callback_Confirm(Menu menu, MenuAction action, int client, int key)
{
	if(action == MenuAction_Select)
	{
		if(key == 1)
		{
			char steamID[32];
			menu.GetItem(key, steamID, 32);

			char szQuery[512];

			switch(g_SelectedEditOption[client])
			{
				// sql_MainDeleteQeury[] = "DELETE From %s where mapname='%s' and style='%s' and steamid='%s' %s";

				case 0:
				{
					FormatEx(szQuery, 512, sql_MainDeleteQeury, "ck_playertimes", g_EditingMap[client], g_SelectedStyle[client], steamID, "");
				}
				case 1:
				{
					char stageQuery[32];
					FormatEx(stageQuery, 32, "AND stage='%i'", g_SelectedType[client]);
					FormatEx(szQuery, 512, sql_MainDeleteQeury, "ck_wrcps", g_EditingMap[client], g_SelectedStyle[client], steamID, stageQuery);
				}
				case 2:
				{
					char zoneQuery[32];
					FormatEx(zoneQuery, 32, "AND zonegroup='%i'", g_SelectedType[client]);
					FormatEx(szQuery, 512, sql_MainDeleteQeury, "ck_bonus", g_EditingMap[client], g_SelectedStyle[client], steamID, zoneQuery);
				}
			}
			SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);

			// Looking for online player to refresh his record after deleting it.
			char player_steamID[32];
			for(int i=1; i <= MaxClients; i++)
			{
				if (!IsValidClient(i) || IsFakeClient(client))
					continue;

				GetClientAuthId(i, AuthId_Steam2, player_steamID, 32, true);
				if(StrEqual(player_steamID,steamID))
				{
					LoadPlayerStart(client);
					break;
				}
			}

			db_GetMapRecord_Pro();
			PrintToServer(szQuery);

			CPrintToChat(client, "%t", "DeleteRecordsDeletion", g_szChatPrefix);
		}

	}
	else if(action == MenuAction_End)
		delete menu;
}


/*==================================
=          SPAWN LOCATION          =
==================================*/

public void db_deleteSpawnLocations(int zGrp, int teleside)
{
	g_bGotSpawnLocation[zGrp][1][teleside] = false;
	char szQuery[128];
	Format(szQuery, 128, sql_deleteSpawnLocations, g_szMapName, zGrp, teleside);
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
}


public void db_updateSpawnLocations(float position[3], float angle[3], float vel[3], int zGrp, int teleside)
{
	char szQuery[512];
	Format(szQuery, 512, sql_updateSpawnLocations, position[0], position[1], position[2], angle[0], angle[1], angle[2], vel[0], vel[1], vel[2], g_szMapName, zGrp, teleside);
	SQL_TQuery(g_hDb, db_editSpawnLocationsCallback, szQuery, zGrp);
}

public void db_insertSpawnLocations(float position[3], float angle[3], float vel[3], int zGrp, int teleside)
{
	char szQuery[512];
	Format(szQuery, 512, sql_insertSpawnLocations, g_szMapName, position[0], position[1], position[2], angle[0], angle[1], angle[2], vel[0], vel[1], vel[2], zGrp, teleside);
	SQL_TQuery(g_hDb, db_editSpawnLocationsCallback, szQuery, zGrp);
}

public void db_editSpawnLocationsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_editSpawnLocationsCallback): %s ", error);
		return;
	}
	db_selectSpawnLocations();
}

/*===================================
=            PLAYER RANK            =
===================================*/

// Players points have changed in game, make changes in database and recalculate points
public void db_updateStat(int client, int style)
{
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);

	char szQuery[512];
	// "UPDATE ck_playerrank SET finishedmaps ='%i', finishedmapspro='%i', multiplier ='%i'  where steamid='%s'";
	Format(szQuery, 512, sql_updatePlayerRank, g_pr_finishedmaps[client], g_pr_finishedmaps[client], g_szSteamID[client], style);

	SQL_TQuery(g_hDb, SQL_UpdateStatCallback, szQuery, pack);

}

public void SQL_UpdateStatCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_UpdateStatCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	// Calculating starts here:
	CalculatePlayerRank(client, style);
}

public void RecalcPlayerRank(int client, char steamid[128])
{
	int i = 66;
	while (g_bProfileRecalc[i])
	i++;
	if (!g_bProfileRecalc[i])
	{
		char szQuery[255];
		char szsteamid[128 * 2 + 1];
		SQL_EscapeString(g_hDb, steamid, szsteamid, 128 * 2 + 1);
		Format(g_pr_szSteamID[i], 32, "%s", steamid);
		Format(szQuery, 255, sql_selectPlayerName, szsteamid);
		DataPack pack = CreateDataPack();
		WritePackCell(pack, i);
		WritePackCell(pack, client);
		SQL_TQuery(g_hDb, sql_selectPlayerNameCallback, szQuery, pack);
	}
}

//
//  1. Point calculating starts here
// 	There are two ways:
//	- if client > MAXPLAYERS, his rank is being recalculated by an admin
//	- else player has increased his rank = recalculate points
//
public void CalculatePlayerRank(int client, int style)
{
	char szQuery[255];
	char szSteamId[32];
	// Take old points into memory, so at the end you can show how much the points changed
	g_pr_oldpoints[client][style] = g_pr_points[client][style];
	// Initialize point calculatin
	g_pr_points[client][style] = 0;

	// Start fluffys points
	g_Points[client][style][0] = 0; // Map Points
	g_Points[client][style][1] = 0; // Bonus Points
	g_Points[client][style][2] = 0; // Group Points
	g_Points[client][style][3] = 0; // Map WR Points
	g_Points[client][style][4] = 0; // Bonus WR Points
	g_Points[client][style][5] = 0; // Top 10 Points
	g_Points[client][style][6] = 0; // WRCP Points
	// g_GroupPoints[client][0] // G1 Points
	// g_GroupPoints[client][1] // G2 Points
	// g_GroupPoints[client][2] // G3 Points
	// g_GroupPoints[client][3] // G4 Points
	// g_GroupPoints[client][4] // G5 Points
	g_GroupMaps[client][style] = 0; // Group Maps
	g_Top10Maps[client][style] = 0; // Top 10 Maps
	g_WRs[client][style][0] = 0; // WRs
	g_WRs[client][style][1] = 0; // WRBs
	g_WRs[client][style][2] = 0; // WRCPs

	getSteamIDFromClient(client, szSteamId, 32);

	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);

	Format(szQuery, 255, "SELECT name FROM ck_playerrank WHERE steamid = '%s' AND style = '%i';", szSteamId, style);
	SQL_TQuery(g_hDb, sql_CalcuatePlayerRankCallback, szQuery, pack);
}

// 2. See if player exists, insert new player into the database
// Fetched values:
// name
public void sql_CalcuatePlayerRankCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CalcuatePlayerRankCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);

	char szSteamId[32], szSteamId64[64];

	getSteamIDFromClient(client, szSteamId, 32);

	if (IsValidClient(client))
	{
		GetClientAuthId(client, AuthId_SteamID64, szSteamId64, MAX_NAME_LENGTH, true);

		if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		{
			if (IsValidClient(client))
			{
				if (GetClientTime(client) < (GetEngineTime() - g_fMapStartTime))
					db_UpdateLastSeen(client); // Update last seen on server
			}

			if (IsValidClient(client))
				g_pr_Calculating[client] = true;

			// Next up, calculate bonus points:
			char szQuery[512];
			Format(szQuery, 512, "SELECT a.mapname, (SELECT count(1)+1 FROM ck_bonus b WHERE a.mapname=b.mapname AND a.runtime > b.runtime AND a.zonegroup = b.zonegroup AND b.style = %i) AS rank, (SELECT count(1) FROM ck_bonus b WHERE a.mapname = b.mapname AND a.zonegroup = b.zonegroup AND b.style = %i) as total FROM ck_bonus a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname WHERE steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", style, style, szSteamId, style);
			SQL_TQuery(g_hDb, sql_CountFinishedBonusCallback, szQuery, pack);
		}
		else
		{
			g_pr_Calculating[client] = false;
			g_pr_AllPlayers[style]++;

			// Insert player to database
			char szQuery[512];
			char szUName[MAX_NAME_LENGTH];
			char szName[MAX_NAME_LENGTH * 2 + 1];

			GetClientName(client, szUName, MAX_NAME_LENGTH);
			SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);

			// "INSERT INTO ck_playerrank (steamid, name, country) VALUES('%s', '%s', '%s');";
			// No need to continue calculating, as the doesn't have any records.
			Format(szQuery, 512, sql_insertPlayerRank, szSteamId, szSteamId64, szName, g_szCountry[client], GetTime(), style);
			SQL_TQuery(g_hDb, SQL_InsertPlayerCallBack, szQuery, client);

			g_pr_finishedmaps[client][style] = 0;
			g_pr_finishedbonuses[client][style] = 0;
			g_pr_finishedstages[client][style] = 0;
			g_GroupMaps[client][style] = 0; // Group Maps
			g_Top10Maps[client][style] = 0; // Top 10 Maps

			// play time
			g_iPlayTimeAlive[client] = 0;
			g_iPlayTimeSpec[client] = 0;

			CalculatePlayerRank(client, style);
		}
	}
}

//
// 3. Calculate points gained from bonuses
// Fetched values
// mapname, rank, total
//
public void sql_CountFinishedBonusCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CountFinishedBonusCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);

	char szMap[128], szSteamId[32];
	// int totalplayers
	int rank;

	getSteamIDFromClient(client, szSteamId, 32);
	int finishedbonuses = 0;
	int wrbs = 0;

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			finishedbonuses++;
			// Total amount of players who have finished the bonus
			// totalplayers = SQL_FetchInt(hndl, 2);
			rank = SQL_FetchInt(hndl, 1);
			SQL_FetchString(hndl, 0, szMap, 128);

			/*float percentage = 1.0 + ((1.0 / float(totalplayers)) - (float(rank) / float(totalplayers)));
			g_pr_points[client] += RoundToCeil(200.0 * percentage);*/
			switch (rank)
			{
				case 1:
				{
					g_pr_points[client][style] += 250;
					g_Points[client][style][4] += 250;
					wrbs++;
				}
				case 2:
				{
					g_pr_points[client][style] += 235;
					g_Points[client][style][1] += 235;
				}
				case 3:
				{
					g_pr_points[client][style] += 220;
					g_Points[client][style][1] += 220;
				}
				case 4:
				{
					g_pr_points[client][style] += 205;
					g_Points[client][style][1] += 205;
				}
				case 5:
				{
					g_pr_points[client][style] += 190;
					g_Points[client][style][1] += 190;
				}
				case 6:
				{
					g_pr_points[client][style] += 175;
					g_Points[client][style][1] += 175;
				}
				case 7:
				{
					g_pr_points[client][style] += 160;
					g_Points[client][style][1] += 160;
				}
				case 8:
				{
					g_pr_points[client][style] += 145;
					g_Points[client][style][1] += 145;
				}
				case 9:
				{
					g_pr_points[client][style] += 130;
					g_Points[client][style][1] += 130;
				}
				case 10:
				{
					g_pr_points[client][style] += 100;
					g_Points[client][style][1] += 100;
				}
				case 11:
				{
					g_pr_points[client][style] += 95;
					g_Points[client][style][1] += 95;
				}
				case 12:
				{
					g_pr_points[client][style] += 90;
					g_Points[client][style][1] += 90;
				}
				case 13:
				{
					g_pr_points[client][style] += 80;
					g_Points[client][style][1] += 80;
				}
				case 14:
				{
					g_pr_points[client][style] += 70;
					g_Points[client][style][1] += 70;
				}
				case 15:
				{
					g_pr_points[client][style] += 60;
					g_Points[client][style][1] += 60;
				}
				case 16:
				{
					g_pr_points[client][style] += 50;
					g_Points[client][style][1] += 50;
				}
				case 17:
				{
					g_pr_points[client][style] += 40;
					g_Points[client][style][1] += 40;
				}
				case 18:
				{
					g_pr_points[client][style] += 30;
					g_Points[client][style][1] += 30;
				}
				case 19:
				{
					g_pr_points[client][style] += 20;
					g_Points[client][style][1] += 20;
				}
				case 20:
				{
					g_pr_points[client][style] += 10;
					g_Points[client][style][1] += 10;
				}
				default:
				{
					g_pr_points[client][style] += 5;
					g_Points[client][style][1] += 5;
				}
			}
		}
	}

	g_pr_finishedbonuses[client][style] = finishedbonuses;
	g_WRs[client][style][1] = wrbs;
	// Next up: Points from stages
	char szQuery[512];
	Format(szQuery, 512, "SELECT a.mapname, a.stage, (select count(1)+1 from ck_wrcps b where a.mapname=b.mapname and a.runtimepro > b.runtimepro and a.style = b.style and a.stage = b.stage) AS rank FROM ck_wrcps a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname where steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", szSteamId, style);
	SQL_TQuery(g_hDb, sql_CountFinishedStagesCallback, szQuery, pack);
}

//
// 4. Calculate points gained from stages
// Fetched values
// mapname, stage, rank, total
//
public void sql_CountFinishedStagesCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CountFinishedStagesCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);

	char szMap[128], szSteamId[32];
	// int totalplayers, rank;

	getSteamIDFromClient(client, szSteamId, 32);
	int finishedstages = 0;
	int rank;
	int wrcps = 0;

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			finishedstages++;
			// Total amount of players who have finished the bonus
			// totalplayers = SQL_FetchInt(hndl, 2);
			SQL_FetchString(hndl, 0, szMap, 128);
			rank = SQL_FetchInt(hndl, 2);

			if (rank == 1)
			{
				wrcps++;
				int wrcpPoints = GetConVarInt(g_hWrcpPoints);
				if (wrcpPoints > 0)
				{
					g_pr_points[client][style] += wrcpPoints;
					g_Points[client][style][6] += wrcpPoints;
				}
			}
		}
	}

	g_pr_finishedstages[client][style] = finishedstages;
	g_WRs[client][style][2] = wrcps;

	// Next up: Points from maps
	char szQuery[512];
	Format(szQuery, 512, "SELECT a.mapname, (select count(1)+1 from ck_playertimes b where a.mapname=b.mapname and a.runtimepro > b.runtimepro AND b.style = %i) AS rank, (SELECT count(1) FROM ck_playertimes b WHERE a.mapname = b.mapname AND b.style = %i) as total, tier.tier FROM ck_playertimes a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname where steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", style, style, szSteamId, style);
	SQL_TQuery(g_hDb, sql_CountFinishedMapsCallback, szQuery, pack);
}

// 5. Count the points gained from regular maps
// Fetching:
// mapname, rank, total, tier
public void sql_CountFinishedMapsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CountFinishedMapsCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	char szMap[128];
	int finishedMaps = 0, totalplayers, rank, tier, wrs;

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			// Total amount of players who have finished the map
			totalplayers = SQL_FetchInt(hndl, 2);
			// Rank in that map
			rank = SQL_FetchInt(hndl, 1);
			// Map name
			SQL_FetchString(hndl, 0, szMap, 128);
			// Map tier
			tier = SQL_FetchInt(hndl, 3);

			finishedMaps++;
			float wrpoints;
			int iwrpoints;
			float points;
			// bool wr;
			// bool top10;
			float g1points;
			float g2points;
			float g3points;
			float g4points;
			float g5points;

			// Calculate Group Ranks
			// Group 1
			float fG1top;
			int g1top;
			int g1bot = 11;
			fG1top = (float(totalplayers) * g_Group1Pc);
			fG1top += 11.0; // Rank 11 is always End of Group 1
			g1top = RoundToCeil(fG1top);

			int g1difference = (g1top - g1bot);
			if (g1difference < 4)
				g1top = (g1bot + 4);

			// Group 2
			float fG2top;
			int g2top;
			int g2bot;
			g2bot = g1top + 1;
			fG2top = (float(totalplayers) * g_Group2Pc);
			fG2top += 11.0;
			g2top = RoundToCeil(fG2top);

			int g2difference = (g2top - g2bot);
			if (g2difference < 4)
				g2top = (g2bot + 4);

			// Group 3
			float fG3top;
			int g3top;
			int g3bot;
			g3bot = g2top + 1;
			fG3top = (float(totalplayers) * g_Group3Pc);
			fG3top += 11.0;
			g3top = RoundToCeil(fG3top);

			int g3difference = (g3top - g3bot);
			if (g3difference < 4)
				g3top = (g3bot + 4);

			// Group 4
			float fG4top;
			int g4top;
			int g4bot;
			g4bot = g3top + 1;
			fG4top = (float(totalplayers) * g_Group4Pc);
			fG4top += 11.0;
			g4top = RoundToCeil(fG4top);

			int g4difference = (g4top - g4bot);
			if (g4difference < 4)
				g4top = (g4bot + 4);

			// Group 5
			float fG5top;
			int g5top;
			int g5bot;
			g5bot = g4top + 1;
			fG5top = (float(totalplayers) * g_Group5Pc);
			fG5top += 11.0;
			g5top = RoundToCeil(fG5top);

			int g5difference = (g5top - g5bot);
			if (g5difference < 4)
				g5top = (g5bot + 4);

			if (tier == 1)
			{
				wrpoints = ((float(totalplayers) * 1.75) / 6);
				wrpoints += 58.5;
				if (wrpoints < 250.0)
					wrpoints = 250.0;
			}
			else if (tier == 2)
			{
				wrpoints = ((float(totalplayers) * 2.8) / 5);
				wrpoints += 82.15;
				if (wrpoints < 500.0)
					wrpoints = 500.0;
			}
			else if (tier == 3)
			{
				wrpoints = ((float(totalplayers) * 3.5) / 4);
				if (wrpoints < 750.0)
					wrpoints = 750.0;
				else
					wrpoints += 117;
			}
			else if (tier == 4)
			{
				wrpoints = ((float(totalplayers) * 5.74) / 4);
				if (wrpoints < 1000.0)
					wrpoints = 1000.0;
				else
					wrpoints += 164.25;
			}
			else if (tier == 5)
			{
				wrpoints = ((float(totalplayers) * 7) / 4);
				if (wrpoints < 1250.0)
					wrpoints = 1250.0;
				else
					wrpoints += 234;
			}
			else if (tier == 6)
			{
				wrpoints = ((float(totalplayers) * 14) / 4);
				if (wrpoints < 1500.0)
					wrpoints = 1500.0;
				else
					wrpoints += 328;
			}
			else // no tier set
				wrpoints = 25.0;

			// Round WR points up
			iwrpoints = RoundToCeil(wrpoints);

			// Top 10 Points
			if (rank < 11)
			{
				g_Top10Maps[client][style]++;
				if (rank == 1)
				{
					g_pr_points[client][style] += iwrpoints;
					g_Points[client][style][3] += iwrpoints;
					wrs++;
				}
				else if (rank == 2)
				{
					points = (0.80 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 3)
				{
					points = (0.75 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 4)
				{
					points = (0.70 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 5)
				{
					points = (0.65 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 6)
				{
					points = (0.60 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 7)
				{
					points = (0.55 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 8)
				{
					points = (0.50 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 9)
				{
					points = (0.45 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
				else if (rank == 10)
				{
					points = (0.40 * iwrpoints);
					g_pr_points[client][style] += RoundToCeil(points);
					g_Points[client][style][5] += RoundToCeil(points);
				}
			}
			else if (rank > 10 && rank <= g5top)
			{
				// Group 1-5 Points
				g_GroupMaps[client][style] += 1;
				// Calculate Group Points
				g1points = (iwrpoints * 0.25);
				g2points = (g1points / 1.5);
				g3points = (g2points / 1.5);
				g4points = (g3points / 1.5);
				g5points = (g4points / 1.5);

				if (rank >= g1bot && rank <= g1top) // Group 1
				{
					g_pr_points[client][style] += RoundFloat(g1points);
					g_Points[client][style][2] += RoundFloat(g1points);
				}
				else if (rank >= g2bot && rank <= g2top) // Group 2
				{
					g_pr_points[client][style] += RoundFloat(g2points);
					g_Points[client][style][2] += RoundFloat(g2points);
				}
				else if (rank >= g3bot && rank <= g3top) // Group 3
				{
					g_pr_points[client][style] += RoundFloat(g3points);
					g_Points[client][style][2] += RoundFloat(g3points);
				}
				else if (rank >= g4bot && rank <= g4top) // Group 4
				{
					g_pr_points[client][style] += RoundFloat(g4points);
					g_Points[client][style][2] += RoundFloat(g4points);
				}
				else if (rank >= g5bot && rank <= g5top) // Group 5
				{
					g_pr_points[client][style] += RoundFloat(g5points);
					g_Points[client][style][2] += RoundFloat(g5points);
				}
			}

			// Map Completiton Points
			if (tier == 1)
			{
				g_pr_points[client][style] += 25;
				g_Points[client][style][0] += 25;
			}
			else if (tier == 2)
			{
				g_pr_points[client][style] += 50;
				g_Points[client][style][0] += 50;
			}
			else if (tier == 3)
			{
				g_pr_points[client][style] += 100;
				g_Points[client][style][0] += 100;
			}
			else if (tier == 4)
			{
				g_pr_points[client][style] += 200;
				g_Points[client][style][0] += 200;
			}
			else if (tier == 5)
			{
				g_pr_points[client][style] += 400;
				g_Points[client][style][0] += 400;
			}
			else if (tier == 6)
			{
				g_pr_points[client][style] += 600;
				g_Points[client][style][0] += 600;
			}
			else // no tier
			{
				g_pr_points[client][style] += 13;
				g_Points[client][style][0] += 13;
			}
		}
	}

	// Finished maps amount is stored in memory
	g_pr_finishedmaps[client][style] = finishedMaps;

	// WRs
	g_WRs[client][style][0] = wrs;

	/*
	// TODO
	int totalperc = g_pr_finishedstages[client][style] + g_pr_finishedbonuses[client][style] + g_pr_finishedmaps[client][style];
	int totalcomp = g_pr_StageCount + g_pr_BonusCount + g_pr_MapCount[0];
	float ftotalperc;

	ftotalperc = (float(totalperc) / (float(totalcomp))) * 100.0;

	if (IsValidClient(client) && !IsFakeClient(client))
		CS_SetMVPCount(client, (RoundFloat(ftotalperc)));
	*/

	// Done checking, update points
	db_updatePoints(client, style);
}

// 6. Updating points to database
public void db_updatePoints(int client, int style)
{
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);

	char szQuery[512];
	char szName[MAX_NAME_LENGTH * 2 + 1];
	char szSteamId[32];
	if (client > MAXPLAYERS && g_pr_RankingRecalc_InProgress || client > MAXPLAYERS && g_bProfileRecalc[client])
	{
		SQL_EscapeString(g_hDb, g_pr_szName[client], szName, MAX_NAME_LENGTH * 2 + 1);
		Format(szQuery, 512, sql_updatePlayerRankPoints, szName, g_pr_points[client][style], g_Points[client][style][3], g_Points[client][style][4], g_Points[client][style][6], g_Points[client][style][5], g_Points[client][style][2], g_Points[client][style][0], g_Points[client][style][1], g_pr_finishedmaps[client][style], g_pr_finishedbonuses[client][style], g_pr_finishedstages[client][style], g_WRs[client][style][0], g_WRs[client][style][1], g_WRs[client][style][2], g_Top10Maps[client][style], g_GroupMaps[client][style], g_pr_szSteamID[client], style);
		SQL_TQuery(g_hDb, sql_updatePlayerRankPointsCallback, szQuery, pack);
	}
	else
	{
		if (IsValidClient(client))
		{
			GetClientName(client, szName, MAX_NAME_LENGTH);
			GetClientAuthId(client, AuthId_Steam2, szSteamId, MAX_NAME_LENGTH, true);
			// GetClientAuthString(client, szSteamId, MAX_NAME_LENGTH);
			Format(szQuery, 512, sql_updatePlayerRankPoints2, szName, g_pr_points[client][style], g_Points[client][style][3], g_Points[client][style][4], g_Points[client][style][6], g_Points[client][style][5], g_Points[client][style][2], g_Points[client][style][0], g_Points[client][style][1], g_pr_finishedmaps[client][style], g_pr_finishedbonuses[client][style], g_pr_finishedstages[client][style], g_WRs[client][style][0], g_WRs[client][style][1], g_WRs[client][style][2], g_Top10Maps[client][style], g_GroupMaps[client][style], g_szCountry[client], szSteamId, style);
			SQL_TQuery(g_hDb, sql_updatePlayerRankPointsCallback, szQuery, pack);
		}
	}

	if (style == 0 && IsValidClient(client))
	{
		CS_SetClientAssists(client, g_pr_finishedmaps[client][0]);
	}
}

// 7. Calculations done, if calculating all, move forward, if not announce changes.
public void sql_updatePlayerRankPointsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_updatePlayerRankPointsCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int data = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	// If was recalculating points, go to the next player, announce or end calculating
	if (data > MAXPLAYERS && g_pr_RankingRecalc_InProgress || data > MAXPLAYERS && g_bProfileRecalc[data])
	{
		if (g_bProfileRecalc[data] && !g_pr_RankingRecalc_InProgress)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsValidClient(i))
				{
					if (StrEqual(g_szSteamID[i], g_pr_szSteamID[data]))
					CalculatePlayerRank(i, 0);
				}
			}
		}

		g_bProfileRecalc[data] = false;
		if (g_pr_RankingRecalc_InProgress)
		{
			// console info
			if (IsValidClient(g_pr_Recalc_AdminID) && g_bManualRecalc)
				PrintToConsole(g_pr_Recalc_AdminID, "%i/%i", g_pr_Recalc_ClientID, g_pr_TableRowCount);

			int x = 66 + g_pr_Recalc_ClientID;
			if (StrContains(g_pr_szSteamID[x], "STEAM", false) != -1)
			{
				CalculatePlayerRank(x, 0);
			}
			else
			{
				for (int i = 1; i <= MaxClients; i++)
				if (1 <= i <= MaxClients && IsValidEntity(i) && IsValidClient(i))
				{
					if (g_bManualRecalc)
						CPrintToChat(i, "%t", "PrUpdateFinished", g_szChatPrefix);
				}

				g_bManualRecalc = false;
				g_pr_RankingRecalc_InProgress = false;

				if (IsValidClient(g_pr_Recalc_AdminID))
					CreateTimer(0.1, RefreshAdminMenu, g_pr_Recalc_AdminID, TIMER_FLAG_NO_MAPCHANGE);
			}
			g_pr_Recalc_ClientID++;
		}
	}
	else // Gaining points normally
	{
		// Player recalculated own points in !profile
		if (g_bRecalcRankInProgess[data] && data <= MAXPLAYERS)
		{
			ProfileMenu2(data, style, "", g_szSteamID[data]);
			if (IsValidClient(data))
			{
				if (style == STYLE_NORMAL)
					CPrintToChat(data, "%t", "Rc_PlayerRankFinished", g_szChatPrefix, g_pr_points[data][style]);
				else
					CPrintToChat(data, "%t", "Rc_PlayerRankFinished2", g_szChatPrefix, g_szStyleMenuPrint[style], g_pr_points[data][style]);
			}

			g_bRecalcRankInProgess[data] = false;
		}
		if (IsValidClient(data) && g_pr_showmsg[data]) // Player gained points
		{
			char szName[MAX_NAME_LENGTH];
			GetClientName(data, szName, MAX_NAME_LENGTH);

			int diff = g_pr_points[data][style] - g_pr_oldpoints[data][style];
			if (diff > 0) // if player earned points -> Announce
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsValidClient(i))
					{
						if (style == STYLE_NORMAL)
							CPrintToChat(i, "%t", "EarnedPoints", g_szChatPrefix, szName, diff, g_pr_points[data][0]);
						else
							CPrintToChat(i, "%t", "EarnedPoints2", g_szChatPrefix, szName, diff, g_szStyleRecordPrint[style], g_pr_points[data][style]);
					}
				}
			}

			g_pr_showmsg[data] = false;
			db_CalculatePlayersCountGreater0();
		}
		g_pr_Calculating[data] = false;
		db_GetPlayerRank(data);
	}
}

public void db_viewPlayerProfileByName(int client, int style, const char[] szName) {
	char szNameEx[MAX_NAME_LENGTH*2+1];
	SQL_EscapeString(g_hDb, szName, szNameEx, sizeof(szNameEx));
	char szQuery[512];
	Format(szQuery, sizeof(szQuery), "SELECT steamid, style FROM ck_playerrank WHERE style=%i AND name LIKE '%c%s%c' ORDER BY points DESC LIMIT 1", style, PERCENT, szNameEx, PERCENT);
	SQL_TQuery(g_hDb, db_viewPlayerProfileByName2, szQuery, client);
}
public void db_viewPlayerProfileByName2(Handle owner, Handle hndl, const char[] error, int client) {
	if (hndl == null) { LogError("[Surftimer] SQL Error (db_viewPlayerProfileByName2): %s", error); return; }
	if (!SQL_HasResultSet(hndl) || !SQL_FetchRow(hndl)) { CPrintToChat(client, "Player not found"); return; }
	char szSteamid[MAX_NAME_LENGTH];
	SQL_FetchString(hndl, 0, szSteamid, sizeof(szSteamid));
	int style = SQL_FetchInt(hndl, 1);
	db_viewPlayerProfileBySteamid(client, style, szSteamid);
}
public void db_viewPlayerProfileBySteamid(int client, int style, const char[] szSteamid) {
	char szSteamidEx[MAX_NAME_LENGTH*2+1];
	SQL_EscapeString(g_hDb, szSteamid, szSteamidEx, sizeof(szSteamidEx));
	char szQuery[2048];
	Format(szQuery, sizeof(szQuery), " \
		SELECT steamid, name, country, style, points, wrpoints, wrbpoints, wrcppoints, top10points, groupspoints, mappoints, bonuspoints, finishedmapspro, finishedbonuses, finishedstages, wrs, wrbs, wrcps, top10s, groups, lastseen, \
			(SELECT COUNT(*)+1 FROM ck_playerrank b WHERE a.style=b.style AND b.points > a.points) AS rank, \
			(SELECT COUNT(DISTINCT ck_zones.mapname, `zonegroup`) FROM ck_zones INNER JOIN ck_maptier ON ck_zones.mapname=ck_maptier.mapname WHERE `zonetypeid` = 0 AND `zonegroup` > 0 AND ranked = 1 AND tier > 0) AS bonuscount, \
			(SELECT COUNT(*) FROM ck_maptier WHERE ranked = 1 AND tier > 0) AS mapcount, \
			(SELECT COUNT(DISTINCT ck_zones.mapname, `zonetypeid`) FROM `ck_zones` INNER JOIN ck_maptier ON ck_zones.mapname=ck_maptier.mapname WHERE `zonetype` IN (1, 3, 5) AND `zonegroup` = 0 AND ranked = 1 AND tier > 0) AS stagecount \
		FROM ck_playerrank a \
		WHERE steamid='%s' AND style='%i' \
		LIMIT 1 \
	", szSteamidEx, style);
	SQL_TQuery(g_hDb, db_viewPlayerProfileBySteamid2, szQuery, client);
}
public void db_viewPlayerProfileBySteamid2(Handle owner, Handle hndl, const char[] error, int client) {
	if (hndl == null) { LogError("[Surftimer] SQL Error (db_viewPlayerProfileBySteamid2): %s", error); return; }
	if (!SQL_HasResultSet(hndl) || !SQL_FetchRow(hndl)) { CPrintToChat(client, "Player not found"); return; }

	char szName[MAX_NAME_LENGTH], szSteamId[32], szCountry[64];

	int i = 0;
	SQL_FetchString(hndl, i++, szSteamId, sizeof(szSteamId));
	SQL_FetchString(hndl, i++, szName, sizeof(szName));
	SQL_FetchString(hndl, i++, szCountry, sizeof(szCountry));
	int style = SQL_FetchInt(hndl, i++);
	int points = SQL_FetchInt(hndl, i++);
	int wrPoints = SQL_FetchInt(hndl, i++);
	int wrbPoints = SQL_FetchInt(hndl, i++);
	int wrcpPoints = SQL_FetchInt(hndl, i++);
	int top10Points = SQL_FetchInt(hndl, i++);
	int groupPoints = SQL_FetchInt(hndl, i++);
	int mapPoints = SQL_FetchInt(hndl, i++);
	int bonusPoints = SQL_FetchInt(hndl, i++);
	int finishedMaps = SQL_FetchInt(hndl, i++);
	int finishedBonuses = SQL_FetchInt(hndl, i++);
	int finishedStages = SQL_FetchInt(hndl, i++);
	int wrs = SQL_FetchInt(hndl, i++);
	int wrbs = SQL_FetchInt(hndl, i++);
	int wrcps = SQL_FetchInt(hndl, i++);
	int top10s = SQL_FetchInt(hndl, i++);
	int groups = SQL_FetchInt(hndl, i++);
	int lastseen = SQL_FetchInt(hndl, i++);
	int rank = SQL_FetchInt(hndl, i++);
	int bonusCount = SQL_FetchInt(hndl, i++);
	int mapCount = SQL_FetchInt(hndl, i++);
	int stageCount = SQL_FetchInt(hndl, i++);

	strcopy(g_szProfileSteamId[client], sizeof(g_szProfileSteamId), szSteamId);
	strcopy(g_szProfileName[client], sizeof(g_szProfileName), szName);

	if (finishedMaps > mapCount) finishedMaps = mapCount;
	if (finishedBonuses > bonusCount) finishedBonuses = bonusCount;
	if (finishedStages > stageCount) finishedStages = stageCount;

	int totalCompleted = finishedMaps + finishedBonuses + finishedStages;
	int totalZones = mapCount + bonusCount + stageCount;

	// Completion Percentage
	float fPerc, fBPerc, fSPerc, fTotalPerc;
	char szPerc[32], szBPerc[32], szSPerc[32], szTotalPerc[32];

	// Calculate percentages and format them into strings
	fPerc = (float(finishedMaps) / (float(mapCount))) * 100.0;
	fBPerc = (float(finishedBonuses) / (float(bonusCount))) * 100.0;
	fSPerc = (float(finishedStages) / (float(stageCount))) * 100.0;
	fTotalPerc = (float(totalCompleted) / (float(totalZones))) * 100.0;

	FormatPercentage(fPerc, szPerc, sizeof(szPerc));
	FormatPercentage(fBPerc, szBPerc, sizeof(szBPerc));
	FormatPercentage(fSPerc, szSPerc, sizeof(szSPerc));
	FormatPercentage(fTotalPerc, szTotalPerc, sizeof(szTotalPerc));

	// Get players skillgroup
	int RankValue[SkillGroup];
	int index = GetSkillgroupIndex(rank, points);
	GetArrayArray(g_hSkillGroups, index, RankValue[0]);
	char szSkillGroup[128];
	Format(szSkillGroup, sizeof(szSkillGroup), RankValue[RankName]);
	ReplaceString(szSkillGroup, sizeof(szSkillGroup), "{style}", "");

	char szRank[32];
	if (rank > g_pr_RankedPlayers[0] || points == 0)
		Format(szRank, 32, "-");
	else
		Format(szRank, 32, "%i", rank);

	// Format Profile Menu
	char szCompleted[1024], szMapPoints[128], szBonusPoints[128], szTop10Points[128], szStagePc[128], szMiPc[128], szRecords[128], szLastSeen[128], szRankLine[128];

	// Get last seen
	int time = GetTime();
	int unix = time - lastseen;
	diffForHumans(unix, szLastSeen, sizeof(szLastSeen), 1);

	Format(szMapPoints, 128, "Maps: %i/%i - [%i] (%s%c)", finishedMaps, mapCount, mapPoints, szPerc, PERCENT);

	if (wrbPoints > 0)
		Format(szBonusPoints, sizeof(szBonusPoints), "Bonuses: %i/%i - [%i+%i] (%s%c)", finishedBonuses, bonusCount, bonusPoints, wrbPoints, szBPerc, PERCENT);
	else
		Format(szBonusPoints, sizeof(szBonusPoints), "Bonuses: %i/%i - [%i] (%s%c)", finishedBonuses, bonusCount, bonusPoints, szBPerc, PERCENT);

	if (wrPoints > 0)
		Format(szTop10Points, sizeof(szTop10Points), "Top10: %i - [%i+%i]", top10s, top10Points, wrPoints);
	else
		Format(szTop10Points, sizeof(szTop10Points), "Top10: %i - [%i]", top10s, top10Points);

	if (wrcpPoints > 0)
		Format(szStagePc, sizeof(szStagePc), "Stages: %i/%i [0+%d] (%s%c)", finishedStages, stageCount, wrcpPoints, szSPerc, PERCENT);
	else
		Format(szStagePc, sizeof(szStagePc), "Stages: %i/%i [0] (%s%c)", finishedStages, stageCount, szSPerc, PERCENT);

	Format(szMiPc, sizeof(szMiPc), "Map Improvement Pts: %i - [%i]", groups, groupPoints);
	Format(szRecords, sizeof(szRecords), "Records:\nMap WR: %i\nStage WR: %i\nBonus WR: %i", wrs, wrcps, wrbs);
	Format(szCompleted, sizeof(szCompleted), "Completed - Points (%s%c):\n%s\n%s\n%s\n%s\n \n%s\n \n%s\n \n", szTotalPerc, PERCENT, szMapPoints, szBonusPoints, szTop10Points, szStagePc, szMiPc, szRecords);
	Format(szRankLine, sizeof(szRankLine), "Rank: %s/%i %s\nTotal pts: %i\n \n", szRank, g_pr_RankedPlayers[style], szSkillGroup, points);

	char szTop[128];
	if (style > 0)
		Format(szTop, sizeof(szTop), "[%s | %s | Online: %s]\n", szName, g_szStyleMenuPrint[style], szLastSeen);
	else
		Format(szTop, sizeof(szTop), "[%s ||| Online: %s]\n", szName, szLastSeen);

	char szTitle[1024];
	if (GetConVarBool(g_hCountry))
		Format(szTitle, sizeof(szTitle), "%s-------------------------------------\n%s\nCountry: %s\n \n%s\n", szTop, szSteamId, szCountry, szRankLine);
	else
		Format(szTitle, sizeof(szTitle), "%s-------------------------------------\n%s\n \n%s", szTop, szSteamId, szRankLine);

	Menu menu = CreateMenu(ProfileMenuHandler);
	SetMenuTitle(menu, szTitle);
	AddMenuItem(menu, "Finished maps", szCompleted);
	AddMenuItem(menu, szSteamId, "Player Info");

	if (IsValidClient(client))
		if (StrEqual(szSteamId, g_szSteamID[client]))
			AddMenuItem(menu, "Refresh my profile", "Refresh my profile");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ProfileMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0: completionMenu(client);
			case 1:
			{
				char szSteamId[32];
				GetMenuItem(menu, item, szSteamId, 32);
				db_viewPlayerInfo(client, szSteamId);
			}
			case 2:
			{
				if (g_bRecalcRankInProgess[client])
				{
					CPrintToChat(client, "%t", "SQL1", g_szChatPrefix);
				}
				else
				{
					g_bRecalcRankInProgess[client] = true;
					CPrintToChat(client, "%t", "Rc_PlayerRankStart", g_szChatPrefix);
					CalculatePlayerRank(client, g_ProfileStyleSelect[client]);
				}
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (1 <= client <= MaxClients && IsValidClient(client))
		{
			switch (g_MenuLevel[client])
			{
				case 0:db_selectTopPlayers(client, 0);
				case 3:db_viewStyleWrcpMap(client, g_szWrcpMapSelect[client], 0);
			}
			if (g_MenuLevel[client] < 0)
			{
				if (g_bSelectProfile[client])
					ProfileMenu2(client, g_ProfileStyleSelect[client], "", "");
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void completionMenu(int client)
{
	int style = g_ProfileStyleSelect[client];
	char szTitle[128];
	if (style == STYLE_NORMAL)
		Format(szTitle, 128, "[%s | Completion Menu]\n \n", g_szProfileName[client]);
	else
		Format(szTitle, 128, "[%s | %s | Completion Menu]\n \n", g_szProfileName[client], g_szStyleMenuPrint[style]);

	Menu theCompletionMenu = CreateMenu(CompletionMenuHandler);
	SetMenuTitle(theCompletionMenu, szTitle);
	AddMenuItem(theCompletionMenu, "Complete Maps", "Complete Maps");
	AddMenuItem(theCompletionMenu, "Incomplete Maps", "Incomplete Maps");
	AddMenuItem(theCompletionMenu, "Top 10 Maps", "Top 10 Maps");
	AddMenuItem(theCompletionMenu, "WRs", "WRs");
	SetMenuExitBackButton(theCompletionMenu, true);
	DisplayMenu(theCompletionMenu, client, MENU_TIME_FOREVER);
}

public int CompletionMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		switch (item)
		{
			case 0:db_viewAllRecords(client, g_szProfileSteamId[client], false, true);
			case 1:db_viewAllRecords(client, g_szProfileSteamId[client], true, false);
			case 2:db_viewAllRecords(client, g_szProfileSteamId[client], true, true, 10);
			case 3:db_viewAllRecords(client, g_szProfileSteamId[client], true, true, 1);
		}
	}
	else if (action == MenuAction_Cancel)
		db_viewPlayerProfileBySteamid(client, g_ProfileStyleSelect[client], g_szProfileSteamId[client]);
	else if (action == MenuAction_End)
		delete menu;
}

/*==================================
=           PLAYER TIMES           =
==================================*/

public void db_selectTopSurfers(int client, char mapname[128])
{
	char szQuery[1024];
	Format(szQuery, 1024, sql_selectTopSurfers, mapname);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, mapname);
	WritePackCell(pack, 0);
	SQL_TQuery(g_hDb, sql_selectTopSurfersCallback, szQuery, pack);
}

public void db_selectMapTopSurfers(int client, char mapname[128])
{
	char szQuery[1024];
	char type[128];
	type = "normal";
	Format(szQuery, 1024, sql_selectTopSurfers3, mapname);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, mapname);
	WritePackString(pack, type);
	SQL_TQuery(g_hDb, sql_selectTopSurfersCallback, szQuery, pack);
}

public void sql_selectTopSurfersCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectTopSurfersCallback): %s", error);
		return;
	}

	ResetPack(data);
	int client = ReadPackCell(data);
	char szMap[128];
	ReadPackString(data, szMap, 128);
	int style = ReadPackCell(data);
	delete data;

	char szFirstMap[128];
	char szValue[128];
	char szName[64];
	float time;
	char szSteamID[32];
	char lineBuf[256];
	Handle stringArray = CreateArray(100);

	Handle menu;
	menu = CreateMenu(MapMenuHandler1);
	SetMenuPagination(menu, 5);

	bool bduplicat = false;
	char title[256];
	if (SQL_HasResultSet(hndl))
	{
		int i = 1;
		while (SQL_FetchRow(hndl))
		{
			bduplicat = false;
			SQL_FetchString(hndl, 0, szSteamID, 32);
			SQL_FetchString(hndl, 1, szName, 64);
			time = SQL_FetchFloat(hndl, 2);
			SQL_FetchString(hndl, 4, szMap, 128);

			if (i == 1 || (i > 1 && StrEqual(szFirstMap, szMap)))
			{
				int stringArraySize = GetArraySize(stringArray);
				for (int x = 0; x < stringArraySize; x++)
				{
					GetArrayString(stringArray, x, lineBuf, sizeof(lineBuf));
					if (StrEqual(lineBuf, szName, false))
						bduplicat = true;
				}
				if (!bduplicat && i < 51)
				{
					char szTime[32];
					FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));

					if (time < 3600.0)
						Format(szTime, 32, "   %s", szTime);
					if (i == 100)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					if (i >= 10)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					else
						Format(szValue, 128, "[0%i.] %s |    » %s", i, szTime, szName);

					AddMenuItem(menu, szSteamID, szValue, ITEMDRAW_DEFAULT);
					PushArrayString(stringArray, szName);

					if (i == 1)
						Format(szFirstMap, 128, "%s", szMap);
					i++;
				}
			}
		}
		if (i == 1)
		{
			CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, szMap);
		}
	}
	else
		CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, szMap);

	switch (style)
	{
		case 1: Format(title, 256, "Top 50 SW Times on %s \n    Rank    Time               Player", szFirstMap);
		case 2: Format(title, 256, "Top 50 HSW Times on %s \n    Rank    Time               Player", szFirstMap);
		case 3: Format(title, 256, "Top 50 BW Times on %s \n    Rank    Time               Player", szFirstMap);
		case 4: Format(title, 256, "Top 50 Low-Gravity Times on %s \n    Rank    Time               Player", szFirstMap);
		case 5: Format(title, 256, "Top 50 Slow Motion Times on %s \n    Rank    Time               Player", szFirstMap);
		case 6: Format(title, 256, "Top 50 Fast Forward Times on %s \n    Rank    Time               Player", szFirstMap);
		default: Format(title, 256, "Top 50 Times on %s \n    Rank    Time               Player", szFirstMap);
	}

	delete stringArray;
	SetMenuTitle(menu, title);
	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}


// BONUS
public void db_selectBonusesInMap(int client, char mapname[128])
{
	// SELECT mapname, zonegroup, zonename FROM `ck_zones` WHERE mapname LIKE '%c%s%c' AND zonegroup > 0 GROUP BY zonegroup;
	char szQuery[512];
	Format(szQuery, 512, sql_selectBonusesInMap, PERCENT, mapname, PERCENT);
	SQL_TQuery(g_hDb, db_selectBonusesInMapCallback, szQuery, client);
}

public void db_selectBonusesInMapCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectBonusesInMapCallback): %s", error);
		return;
	}
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char mapname[128], MenuTitle[248], BonusName[128], MenuID[248];
		int zGrp;

		if (SQL_GetRowCount(hndl) == 1)
		{
			SQL_FetchString(hndl, 0, mapname, 128);
			db_selectBonusTopSurfers(client, mapname, SQL_FetchInt(hndl, 1));
			return;
		}

		Menu listBonusesinMapMenu = new Menu(MenuHandler_SelectBonusinMap);

		SQL_FetchString(hndl, 0, mapname, 128);
		zGrp = SQL_FetchInt(hndl, 1);
		Format(MenuTitle, 248, "Choose a Bonus in %s", mapname);
		listBonusesinMapMenu.SetTitle(MenuTitle);

		SQL_FetchString(hndl, 2, BonusName, 128);

		if (!BonusName[0])
			Format(BonusName, 128, "Bonus %i", zGrp);

		Format(MenuID, 248, "%s-%i", mapname, zGrp);

		listBonusesinMapMenu.AddItem(MenuID, BonusName);


		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 2, BonusName, 128);
			zGrp = SQL_FetchInt(hndl, 1);

			if (StrEqual(BonusName, "NULL", false))
				Format(BonusName, 128, "Bonus %i", zGrp);

			Format(MenuID, 248, "%s-%i", mapname, zGrp);

			listBonusesinMapMenu.AddItem(MenuID, BonusName);
		}

		listBonusesinMapMenu.ExitButton = true;
		listBonusesinMapMenu.Display(client, 60);
	}
	else
	{
		CPrintToChat(client, "%t", "SQL2", g_szChatPrefix);
		return;
	}
}

public int MenuHandler_SelectBonusinMap(Handle sMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[248];
			char splits[2][128];
			GetMenuItem(sMenu, item, aID, sizeof(aID));
			ExplodeString(aID, "-", splits, sizeof(splits), sizeof(splits[]));

			db_selectBonusTopSurfers(client, splits[0], StringToInt(splits[1]));
		}
		case MenuAction_End:
		{
			delete sMenu;
		}
	}
}

public void db_selectBonusTopSurfers(int client, char mapname[128], int zGrp)
{
	char szQuery[1024];
	Format(szQuery, 1024, sql_selectTopBonusSurfers, mapname, zGrp);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, mapname);
	WritePackCell(pack, zGrp);
	SQL_TQuery(g_hDb, sql_selectTopBonusSurfersCallback, szQuery, pack);
}

public void sql_selectTopBonusSurfersCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectTopBonusSurfersCallback): %s", error);
		return;
	}

	ResetPack(data);
	int client = ReadPackCell(data);
	char szMap[128];
	ReadPackString(data, szMap, 128);
	int zGrp = ReadPackCell(data);
	delete data;

	char szFirstMap[128], szValue[128], szName[64], szSteamID[32], lineBuf[256], title[256];
	float time;
	bool bduplicat = false;
	Handle stringArray = CreateArray(100);
	Menu topMenu;

	topMenu = new Menu(MapMenuHandler1);

	topMenu.Pagination = 5;

	if (SQL_HasResultSet(hndl))
	{
		int i = 1;
		while (SQL_FetchRow(hndl))
		{
			bduplicat = false;
			SQL_FetchString(hndl, 0, szSteamID, 32);
			SQL_FetchString(hndl, 1, szName, 64);
			time = SQL_FetchFloat(hndl, 2);
			SQL_FetchString(hndl, 4, szMap, 128);
			if (i == 1 || (i > 1 && StrEqual(szFirstMap, szMap)))
			{
				int stringArraySize = GetArraySize(stringArray);
				for (int x = 0; x < stringArraySize; x++)
				{
					GetArrayString(stringArray, x, lineBuf, sizeof(lineBuf));
					if (StrEqual(lineBuf, szName, false))
					bduplicat = true;
				}
				if (!bduplicat && i < 51)
				{
					char szTime[32];
					FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));
					if (time < 3600.0)
					Format(szTime, 32, "   %s", szTime);
					if (i == 100)
					Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					if (i >= 10)
					Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					else
					Format(szValue, 128, "[0%i.] %s |    » %s", i, szTime, szName);
					topMenu.AddItem(szSteamID, szValue, ITEMDRAW_DEFAULT);
					PushArrayString(stringArray, szName);
					if (i == 1)
					Format(szFirstMap, 128, "%s", szMap);
					i++;
				}
			}
		}
		if (i == 1)
		{
			CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, szMap);
		}
	}
	else
	CPrintToChat(client, "%t", "NoTopRecords", g_szChatPrefix, szMap);
	Format(title, 256, "Top 50 Times on %s (B %i) \n    Rank    Time               Player", szFirstMap, zGrp);
	topMenu.SetTitle(title);
	topMenu.OptionFlags = MENUFLAG_BUTTON_EXIT;
	topMenu.Display(client, MENU_TIME_FOREVER);
	delete stringArray;
}

public void db_currentRunRank(int client)
{
	if (!IsValidClient(client))
	return;

	char szQuery[512];
	Format(szQuery, 512, "SELECT count(runtimepro)+1 FROM `ck_playertimes` WHERE `mapname` = '%s' AND `runtimepro` < %f;", g_szMapName, g_fFinalTime[client]);
	SQL_TQuery(g_hDb, SQL_CurrentRunRankCallback, szQuery, client);
}

public void SQL_CurrentRunRankCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_CurrentRunRankCallback): %s", error);
		return;
	}
	// Get players rank, 9999999 = error
	int rank;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		rank = SQL_FetchInt(hndl, 0);
	}

	MapFinishedMsgs(client, rank);
}

// Get clients record from database
// Called when a player finishes a map
public void db_selectRecord(int client)
{
	if (!IsValidClient(client))
	return;

	char szQuery[255];
	Format(szQuery, 255, "SELECT runtimepro FROM ck_playertimes WHERE steamid = '%s' AND mapname = '%s' AND runtimepro > -1.0 AND style = 0;", g_szSteamID[client], g_szMapName);
	SQL_TQuery(g_hDb, sql_selectRecordCallback, szQuery, client);
}

public void sql_selectRecordCallback(Handle owner, Handle hndl, const char[] error, int client)
{
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (sql_selectRecordCallback): %s", error);
		return;
	}
	if (!IsValidClient(client)) {
		return;
	}

	char szQuery[512];
	DataPack pack = CreateDataPack();
	WritePackFloat(pack, g_fFinalTime[client]);
	WritePackCell(pack, client);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)) {
		// Found old time from database
		float time = SQL_FetchFloat(hndl, 0);

		// If old time was slower than the new time, update record
		if ((g_fFinalTime[client] <= time || time <= 0.0)) {
			char szUName[MAX_NAME_LENGTH];

			if (IsValidClient(client))
				GetClientName(client, szUName, MAX_NAME_LENGTH);
			else
				return;

			// Also updating name in database, escape string
			char szName[MAX_NAME_LENGTH * 2 + 1];
			SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);

			// "UPDATE ck_playertimes SET name = '%s', runtimepro = '%f' WHERE steamid = '%s' AND mapname = '%s' AND style = %i;";
			Format(szQuery, sizeof(szQuery), "UPDATE ck_playertimes SET name = '%s', runtimepro = '%f', startspeed = '%i' WHERE steamid = '%s' AND mapname = '%s' AND style = %i", szName, g_fFinalTime[client], g_iStartSpeed[client], g_szSteamID[client], g_szMapName, 0);
			SQL_TQuery(g_hDb, SQL_UpdateRecordProCallback, szQuery, pack);
		}
	} else {
		// No record found from database - Let's insert

		// Escape name for SQL injection protection
		char szName[MAX_NAME_LENGTH * 2 + 1], szUName[MAX_NAME_LENGTH];
		GetClientName(client, szUName, MAX_NAME_LENGTH);
		SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH);

		// "INSERT INTO ck_playertimes (steamid, mapname, name, runtimepro, style) VALUES('%s', '%s', '%s', '%f', %i);";
		Format(szQuery, sizeof(szQuery), "INSERT INTO ck_playertimes (steamid, mapname, name, runtimepro, startspeed, style) VALUES ('%s', '%s', '%s', '%f', %i, %i)", g_szSteamID[client], g_szMapName, szName, g_fFinalTime[client], g_iStartSpeed[client], 0);
		SQL_TQuery(g_hDb, SQL_UpdateRecordProCallback, szQuery, pack);

		g_bInsertNewTime = true;
	}
}
public void SQL_UpdateRecordProCallback(Handle owner, Handle hndl, const char[] error, DataPack data) {
	ResetPack(data);
	float time = ReadPackFloat(data);
	int client = ReadPackCell(data);
	delete data;

	if (hndl == null) {
		LogError("[Surftimer] SQL Error (SQL_UpdateRecordProCallback): %s", error);
		return;
	}

	// Find out how many times are are faster than the players time
	char szQuery[512];
	Format(szQuery, 512, "SELECT count(runtimepro) FROM `ck_playertimes` WHERE `mapname` = '%s' AND `runtimepro` < %f AND style = 0;", g_szMapName, time);
	SQL_TQuery(g_hDb, SQL_UpdateRecordProCallback2, szQuery, client);
}
public void SQL_UpdateRecordProCallback2(Handle owner, Handle hndl, const char[] error, int client) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (SQL_UpdateRecordProCallback2): %s", error);
		return;
	}
	// Get players rank, 9999999 = error
	int rank = 9999999;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		rank = (SQL_FetchInt(hndl, 0)+1);
	}
	g_MapRank[client] = rank;
	if (rank <= 10 && rank > 1)
		g_bTop10Time[client] = true;
	else
		g_bTop10Time[client] = false;

	MapFinishedMsgs(client);

	if (g_bInsertNewTime)
	{
		db_selectCurrentMapImprovement();
		g_bInsertNewTime = false;
	}
}

void db_viewAllRecords(int client, char szSteamId[32], bool rankedOnly, bool finished, int top = 0)
{
	char szSteamIdEx[MAX_NAME_LENGTH*2+1];
	SQL_EscapeString(g_hDb, szSteamId, szSteamIdEx, sizeof(szSteamIdEx));
	char rankedCondition[32] = "TRUE";
	if (rankedOnly) {
		rankedCondition = "ranked=1 AND tier > 0";
	}
	char finishedCondition[64];
	if (finished) {
		finishedCondition = "time IS NOT NULL";
	} else {
		finishedCondition = "time IS NULL";
	}
	char topCondition[32] = "TRUE";
	if (top > 0) {
		Format(topCondition, sizeof(topCondition), "rank <= %i", top);
	}
	int style = g_ProfileStyleSelect[client];
	char szQuery[4096];
	Format(szQuery, sizeof(szQuery), " \
		SELECT * FROM ( \
		SELECT \
			map.mapname, zone.zonegroup, map.tier, map.ranked, mytime.runtimepro AS time, \
			(SELECT COUNT(*)+1 FROM ck_playertimes alltimes WHERE alltimes.mapname=map.mapname AND alltimes.style=%i AND alltimes.runtimepro<mytime.runtimepro) AS rank, \
			(SELECT COUNT(*) FROM ck_playertimes alltimes WHERE alltimes.mapname=map.mapname AND alltimes.style=%i) as total \
		FROM \
			ck_maptier AS map \
			INNER JOIN (SELECT mapname, zonegroup, zonename FROM ck_zones WHERE zonetype IN (1,5) GROUP BY mapname, zonegroup, zonename) AS zone ON zone.mapname=map.mapname AND zone.zonegroup=0 \
			LEFT JOIN ck_playertimes AS mytime ON mytime.mapname=map.mapname AND mytime.style=%i AND mytime.steamid='%s' \
		UNION ALL SELECT \
			map.mapname, zone.zonegroup, map.tier, map.ranked, mytime.runtime AS time, \
			(SELECT COUNT(*)+1 FROM ck_bonus alltimes WHERE alltimes.mapname=map.mapname AND alltimes.zonegroup=zone.zonegroup AND alltimes.style=%i AND alltimes.runtime<mytime.runtime) AS rank, \
			(SELECT COUNT(*) FROM ck_bonus alltimes WHERE alltimes.mapname=map.mapname AND alltimes.zonegroup=zone.zonegroup AND alltimes.style=%i) as total \
		FROM \
			ck_maptier AS map \
			INNER JOIN (SELECT mapname, zonegroup, zonename FROM ck_zones WHERE zonetype IN (1,5) GROUP BY mapname, zonegroup, zonename) AS zone ON zone.mapname=map.mapname AND zone.zonegroup>0 \
			LEFT JOIN ck_bonus AS mytime ON mytime.mapname=map.mapname AND mytime.zonegroup=zone.zonegroup AND mytime.style=%i AND mytime.steamid='%s' \
		) a \
		WHERE %s AND %s AND %s \
		ORDER BY mapname, zonegroup ASC \
	",
	style, style, style, szSteamIdEx,
	style, style, style, szSteamIdEx,
	rankedCondition, finishedCondition, topCondition);

	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, rankedOnly);
	WritePackCell(pack, finished);
	WritePackCell(pack, top);
	SQL_TQuery(g_hDb, SQL_ViewAllRecordsCallback, szQuery, pack);
}
public void SQL_ViewAllRecordsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	int client = ReadPackCell(pack);
	ReadPackCell(pack); // int rankedOnly
	int finishedOnly = ReadPackCell(pack);
	int top = ReadPackCell(pack);
	delete pack;

	if (hndl == null) { LogError("[Surftimer] SQL Error (SQL_ViewAllRecordsCallback): %s", error); return; }
	if (!SQL_HasResultSet(hndl)) return;

	char szTitle[64];
	if (finishedOnly) {
		szTitle = "Finished Maps";
	} else {
		szTitle = "Unfinished Maps";
	}
	if (top > 0) {
		Format(szTitle, sizeof(szTitle), "%s (Ranked in top %i only)", szTitle, top);
	}

	ArrayList msgs = CreateArray(100);
	PushArrayString(msgs, " ");
	PushArrayString(msgs, "-------------");
	PushArrayString(msgs, szTitle);
	PushArrayString(msgs, "-------------");
	PushArrayString(msgs, " ");

	int totalMaps = 0;
	while (SQL_FetchRow(hndl)) {
		totalMaps++;
		int i = 0;
		char szMapName[128];
		SQL_FetchString(hndl, i++, szMapName, sizeof(szMapName));
		int izoneGroup = SQL_FetchInt(hndl, i++);
		int tier = SQL_FetchInt(hndl, i++);
		bool ranked = SQL_FetchInt(hndl, i++) > 0;
		bool finished = !SQL_IsFieldNull(hndl, i);
		float time = SQL_FetchFloat(hndl, i++);
		int rank = SQL_FetchInt(hndl, i++);
		int count = SQL_FetchInt(hndl, i++);

		char szTime[32], szRank[32];
		if (finished) {
			Format(szRank, sizeof(szRank), "%i", rank);
			FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));
		} else {
			szRank = "-";
			szTime = "-";
		}

		char szRanked[32] = "";
		if (!ranked || tier == 0) {
			szRanked = " (Unranked)";
		}

		char szBonus[32] = "";
		if (izoneGroup > 0) {
			Format(szBonus, sizeof(szBonus), " (Bonus %i)", izoneGroup);
		}

		char szValue[128];
		Format(szValue, sizeof(szValue), "%s%s%s - Tier: %i, Time: %s, Rank: %s/%i", szMapName, szBonus, szRanked, tier, szTime, szRank, count);

		PushArrayString(msgs, szValue);
	}

	if (totalMaps > 0) {
		CPrintToChat(client, "%t", "ConsoleOutput", g_szChatPrefix);
		DataPack out = CreateDataPack();
		WritePackCell(out, client);
		WritePackCell(out, 0);
		WritePackCell(out, msgs);
		ThrottledConsolePrint(out);
	} else {
		delete msgs;
	}
}

public void db_selectPlayer(int client)
{
	char szQuery[255];
	if (!IsValidClient(client))
	return;
	Format(szQuery, 255, sql_selectPlayer, g_szSteamID[client], g_szMapName);
	SQL_TQuery(g_hDb, SQL_SelectPlayerCallback, szQuery, client);
}

public void SQL_SelectPlayerCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_SelectPlayerCallback): %s", error);
		return;
	}

	if (!SQL_HasResultSet(hndl) && !SQL_FetchRow(hndl) && !IsValidClient(data))
		db_insertPlayer(data);
}

public void db_insertPlayer(int client)
{
	char szQuery[255];
	char szUName[MAX_NAME_LENGTH];
	if (IsValidClient(client))
	{
		GetClientName(client, szUName, MAX_NAME_LENGTH);
	}
	else
	return;
	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	Format(szQuery, 255, sql_insertPlayer, g_szSteamID[client], g_szMapName, szName);
	SQL_TQuery(g_hDb, SQL_InsertPlayerCallBack, szQuery, client);
}

/*===================================
=            PLAYER TEMP            =
===================================*/

public void db_deleteTmp(int client)
{
	char szQuery[256];
	if (!IsValidClient(client))
		return;
	Format(szQuery, 256, sql_deletePlayerTmp, g_szSteamID[client]);
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery, client);
}

public void db_selectLastRun(int client)
{
	char szQuery[512];
	if (!IsValidClient(client))
	return;
	Format(szQuery, 512, sql_selectPlayerTmp, g_szSteamID[client], g_szMapName);
	SQL_TQuery(g_hDb, SQL_LastRunCallback, szQuery, client);
}

public void SQL_LastRunCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_LastRunCallback): %s", error);
		return;
	}

	g_bTimerRunning[data] = false;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl) && IsValidClient(data))
	{

		// "SELECT cords1,cords2,cords3, angle1, angle2, angle3,runtimeTmp, EncTickrate, Stage, zonegroup FROM ck_playertemp WHERE steamid = '%s' AND mapname = '%s';";

		// Get last psition
		g_fPlayerCordsRestore[data][0] = SQL_FetchFloat(hndl, 0);
		g_fPlayerCordsRestore[data][1] = SQL_FetchFloat(hndl, 1);
		g_fPlayerCordsRestore[data][2] = SQL_FetchFloat(hndl, 2);
		g_fPlayerAnglesRestore[data][0] = SQL_FetchFloat(hndl, 3);
		g_fPlayerAnglesRestore[data][1] = SQL_FetchFloat(hndl, 4);
		g_fPlayerAnglesRestore[data][2] = SQL_FetchFloat(hndl, 5);


		int zGroup;
		zGroup = SQL_FetchInt(hndl, 9);

		g_iClientInZone[data][2] = zGroup;

		g_Stage[zGroup][data] = SQL_FetchInt(hndl, 8);

		// Set new start time
		float fl_time = SQL_FetchFloat(hndl, 6);
		int tickrate = RoundFloat(float(SQL_FetchInt(hndl, 7)) / 5.0 / 11.0);
		if (tickrate == g_Server_Tickrate)
		{
			if (fl_time > 0.0)
			{
				g_fStartTime[data] = GetGameTime() - fl_time;
				g_bTimerRunning[data] = true;
			}

			if (SQL_FetchFloat(hndl, 0) == -1.0 && SQL_FetchFloat(hndl, 1) == -1.0 && SQL_FetchFloat(hndl, 2) == -1.0)
			{
				g_bRestorePosition[data] = false;
				g_bRestorePositionMsg[data] = false;
			}
			else
			{
				if (g_bLateLoaded && IsPlayerAlive(data) && !g_specToStage[data])
				{
					g_bPositionRestored[data] = true;
					TeleportEntity(data, g_fPlayerCordsRestore[data], g_fPlayerAnglesRestore[data], NULL_VECTOR);
					g_bRestorePosition[data] = false;
				}
				else
				{
					g_bRestorePosition[data] = true;
					g_bRestorePositionMsg[data] = true;
				}

			}
		}
	}
	else
	{

		g_bTimerRunning[data] = false;
	}
}

/*===================================
=            CHECKPOINTS            =
===================================*/

public void db_UpdateCheckpoints(int client, char szSteamID[32], int zGroup)
{
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, zGroup);
	if (g_bCheckpointsFound[zGroup][client])
	{
		char szQuery[1024];
		Format(szQuery, 1024, sql_updateCheckpoints, g_fCheckpointTimesNew[zGroup][client][0], g_fCheckpointTimesNew[zGroup][client][1], g_fCheckpointTimesNew[zGroup][client][2], g_fCheckpointTimesNew[zGroup][client][3], g_fCheckpointTimesNew[zGroup][client][4], g_fCheckpointTimesNew[zGroup][client][5], g_fCheckpointTimesNew[zGroup][client][6], g_fCheckpointTimesNew[zGroup][client][7], g_fCheckpointTimesNew[zGroup][client][8], g_fCheckpointTimesNew[zGroup][client][9], g_fCheckpointTimesNew[zGroup][client][10], g_fCheckpointTimesNew[zGroup][client][11], g_fCheckpointTimesNew[zGroup][client][12], g_fCheckpointTimesNew[zGroup][client][13], g_fCheckpointTimesNew[zGroup][client][14], g_fCheckpointTimesNew[zGroup][client][15], g_fCheckpointTimesNew[zGroup][client][16], g_fCheckpointTimesNew[zGroup][client][17], g_fCheckpointTimesNew[zGroup][client][18], g_fCheckpointTimesNew[zGroup][client][19], g_fCheckpointTimesNew[zGroup][client][20], g_fCheckpointTimesNew[zGroup][client][21], g_fCheckpointTimesNew[zGroup][client][22], g_fCheckpointTimesNew[zGroup][client][23], g_fCheckpointTimesNew[zGroup][client][24], g_fCheckpointTimesNew[zGroup][client][25], g_fCheckpointTimesNew[zGroup][client][26], g_fCheckpointTimesNew[zGroup][client][27], g_fCheckpointTimesNew[zGroup][client][28], g_fCheckpointTimesNew[zGroup][client][29], g_fCheckpointTimesNew[zGroup][client][30], g_fCheckpointTimesNew[zGroup][client][31], g_fCheckpointTimesNew[zGroup][client][32], g_fCheckpointTimesNew[zGroup][client][33], g_fCheckpointTimesNew[zGroup][client][34], szSteamID, g_szMapName, zGroup);
		SQL_TQuery(g_hDb, SQL_updateCheckpointsCallback, szQuery, pack);
	}
	else
	{
		char szQuery[1024];
		Format(szQuery, 1024, sql_insertCheckpoints, szSteamID, g_szMapName, g_fCheckpointTimesNew[zGroup][client][0], g_fCheckpointTimesNew[zGroup][client][1], g_fCheckpointTimesNew[zGroup][client][2], g_fCheckpointTimesNew[zGroup][client][3], g_fCheckpointTimesNew[zGroup][client][4], g_fCheckpointTimesNew[zGroup][client][5], g_fCheckpointTimesNew[zGroup][client][6], g_fCheckpointTimesNew[zGroup][client][7], g_fCheckpointTimesNew[zGroup][client][8], g_fCheckpointTimesNew[zGroup][client][9], g_fCheckpointTimesNew[zGroup][client][10], g_fCheckpointTimesNew[zGroup][client][11], g_fCheckpointTimesNew[zGroup][client][12], g_fCheckpointTimesNew[zGroup][client][13], g_fCheckpointTimesNew[zGroup][client][14], g_fCheckpointTimesNew[zGroup][client][15], g_fCheckpointTimesNew[zGroup][client][16], g_fCheckpointTimesNew[zGroup][client][17], g_fCheckpointTimesNew[zGroup][client][18], g_fCheckpointTimesNew[zGroup][client][19], g_fCheckpointTimesNew[zGroup][client][20], g_fCheckpointTimesNew[zGroup][client][21], g_fCheckpointTimesNew[zGroup][client][22], g_fCheckpointTimesNew[zGroup][client][23], g_fCheckpointTimesNew[zGroup][client][24], g_fCheckpointTimesNew[zGroup][client][25], g_fCheckpointTimesNew[zGroup][client][26], g_fCheckpointTimesNew[zGroup][client][27], g_fCheckpointTimesNew[zGroup][client][28], g_fCheckpointTimesNew[zGroup][client][29], g_fCheckpointTimesNew[zGroup][client][30], g_fCheckpointTimesNew[zGroup][client][31], g_fCheckpointTimesNew[zGroup][client][32], g_fCheckpointTimesNew[zGroup][client][33], g_fCheckpointTimesNew[zGroup][client][34], zGroup);
		SQL_TQuery(g_hDb, SQL_updateCheckpointsCallback, szQuery, pack);
	}
}

public void SQL_updateCheckpointsCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_updateCheckpointsCallback): %s", error);
		return;
	}
	ResetPack(data);
	int client = ReadPackCell(data);
	ReadPackCell(data); // int zonegrp
	delete data;

	db_refreshCheckpoints(client);
}

public void db_deleteCheckpoints()
{
	char szQuery[258];
	Format(szQuery, 258, sql_deleteCheckpoints, g_szMapName);
	SQL_TQuery(g_hDb, SQL_deleteCheckpointsCallback, szQuery);
}

public void SQL_deleteCheckpointsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_deleteCheckpointsCallback): %s", error);
		return;
	}
}

/*===================================
=             SQL Bonus             =
===================================*/

public void db_currentBonusRunRank(int client, int zGroup)
{
	char szQuery[512];
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, zGroup);
	Format(szQuery, 512, "SELECT count(runtime)+1 FROM ck_bonus WHERE mapname = '%s' AND zonegroup = '%i' AND runtime < %f", g_szMapName, zGroup, g_fFinalTime[client]);
	SQL_TQuery(g_hDb, db_viewBonusRunRank, szQuery, pack);
}

public void db_viewBonusRunRank(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_viewBonusRunRank): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int zGroup = ReadPackCell(pack);
	delete pack;
	int rank;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		rank = SQL_FetchInt(hndl, 0);
	}

	PrintChatBonus(client, zGroup, rank);
}

public void db_deleteBonus()
{
	char szQuery[1024];
	Format(szQuery, 1024, sql_deleteBonus, g_szMapName);
	SQL_TQuery(g_hDb, SQL_deleteBonusCallback, szQuery);
}

public void db_insertBonus(int client, char szSteamId[32], char szUName[MAX_NAME_LENGTH], float finalTime, int startSpeed, int zoneGrp)
{
	char szQuery[1024];
	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, zoneGrp);
	Format(szQuery, 1024, sql_insertBonus, szSteamId, szName, g_szMapName, finalTime, startSpeed, zoneGrp);
	SQL_TQuery(g_hDb, SQL_updateBonusCallback, szQuery, pack);
}

public void db_updateBonus(int client, char szSteamId[32], char szUName[MAX_NAME_LENGTH], float finalTime, int startSpeed, int zoneGrp)
{
	char szQuery[1024];
	char szName[MAX_NAME_LENGTH * 2 + 1];
	Handle datapack = CreateDataPack();
	WritePackCell(datapack, client);
	WritePackCell(datapack, zoneGrp);
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	Format(szQuery, 1024, sql_updateBonus, finalTime, startSpeed, szName, szSteamId, g_szMapName, zoneGrp);
	SQL_TQuery(g_hDb, SQL_updateBonusCallback, szQuery, datapack);
}


public void SQL_updateBonusCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	ResetPack(data);
	int client = ReadPackCell(data);
	int zgroup = ReadPackCell(data);
	delete data;

	if (hndl == null) {
		LogError("[Surftimer] SQL Error (SQL_updateBonusCallback): %s", error);
		return;
	}

	db_viewBonusTotalCount();
	RefreshAndPrintRecord(client, zgroup, 0);
	CalculatePlayerRank(client, 0);
}

public void SQL_deleteBonusCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_deleteBonusCallback): %s", error);
		return;
	}
}

/*===================================
=             SQL Zones             =
===================================*/

public void db_setZoneNames(int client, char szName[128])
{
	char szQuery[512], szEscapedName[128 * 2 + 1];
	SQL_EscapeString(g_hDb, szName, szEscapedName, 128 * 2 + 1);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, g_CurrentSelectedZoneGroup[client]);
	WritePackString(pack, szEscapedName);
	// UPDATE ck_zones SET zonename = '%s' WHERE mapname = '%s' AND zonegroup = '%i';
	Format(szQuery, 512, sql_setZoneNames, szEscapedName, g_szMapName, g_CurrentSelectedZoneGroup[client]);
	SQL_TQuery(g_hDb, sql_setZoneNamesCallback, szQuery, pack);
}

public void sql_setZoneNamesCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_setZoneNamesCallback): %s", error);
		delete data;
		return;
	}

	char szName[64];
	ResetPack(data);
	int client = ReadPackCell(data);
	int zonegrp = ReadPackCell(data);
	ReadPackString(data, szName, 64);
	delete data;

	for (int i = 0; i < g_mapZonesCount; i++)
	{
		if (g_mapZones[i].zoneGroup == zonegrp)
		Format(g_mapZones[i].zoneName, 64, szName);
	}

	if (IsValidClient(client))
	{
		CPrintToChat(client, "%t", "SQL4", g_szChatPrefix);
		ListBonusSettings(client);
	}
	db_selectMapZones();
}

public void db_checkAndFixZoneIds()
{
	char szQuery[512];
	// "SELECT mapname, zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename FROM ck_zones WHERE mapname = '%s' ORDER BY zoneid ASC";
	if (!g_szMapName[0])
	GetCurrentMap(g_szMapName, 128);

	Format(szQuery, 512, sql_selectZoneIds, g_szMapName);
	SQL_TQuery(g_hDb, db_checkAndFixZoneIdsCallback, szQuery, 1);
}

public void db_checkAndFixZoneIdsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_checkAndFixZoneIdsCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		bool IDError = false;
		float x1[128], y1[128], z1[128], x2[128], y2[128], z2[128];
		int checker = 0, i, zonetype[128], zonetypeid[128], zoneGrp[128];
		char zName[128][128];
		char hookname[128][128], targetname[128][128];
		int onejumplimit[128];
		float prespeed[128];

		while (SQL_FetchRow(hndl))
		{
			i = SQL_FetchInt(hndl, 1);
			zonetype[checker] = SQL_FetchInt(hndl, 2);
			zonetypeid[checker] = SQL_FetchInt(hndl, 3);
			x1[checker] = SQL_FetchFloat(hndl, 4);
			y1[checker] = SQL_FetchFloat(hndl, 5);
			z1[checker] = SQL_FetchFloat(hndl, 6);
			x2[checker] = SQL_FetchFloat(hndl, 7);
			y2[checker] = SQL_FetchFloat(hndl, 8);
			z2[checker] = SQL_FetchFloat(hndl, 9);
			zoneGrp[checker] = SQL_FetchInt(hndl, 12);
			SQL_FetchString(hndl, 13, zName[checker], 128);
			SQL_FetchString(hndl, 14, hookname[checker], 128);
			SQL_FetchString(hndl, 15, targetname[checker], 128);
			onejumplimit[checker] = SQL_FetchInt(hndl, 16);
			prespeed[checker] = SQL_FetchFloat(hndl, 17);

			if (i != checker)
			IDError = true;

			checker++;
		}

		if (IDError)
		{
			char szQuery[256];
			Format(szQuery, 256, sql_deleteMapZones, g_szMapName);
			SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
			// SQL_FastQuery(g_hDb, szQuery);

			for (int k = 0; k < checker; k++)
			{
				db_insertZoneCheap(k, zonetype[k], zonetypeid[k], x1[k], y1[k], z1[k], x2[k], y2[k], z2[k], 0, 0, zoneGrp[k], zName[k], -10, hookname[k], targetname[k], onejumplimit[k], prespeed[k]);
			}
		}
	}
	db_selectMapZones();
}

public void ZoneDefaultName(int zonetype, int zonegroup, char zName[128])
{
	if (zonegroup > 0)
		Format(zName, 64, "Bonus %i", zonegroup);
	else if (-1 < zonetype < MAX_ZONETYPES)
		Format(zName, 128, "%s %i", g_szZoneDefaultNames[zonetype], zonegroup);
	else
		Format(zName, 64, "Unknown");
}

public void db_insertZoneCheap(int zoneid, int zonetype, int zonetypeid, float pointax, float pointay, float pointaz, float pointbx, float pointby, float pointbz, int vis, int team, int zGrp, char zName[128], int query, char hookname[128], char targetname[128], int ojl, float prespeed)
{
	char szQuery[1024];
	// "INSERT INTO ck_zones (mapname, zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename) VALUES ('%s', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%s')";
	Format(szQuery, 1024, sql_insertZones, g_szMapName, zoneid, zonetype, zonetypeid, pointax, pointay, pointaz, pointbx, pointby, pointbz, vis, team, zGrp, zName, hookname, targetname, ojl, prespeed);
	SQL_TQuery(g_hDb, SQL_insertZonesCheapCallback, szQuery, query);
}

public void SQL_insertZonesCheapCallback(Handle owner, Handle hndl, const char[] error, any query)
{
	if (hndl == null)
	{
		CPrintToChatAll("%t", "SQL5", g_szChatPrefix);
		db_checkAndFixZoneIds();
		return;
	}

	if (query == (g_mapZonesCount - 1))
		db_selectMapZones();
}

public void db_insertZone(int zoneid, int zonetype, int zonetypeid, float pointax, float pointay, float pointaz, float pointbx, float pointby, float pointbz, int vis, int team, int zonegroup)
{
	char szQuery[1024];
	char zName[128];

	if (zonegroup == g_mapZoneGroupCount)
		ZoneDefaultName(zonetype, zonegroup, zName);
	else
		Format(zName, 128, g_szZoneGroupName[zonegroup]);

	// char sql_insertZones[] = "INSERT INTO ck_zones (mapname, zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename, hookname, targetname, onejumplimit, prespeed) VALUES ('%s', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i','%s','%s','%s',%i,%f)";
	Format(szQuery, 1024, sql_insertZones, g_szMapName, zoneid, zonetype, zonetypeid, pointax, pointay, pointaz, pointbx, pointby, pointbz, vis, team, zonegroup, zName, "None", "player", 1, 250.0);
	SQL_TQuery(g_hDb, SQL_insertZonesCallback, szQuery);
}

public void SQL_insertZonesCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		CPrintToChatAll("%t", "SQL5", g_szChatPrefix);
		db_checkAndFixZoneIds();
		return;
	}

	db_selectMapZones();
}

public void db_insertZoneHook(int zoneid, int zonetype, int zonetypeid, int vis, int team, int zonegroup, char[] szHookName, float point_a[3], float point_b[3])
{
	char szQuery[1024];
	char zName[128];

	if (zonegroup == g_mapZoneGroupCount)
		ZoneDefaultName(zonetype, zonegroup, zName);
	else
		Format(zName, 128, g_szZoneGroupName[zonegroup]);

	// "INSERT INTO ck_zones (mapname, zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename) VALUES ('%s', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i', '%s')";
	Format(szQuery, 1024, "INSERT INTO ck_zones (mapname, zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename, hookname) VALUES ('%s', '%i', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%i', '%i', '%i','%s','%s')", g_szMapName, zoneid, zonetype, zonetypeid, point_a[0], point_a[1], point_a[2], point_b[0], point_b[1], point_b[2], vis, team, zonegroup, zName, szHookName);
	SQL_TQuery(g_hDb, SQL_insertZonesCallback, szQuery);
}

public void db_saveZones()
{
	char szQuery[258];
	Format(szQuery, 258, sql_deleteMapZones, g_szMapName);
	SQL_TQuery(g_hDb, SQL_saveZonesCallBack, szQuery);
}

public void SQL_saveZonesCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_saveZonesCallBack): %s", error);
		return;
	}
	char szzone[128];
	char hookname[128], targetname[128];
	for (int i = 0; i < g_mapZonesCount; i++)
	{
		Format(szzone, 128, "%s", g_szZoneGroupName[g_mapZones[i].zoneGroup]);
		Format(hookname, 128, "%s", g_mapZones[i].hookName);
		Format(targetname, 128, "%s", g_mapZones[i].targetName);

		if (g_mapZones[i].PointA[0] != -1.0 && g_mapZones[i].PointA[1] != -1.0 && g_mapZones[i].PointA[2] != -1.0)
		{
			db_insertZoneCheap(g_mapZones[i].zoneId, g_mapZones[i].zoneType, g_mapZones[i].zoneTypeId, g_mapZones[i].PointA[0], g_mapZones[i].PointA[1], g_mapZones[i].PointA[2],
							   g_mapZones[i].PointB[0], g_mapZones[i].PointB[1], g_mapZones[i].PointB[2], 0, 0, g_mapZones[i].zoneGroup, szzone, i, hookname, targetname, g_mapZones[i].oneJumpLimit, g_mapZones[i].preSpeed);
		}
	}
}

public void db_updateZone(int zoneid, int zonetype, int zonetypeid, float[] Point1, float[] Point2, int vis, int team, int zonegroup, int onejumplimit, float prespeed, char[] hookname, char[] targetname)
{
	char szQuery[1024];
	Format(szQuery, 1024, sql_updateZone, zonetype, zonetypeid, Point1[0], Point1[1], Point1[2], Point2[0], Point2[1], Point2[2], vis, team, onejumplimit, prespeed, hookname, targetname, zonegroup, zoneid, g_szMapName);
	SQL_TQuery(g_hDb, SQL_updateZoneCallback, szQuery);
}

public void SQL_updateZoneCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_updateZoneCallback): %s", error);
		return;
	}

	db_selectMapZones();
}

public int db_deleteZonesInGroup(int client)
{
	char szQuery[258];

	if (g_CurrentSelectedZoneGroup[client] < 1)
	{
		if (IsValidClient(client))
			CPrintToChat(client, "%t", "SQL6", g_szChatPrefix, g_CurrentSelectedZoneGroup[client]);

		PrintToServer("surftimer | Invalid zonegroup index selected, aborting. (%i)", g_CurrentSelectedZoneGroup[client]);
	}

	Transaction h_DeleteZoneGroup = SQL_CreateTransaction();
	//"DELETE FROM ck_zones WHERE mapname = '%s' AND zonegroup = '%i'"
	Format(szQuery, 258, sql_deleteZonesInGroup, g_szMapName, g_CurrentSelectedZoneGroup[client]);
	SQL_AddQuery(h_DeleteZoneGroup, szQuery);

	Format(szQuery, 258, "DELETE FROM ck_bonus WHERE zonegroup = %i AND mapname = '%s';", g_CurrentSelectedZoneGroup[client], g_szMapName);
	SQL_AddQuery(h_DeleteZoneGroup, szQuery);

	// dunno why these were commented out originally, they work as intended
	Format(szQuery, 258, "UPDATE ck_zones SET zonegroup = zonegroup-1 WHERE zonegroup > %i AND mapname = '%s';", g_CurrentSelectedZoneGroup[client], g_szMapName);
	SQL_AddQuery(h_DeleteZoneGroup, szQuery);

	Format(szQuery, 258, "UPDATE ck_bonus SET zonegroup = zonegroup-1 WHERE zonegroup > %i AND mapname = '%s';", g_CurrentSelectedZoneGroup[client], g_szMapName);
	SQL_AddQuery(h_DeleteZoneGroup, szQuery);

	SQL_ExecuteTransaction(g_hDb, h_DeleteZoneGroup, SQLTxn_ZoneGroupRemovalSuccess, SQLTxn_ZoneGroupRemovalFailed, client);

	// reload all players just in case
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		LoadPlayerStart(i);
	}
}

public void SQLTxn_ZoneGroupRemovalSuccess(Handle db, any client, int numQueries, Handle[] results, any[] queryData)
{
	PrintToServer("surftimer | Zonegroup removal was successful");

	db_selectMapZones();
	db_viewFastestBonus();
	db_viewBonusTotalCount();
	db_viewRecordCheckpointInMap();

	if (IsValidClient(client))
	{
		ZoneMenu(client);
		CPrintToChat(client, "%t", "SQL7", g_szChatPrefix);
	}
}

public void SQLTxn_ZoneGroupRemovalFailed(Handle db, any client, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if (IsValidClient(client))
	CPrintToChat(client, "%t", "SQL8", g_szChatPrefix, error);

	PrintToServer("surftimer | Zonegroup removal failed (Index: %i | Error: %s)", failIndex, error);
	return;
}

public void db_selectzoneTypeIds(int zonetype, int client, int zonegrp)
{
	char szQuery[258];
	Format(szQuery, 258, sql_selectzoneTypeIds, g_szMapName, zonetype, zonegrp);
	SQL_TQuery(g_hDb, SQL_selectzoneTypeIdsCallback, szQuery, client);
}

public void SQL_selectzoneTypeIdsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_selectzoneTypeIdsCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int availableids[MAX_ZONES] = { 0, ... }, i;
		while (SQL_FetchRow(hndl))
		{
			i = SQL_FetchInt(hndl, 0);
			if (i < MAX_ZONES)
				availableids[i] = 1;
		}
		Menu TypeMenu = new Menu(Handle_EditZoneTypeId);
		char MenuNum[24], MenuInfo[6], MenuItemName[24];
		int x = 0;
		// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0) //fluffys AntiJump(9), AntiDuck(10)
		switch (g_CurrentZoneType[data])
		{
			case 0: Format(MenuItemName, 24, "Stop");
			case 1: Format(MenuItemName, 24, "Start");
			case 2: Format(MenuItemName, 24, "End");
			case 3:
			{
				Format(MenuItemName, 24, "Stage");
				x = 2;
			}
			case 4: Format(MenuItemName, 24, "Checkpoint");
			case 5: Format(MenuItemName, 24, "Speed");
			case 6: Format(MenuItemName, 24, "TeleToStart");
			case 7: Format(MenuItemName, 24, "Validator");
			case 8: Format(MenuItemName, 24, "Checker");
			// fluffys
			case 9: Format(MenuItemName, 24, "AntiJump");
			case 10: Format(MenuItemName, 24, "AntiDuck");
			case 11: Format(MenuItemName, 24, "MaxSpeed");
			default: Format(MenuItemName, 24, "Unknown");
		}

		for (int k = 0; k < 35; k++)
		{
			if (availableids[k] == 0)
			{
				Format(MenuNum, sizeof(MenuNum), "%s-%i", MenuItemName, (k + x));
				Format(MenuInfo, sizeof(MenuInfo), "%i", k);
				TypeMenu.AddItem(MenuInfo, MenuNum);
			}
		}
		TypeMenu.ExitButton = true;
		TypeMenu.Display(data, MENU_TIME_FOREVER);
	}
}

public void sql_zoneFixCallback(Handle owner, Handle hndl, const char[] error, any zongeroup)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_zoneFixCallback): %s", error);
		return;
	}
	if (zongeroup == -1)
		db_selectMapZones();
	else
	{
		char szQuery[258];
		Format(szQuery, 258, "DELETE FROM `ck_bonus` WHERE `mapname` = '%s' AND `zonegroup` = %i;", g_szMapName, zongeroup);
		SQL_TQuery(g_hDb, sql_zoneFixCallback2, szQuery, zongeroup);
	}
}

public void sql_zoneFixCallback2(Handle owner, Handle hndl, const char[] error, any zongeroup)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_zoneFixCallback2): %s", error);
		return;
	}

	char szQuery[258];
	Format(szQuery, 258, "UPDATE ck_bonus SET zonegroup = zonegroup-1 WHERE `mapname` = '%s' AND `zonegroup` = %i;", g_szMapName, zongeroup);
	SQL_TQuery(g_hDb, sql_zoneFixCallback, szQuery);
}

public void db_deleteMapZones()
{
	char szQuery[258];
	Format(szQuery, 258, sql_deleteMapZones, g_szMapName);
	SQL_TQuery(g_hDb, SQL_deleteMapZonesCallback, szQuery);
}

public void SQL_deleteMapZonesCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_deleteMapZonesCallback): %s", error);
		return;
	}
}

public void db_deleteZone(int client, int zoneid)
{
	char szQuery[258];
	Transaction h_deleteZone = SQL_CreateTransaction();

	Format(szQuery, 258, sql_deleteZone, g_szMapName, zoneid);
	SQL_AddQuery(h_deleteZone, szQuery);

	Format(szQuery, 258, "UPDATE ck_zones SET zoneid = zoneid-1 WHERE mapname = '%s' AND zoneid > %i", g_szMapName, zoneid);
	SQL_AddQuery(h_deleteZone, szQuery);

	SQL_ExecuteTransaction(g_hDb, h_deleteZone, SQLTxn_ZoneRemovalSuccess, SQLTxn_ZoneRemovalFailed, client);
}

public void SQLTxn_ZoneRemovalSuccess(Handle db, any client, int numQueries, Handle[] results, any[] queryData)
{
	if (IsValidClient(client))
		CPrintToChat(client, "%t", "SQL9", g_szChatPrefix);
	PrintToServer("[Surftimer] Zone Removed Succesfully");
}

public void SQLTxn_ZoneRemovalFailed(Handle db, any client, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	if (IsValidClient(client))
		CPrintToChat(client, "%t", "SQL10", g_szChatPrefix, error);
	PrintToServer("[Surftimer] Zone Removal Failed. Error: %s", error);
	return;
}

/*==================================
=               MISC               =
==================================*/

public void db_insertLastPosition(int client, char szMapName[128], int stage, int zgroup)
{
	if (GetConVarBool(g_hcvarRestore) && !g_bRoundEnd && (StrContains(g_szSteamID[client], "STEAM_") != -1) && g_bTimerRunning[client])
	{
		DataPack pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, szMapName);
		WritePackString(pack, g_szSteamID[client]);
		WritePackCell(pack, stage);
		WritePackCell(pack, zgroup);
		char szQuery[512];
		Format(szQuery, 512, "SELECT * FROM ck_playertemp WHERE steamid = '%s'", g_szSteamID[client]);
		SQL_TQuery(g_hDb, db_insertLastPositionCallback, szQuery, pack);
	}
}

public void db_insertLastPositionCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_insertLastPositionCallback): %s", error);
		return;
	}

	char szQuery[1024];
	char szMapName[128];
	char szSteamID[32];

	ResetPack(data);
	int client = ReadPackCell(data);
	ReadPackString(data, szMapName, 128);
	ReadPackString(data, szSteamID, 32);
	int stage = ReadPackCell(data);
	int zgroup = ReadPackCell(data);
	delete data;

	if (1 <= client <= MaxClients)
	{
		if (!g_bTimerRunning[client])
			g_fPlayerLastTime[client] = -1.0;
		int tickrate = g_Server_Tickrate * 5 * 11;
		if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		{
			Format(szQuery, 1024, sql_updatePlayerTmp, g_fPlayerCordsLastPosition[client][0], g_fPlayerCordsLastPosition[client][1], g_fPlayerCordsLastPosition[client][2], g_fPlayerAnglesLastPosition[client][0], g_fPlayerAnglesLastPosition[client][1], g_fPlayerAnglesLastPosition[client][2], g_fPlayerLastTime[client], szMapName, tickrate, stage, zgroup, szSteamID);
			SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
		}
		else
		{
			Format(szQuery, 1024, sql_insertPlayerTmp, g_fPlayerCordsLastPosition[client][0], g_fPlayerCordsLastPosition[client][1], g_fPlayerCordsLastPosition[client][2], g_fPlayerAnglesLastPosition[client][0], g_fPlayerAnglesLastPosition[client][1], g_fPlayerAnglesLastPosition[client][2], g_fPlayerLastTime[client], szSteamID, szMapName, tickrate, stage, zgroup);
			SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
		}
	}
}

public void db_deletePlayerTmps()
{
	char szQuery[64];
	Format(szQuery, 64, "delete FROM ck_playertemp");
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
}

public void db_ViewLatestRecords(int client)
{
	SQL_TQuery(g_hDb, sql_selectLatestRecordsCallback, sql_selectLatestRecords, client);
}

public void sql_selectLatestRecordsCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectLatestRecordsCallback): %s", error);
		return;
	}

	char szName[64];
	char szMapName[64];
	char szDate[64];
	char szTime[32];
	float ftime;
	PrintToConsole(data, "----------------------------------------------------------------------------------------------------");
	PrintToConsole(data, "Last map records:");
	if (SQL_HasResultSet(hndl))
	{
		Menu menu = CreateMenu(LatestRecordsMenuHandler);
		SetMenuTitle(menu, "Recently Broken Records");

		int i = 1;
		char szItem[128];
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, szName, 64);
			ftime = SQL_FetchFloat(hndl, 1);
			FormatTimeFloat(data, ftime, 3, szTime, sizeof(szTime));
			SQL_FetchString(hndl, 2, szMapName, 64);
			SQL_FetchString(hndl, 3, szDate, 64);
			Format(szItem, sizeof(szItem), "%s - %s by %s (%s)", szMapName, szTime, szName, szDate);
			PrintToConsole(data, szItem);
			AddMenuItem(menu, "", szItem, ITEMDRAW_DISABLED);
			i++;
		}
		if (i == 1)
		{
			PrintToConsole(data, "No records found.");
			delete menu;
		}
		else
		{
			SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
			DisplayMenu(menu, data, MENU_TIME_FOREVER);
		}
	}
	else
	PrintToConsole(data, "No records found.");
	PrintToConsole(data, "----------------------------------------------------------------------------------------------------");
	CPrintToChat(data, "%t", "ConsoleOutput", g_szChatPrefix);
}

public int LatestRecordsMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
		delete menu;
}

public void db_InsertLatestRecords(char szSteamID[32], char szName[MAX_NAME_LENGTH], float FinalTime)
{
	char szQuery[512];
	Format(szQuery, 512, sql_insertLatestRecords, szSteamID, szName, FinalTime, g_szMapName);
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
}

public void sql_selectPlayerNameCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectPlayerNameCallback): %s", error);
		return;
	}

	ResetPack(data);
	int clientid = ReadPackCell(data);
	int client = ReadPackCell(data);
	delete data;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, g_pr_szName[clientid], 64);
		g_bProfileRecalc[clientid] = true;
		if (IsValidClient(client))
			PrintToConsole(client, "Profile refreshed (%s).", g_pr_szSteamID[clientid]);
	}
	else if (IsValidClient(client))
		PrintToConsole(client, "SteamID %s not found.", g_pr_szSteamID[clientid]);
}

// 0. Admins counting players points starts here
public void RefreshPlayerRankTable(int max)
{
	g_pr_Recalc_ClientID = 1;
	g_pr_RankingRecalc_InProgress = true;
	char szQuery[255];

	// SELECT steamid, name from ck_playerrank where points > 0 ORDER BY points DESC";
	// SELECT steamid, name from ck_playerrank where points > 0 ORDER BY points DESC
	Format(szQuery, 255, sql_selectRankedPlayers);
	SQL_TQuery(g_hDb, sql_selectRankedPlayersCallback, szQuery, max);
}

public void sql_selectRankedPlayersCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectRankedPlayersCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int i = 66;
		int x;
		g_pr_TableRowCount = SQL_GetRowCount(hndl);
		if (g_pr_TableRowCount == 0)
		{
			for (int c = 1; c <= MaxClients; c++)
				if (1 <= c <= MaxClients && IsValidEntity(c) && IsValidClient(c) && g_bManualRecalc)
					CPrintToChat(c, "%t", "PrUpdateFinished", g_szChatPrefix);

			g_bManualRecalc = false;
			g_pr_RankingRecalc_InProgress = false;

			if (IsValidClient(g_pr_Recalc_AdminID))
			{
				PrintToConsole(g_pr_Recalc_AdminID, ">> Recalculation finished");
				CreateTimer(0.1, RefreshAdminMenu, g_pr_Recalc_AdminID, TIMER_FLAG_NO_MAPCHANGE);
			}
		}

		if (MAX_PR_PLAYERS != data && g_pr_TableRowCount > data)
			x = 66 + data;
		else
			x = 66 + g_pr_TableRowCount;

		if (g_pr_TableRowCount > MAX_PR_PLAYERS)
			g_pr_TableRowCount = MAX_PR_PLAYERS;

		if (x > MAX_PR_PLAYERS)
			x = MAX_PR_PLAYERS - 1;

		if (IsValidClient(g_pr_Recalc_AdminID) && g_bManualRecalc)
		{
			int max = MAX_PR_PLAYERS - 66;
			PrintToConsole(g_pr_Recalc_AdminID, " \n>> Recalculation started! (Only Top %i because of performance reasons)", max);
		}

		while (SQL_FetchRow(hndl))
		{
			if (i <= x)
			{
				g_pr_points[i][0] = 0;
				SQL_FetchString(hndl, 0, g_pr_szSteamID[i], 32);
				SQL_FetchString(hndl, 1, g_pr_szName[i], 64);

				g_bProfileRecalc[i] = true;
				i++;
			}

			if (i == x)
				CalculatePlayerRank(66, 0);
		}
	}
	else
		PrintToConsole(g_pr_Recalc_AdminID, " \n>> No valid players found!");
}

public void db_Cleanup()
{
	char szQuery[255];

	// tmps
	Format(szQuery, 255, "DELETE FROM ck_playertemp where mapname != '%s'", g_szMapName);
	SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);

	// times
	SQL_TQuery(g_hDb, SQL_CheckCallback, "DELETE FROM ck_playertimes where runtimepro = -1.0");

	// fluffys pointless players
	SQL_TQuery(g_hDb, SQL_CheckCallback, "DELETE FROM ck_playerrank WHERE `points` <= 0");
	/*SQL_TQuery(g_hDb, SQL_CheckCallback, "DELETE FROM ck_wrcps WHERE `runtimepro` <= -1.0");
	SQL_TQuery(g_hDb, SQL_CheckCallback, "DELETE FROM ck_wrcps WHERE `stage` = 0");*/

}

public void SQL_InsertPlayerCallBack(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_InsertPlayerCallBack): %s", error);
		return;
	}

	if (IsClientInGame(data))
		db_UpdateLastSeen(data);
}

public void db_UpdateLastSeen(int client)
{
	if ((StrContains(g_szSteamID[client], "STEAM_") != -1) && !IsFakeClient(client))
	{
		char szQuery[512];
		if (g_DbType == MYSQL)
			Format(szQuery, 512, sql_UpdateLastSeenMySQL, g_szSteamID[client]);
		else if (g_DbType == SQLITE)
			Format(szQuery, 512, sql_UpdateLastSeenSQLite, g_szSteamID[client]);

		SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery);
	}
}

/*===================================
=         DEFAULT CALLBACKS         =
===================================*/

public void SQL_CheckCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_CheckCallback): %s", error);
		return;
	}
}

public void SQL_CheckCallback2(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_CheckCallback2): %s", error);
		return;
	}

	db_viewMapProRankCount();
	db_GetMapRecord_Pro();
}

public void SQL_CheckCallback3(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_CheckCallback3): %s", error);
		return;
	}

	char steamid[128];

	ResetPack(data);
	int client = ReadPackCell(data);
	ReadPackString(data, steamid, 128);
	delete data;

	RecalcPlayerRank(client, steamid);
	db_viewMapProRankCount();
	db_GetMapRecord_Pro();
}

public void SQL_CheckCallback4(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_CheckCallback4): %s", error);
		return;
	}
	char steamid[128];

	ResetPack(data);
	int client = ReadPackCell(data);
	ReadPackString(data, steamid, 128);
	delete data;

	RecalcPlayerRank(client, steamid);
}

/*==================================
=          PLAYER OPTIONS          =
==================================*/

public void db_updatePlayerOptions(int client)
{
	char szQuery[1024];
	// "UPDATE ck_playeroptions2 SET timer = %i, hide = %i, sounds = %i, chat = %i, viewmodel = %i, autobhop = %i, checkpoints = %i, centrehud = %i, module1c = %i, module2c = %i, module3c = %i,
	// module4c = %i, module5c = %i, module6c = %i, sidehud = %i, module1s = %i, module2s = %i, module3s = %i, module4s = %i, module5s = %i where steamid = '%s'";
	if (IsPlayerLoaded(client)) {
		Format(szQuery, 1024, sql_updatePlayerOptions,
								view_as<int>(g_bTimerEnabled[client]),
								view_as<int>(g_bHide[client]),
								view_as<int>(g_bEnableQuakeSounds[client]),
								view_as<int>(g_bHideChat[client]),
								view_as<int>(g_bViewModel[client]),
								view_as<int>(g_bAutoBhopClient[client]),
								view_as<int>(g_bCheckpointsEnabled[client]),
								g_SpeedGradient[client],
								g_SpeedMode[client],
								view_as<int>(g_players[client].speedDisplay),
								view_as<int>(g_bCentreHud[client]),
								g_iTeleSide[client],
								view_as<int>(g_players[client].hideWeapons),
								view_as<int>(g_players[client].outlines),
								g_iCentreHudModule[client][0],
								g_iCentreHudModule[client][1],
								g_iCentreHudModule[client][2],
								g_iCentreHudModule[client][3],
								g_iCentreHudModule[client][4],
								g_iCentreHudModule[client][5],
								view_as<int>(g_bSideHud[client]),
								g_iSideHudModule[client][0],
								g_iSideHudModule[client][1],
								g_iSideHudModule[client][2],
								g_iSideHudModule[client][3],
								g_iSideHudModule[client][4],
								g_szSteamID[client]);

		SQL_TQuery(g_hDb, SQL_CheckCallback, szQuery, client);
	}
}

/*===================================
=               MENUS               =
===================================*/

public void db_selectTopPlayers(int client, int style)
{
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);

	char szQuery[128];
	Format(szQuery, 128, "SELECT name, points, finishedmapspro, steamid FROM ck_playerrank WHERE style = %i ORDER BY points DESC LIMIT 100", style);
	SQL_TQuery(g_hDb, db_selectTop100PlayersCallback, szQuery, pack);
}

public void db_selectTop100PlayersCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectTop100PlayersCallback): %s", error);
		delete pack;
		return;
	}

	ResetPack(pack);
	int data = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	char szValue[128];
	char szName[64];
	char szRank[16];
	char szSteamID[32];
	char szPerc[16];
	int points;
	Menu menu = new Menu(TopPlayersMenuHandler1);
	char szTitle[256];
	if (style == STYLE_NORMAL)
		Format(szTitle, sizeof(szTitle), "Top 100 Players\n    Rank   Points       Maps            Player");
	else
		Format(szTitle, sizeof(szTitle), "Top 100 Players - %s\n    Rank   Points       Maps            Player", g_szStyleMenuPrint[style]);

	menu.SetTitle(szTitle);
	menu.Pagination = 5;

	if (SQL_HasResultSet(hndl))
	{
		int i = 1;
		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, szName, 64);
			if (i == 100)
				Format(szRank, 16, "[%i.]", i);
			else if (i < 10)
				Format(szRank, 16, "[0%i.]  ", i);
			else
				Format(szRank, 16, "[%i.]  ", i);

			points = SQL_FetchInt(hndl, 1);
			SQL_FetchInt(hndl, 2); // int pro
			SQL_FetchString(hndl, 3, szSteamID, 32);
			// TODO
			float fperc = 0.0;
			//fperc = (float(pro) / (float(g_pr_MapCount[0]))) * 100.0;

			if (fperc < 10.0)
				Format(szPerc, 16, "  %.1f%c  ", fperc, PERCENT);
			else if (fperc == 100.0)
				Format(szPerc, 16, "100.0%c", PERCENT);
			else if (fperc > 100.0) // player profile not refreshed after removing maps
				Format(szPerc, 16, "100.0%c", PERCENT);
			else
				Format(szPerc, 16, "%.1f%c  ", fperc, PERCENT);

			if (points < 10)
				Format(szValue, 128, "%s      %ip       %s     » %s", szRank, points, szPerc, szName);
			else if (points < 100)
				Format(szValue, 128, "%s     %ip       %s     » %s", szRank, points, szPerc, szName);
			else if (points < 1000)
				Format(szValue, 128, "%s   %ip       %s     » %s", szRank, points, szPerc, szName);
			else if (points < 10000)
				Format(szValue, 128, "%s %ip       %s     » %s", szRank, points, szPerc, szName);
			else if (points < 100000)
				Format(szValue, 128, "%s %ip     %s     » %s", szRank, points, szPerc, szName);
			else
				Format(szValue, 128, "%s %ip   %s     » %s", szRank, points, szPerc, szName);

			menu.AddItem(szSteamID, szValue, ITEMDRAW_DEFAULT);
			i++;
		}
		if (i == 1)
		{
			CPrintToChat(data, "%t", "NoPlayerTop", g_szChatPrefix);
		}
		else
		{
			menu.OptionFlags = MENUFLAG_BUTTON_EXIT;
			menu.Display(data, MENU_TIME_FOREVER);
		}
	}
	else
	{
		CPrintToChat(data, "%t", "NoPlayerTop", g_szChatPrefix);
	}
}

public int TopPlayersMenuHandler1(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, item, info, sizeof(info));
		g_MenuLevel[client] = 0;
		db_viewPlayerProfileBySteamid(client, g_ProfileStyleSelect[client], info);
	}
	if (action == MenuAction_Cancel)
	{
		ckTopMenu(client, 0);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MapMenuHandler1(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, item, info, sizeof(info));
		g_MenuLevel[client] = 1;
		db_viewPlayerProfileBySteamid(client, g_ProfileStyleSelect[client], info);
	}
	if (action == MenuAction_Cancel)
	{
		ckTopMenu(client, g_ProfileStyleSelect[client]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int FinishedMapsMenuHandler(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Cancel)
	{
		ProfileMenu2(client, g_ProfileStyleSelect[client], "", g_szSteamID[client]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void db_selectWrcpRecord(int client, int style, int stage)
{
	if (!IsValidClient(client) || IsFakeClient(client) || g_bUsingStageTeleport[client])
		return;

	if (stage > g_TotalStages) // Hack fix for multiple end zones
		stage = g_TotalStages;

	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);
	WritePackCell(pack, stage);

	char szQuery[255];
	if (style == STYLE_NORMAL)
		Format(szQuery, 255, "SELECT runtimepro FROM ck_wrcps WHERE steamid = '%s' AND mapname = '%s' AND stage = %i AND style = 0", g_szSteamID[client], g_szMapName, stage);
	else if (style != STYLE_NORMAL)
		Format(szQuery, 255, "SELECT runtimepro FROM ck_wrcps WHERE steamid = '%s' AND mapname = '%s' AND stage = %i AND style = %i", g_szSteamID[client], g_szMapName, stage, style);

	SQL_TQuery(g_hDb, sql_selectWrcpRecordCallback, szQuery, pack);
}

public void sql_selectWrcpRecordCallback(Handle owner, Handle hndl, const char[] error, DataPack packx)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectWrcpRecordCallback): %s", error);
		delete packx;
		return;
	}

	ResetPack(packx);
	int data = ReadPackCell(packx);
	int style = ReadPackCell(packx);
	int stage = ReadPackCell(packx);
	delete packx;

	if (!IsValidClient(data) || IsFakeClient(data))
		return;

	char szName[32];
	GetClientName(data, szName, 32);

	char szQuery[512];

	if (stage > g_TotalStages) // Hack fix for multiple end zones
		stage = g_TotalStages;

	char sz_srDiff[128];
	char szDiff[128];
	float time = g_fFinalWrcpTime[data];
	float f_srDiff;
	float fDiff;

	// PB
	fDiff = (g_fWrcpRecord[data][stage][style] - time);
	FormatTimeFloat(data, fDiff, 3, szDiff, 128);

	if (fDiff > 0)
		Format(szDiff, 128, "%cPB: %c-%s%c", WHITE, LIGHTGREEN, szDiff, WHITE);
	else
		Format(szDiff, 128, "%cPB: %c+%s%c", WHITE, RED, szDiff, WHITE);

	// SR
	if (style == STYLE_NORMAL)
		f_srDiff = (g_fStageRecord[stage] - time);
	else // styles
		f_srDiff = (g_fStyleStageRecord[style][stage] - time);

	FormatTimeFloat(data, f_srDiff, 3, sz_srDiff, 128);

	if (f_srDiff > 0)
		Format(sz_srDiff, 128, "%cWR: %c-%s%c", WHITE, LIGHTGREEN, sz_srDiff, WHITE);
	else
		Format(sz_srDiff, 128, "%cWR: %c+%s%c", WHITE, RED, sz_srDiff, WHITE);

	// Found old time from database
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		float stagetime = SQL_FetchFloat(hndl, 0);

		// If old time was slower than the new time, update record
		if ((g_fFinalWrcpTime[data] <= stagetime || stagetime <= 0.0))
		{
			db_updateWrcpRecord(data, style, stage);
		}
		else
		{ // fluffys come back
			char szSpecMessage[512];

			g_bStageSRVRecord[data][stage] = false;
			if (style == STYLE_NORMAL)
			{
				CPrintToChat(data, "%t", "SQL11", g_szChatPrefix, stage, g_szFinalWrcpTime[data], szDiff, sz_srDiff);

				Format(szSpecMessage, sizeof(szSpecMessage), "%t", "SQL12", g_szChatPrefix, szName, stage, g_szFinalWrcpTime[data], szDiff, sz_srDiff);
			}
			else if (style != STYLE_NORMAL) // styles
			{
				CPrintToChat(data, "%t", "SQL13", g_szChatPrefix, stage, g_szStyleRecordPrint[style], g_szFinalWrcpTime[data], sz_srDiff, g_StyleStageRank[style][data][stage], g_TotalStageStyleRecords[style][stage]);
				Format(szSpecMessage, sizeof(szSpecMessage), "%t", "SQL13", g_szChatPrefix, stage, g_szStyleRecordPrint[style], g_szFinalWrcpTime[data], sz_srDiff, g_StyleStageRank[style][data][stage], g_TotalStageStyleRecords[style][stage]);
			}
			CheckpointToSpec(data, szSpecMessage);

			if (g_players[data].repeatMode)
			{
				if (stage <= 1)
					Command_Restart(data, 1);
				else
					teleportClient(data, 0, stage, false);
			}
		}
	}
	else
	{ // No record found from database - Let's insert

		// Escape name for SQL injection protection
		char szName2[MAX_NAME_LENGTH * 2 + 1], szUName[MAX_NAME_LENGTH];
		GetClientName(data, szUName, MAX_NAME_LENGTH);
		SQL_EscapeString(g_hDb, szUName, szName2, MAX_NAME_LENGTH);

		// Move required information in datapack
		DataPack pack = CreateDataPack();
		WritePackFloat(pack, g_fFinalWrcpTime[data]);
		WritePackCell(pack, style);
		WritePackCell(pack, stage);
		WritePackCell(pack, 1);
		WritePackCell(pack, data);

		if (style == STYLE_NORMAL)
			Format(szQuery, 512, "INSERT INTO ck_wrcps (steamid, name, mapname, runtimepro, stage) VALUES ('%s', '%s', '%s', '%f', %i);", g_szSteamID[data], szName, g_szMapName, g_fFinalWrcpTime[data], stage);
		else if (style != STYLE_NORMAL)
			Format(szQuery, 512, "INSERT INTO ck_wrcps (steamid, name, mapname, runtimepro, stage, style) VALUES ('%s', '%s', '%s', '%f', %i, %i);", g_szSteamID[data], szName, g_szMapName, g_fFinalWrcpTime[data], stage, style);

		SQL_TQuery(g_hDb, SQL_UpdateWrcpRecordCallback, szQuery, pack);

		g_bStageSRVRecord[data][stage] = false;
	}
}

// If latest record was faster than old - Update time
public void db_updateWrcpRecord(int client, int style, int stage)
{
	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	char szUName[MAX_NAME_LENGTH];
	GetClientName(client, szUName, MAX_NAME_LENGTH);

	// Also updating name in database, escape string
	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	// int stage = g_CurrentStage[client];

	// Packing required information for later
	DataPack pack = CreateDataPack();
	WritePackFloat(pack, g_fFinalWrcpTime[client]);
	WritePackCell(pack, style);
	WritePackCell(pack, stage);
	WritePackCell(pack, 0);
	WritePackCell(pack, client);

	char szQuery[1024];
	// "UPDATE ck_playertimes SET name = '%s', runtimepro = '%f' WHERE steamid = '%s' AND mapname = '%s';";
	if (style == STYLE_NORMAL)
		Format(szQuery, 1024, "UPDATE ck_wrcps SET name = '%s', runtimepro = '%f' WHERE steamid = '%s' AND mapname = '%s' AND stage = %i AND style = 0;", szName, g_fFinalWrcpTime[client], g_szSteamID[client], g_szMapName, stage);
	if (style > 0)
		Format(szQuery, 1024, "UPDATE ck_wrcps SET name = '%s', runtimepro = '%f' WHERE steamid = '%s' AND mapname = '%s' AND stage = %i AND style = %i;", szName, g_fFinalWrcpTime[client], g_szSteamID[client], g_szMapName, stage, style);
	SQL_TQuery(g_hDb, SQL_UpdateWrcpRecordCallback, szQuery, pack);
}


public void SQL_UpdateWrcpRecordCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_UpdateWrcpRecordCallback): %s", error);
		delete data;
		return;
	}

	ResetPack(data);
	float stagetime = ReadPackFloat(data);
	int style = ReadPackCell(data);
	int stage = ReadPackCell(data);

	// Find out how many times are are faster than the players time
	char szQuery[512];
	if (style == STYLE_NORMAL)
		Format(szQuery, 512, "SELECT count(runtimepro) FROM ck_wrcps WHERE `mapname` = '%s' AND stage = %i AND style = 0 AND runtimepro < %f AND runtimepro > -1.0;", g_szMapName, stage, stagetime);
	else if (style != STYLE_NORMAL)
		Format(szQuery, 512, "SELECT count(runtimepro) FROM ck_wrcps WHERE mapname = '%s' AND runtimepro < %f AND stage = %i AND style = %i AND runtimepro > -1.0;", g_szMapName, stagetime, stage, style);

	SQL_TQuery(g_hDb, SQL_UpdateWrcpRecordCallback2, szQuery, data);
}

public void SQL_UpdateWrcpRecordCallback2(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_UpdateWrcpRecordCallback2): %s", error);
		delete data;
		return;
	}

	ResetPack(data);
	float time = ReadPackFloat(data);
	int style = ReadPackCell(data);
	int stage = ReadPackCell(data);
	bool bInsert = view_as<bool>(ReadPackCell(data));
	int client = ReadPackCell(data);
	delete data;

	if (!IsValidClient(client))
		return;

	if (bInsert) // fluffys FIXME
	{
		if (style == STYLE_NORMAL)
			g_TotalStageRecords[stage]++;
		else
			g_TotalStageStyleRecords[style][stage]++;
	}

	if (stage == 0)
		return;

	// Get players rank, 9999999 = error
	int stagerank = 9999999;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		stagerank = SQL_FetchInt(hndl, 0) + 1;

	if (stage > g_TotalStages) // Hack Fix for multiple end zone issue
		stage = g_TotalStages;

	if (style == STYLE_NORMAL)
		g_StageRank[client][stage] = stagerank;
	else
		g_StyleStageRank[style][client][stage] = stagerank;

	// Get client name
	char szName[MAX_NAME_LENGTH];
	GetClientName(client, szName, MAX_NAME_LENGTH);

	char sz_srDiff[128];

	// PB
	char szDiff[128];
	float fDiff;

	fDiff = (g_fWrcpRecord[client][stage][style] - time);
	FormatTimeFloat(client, fDiff, 3, szDiff, 128);

	if (g_fWrcpRecord[client][stage][style] != -1.0) // Existing stage time
	{
		if (fDiff > 0)
			Format(szDiff, 128, "%cPB: %c-%s%c", WHITE, LIGHTGREEN, szDiff, WHITE);
		else
			Format(szDiff, 128, "%cPB: %c+%s%c", WHITE, RED, szDiff, WHITE);
	}
	else
	{
		Format(szDiff, 128, "%cPB: %c%s%c", WHITE, LIMEGREEN, g_szFinalWrcpTime[client], WHITE);
	}

	// SR
	float f_srDiff;
	if (style == STYLE_NORMAL)
		f_srDiff = (g_fStageRecord[stage] - time);
	else if (style != STYLE_NORMAL)
		f_srDiff = (g_fStyleStageRecord[style][stage] - time);

	FormatTimeFloat(client, f_srDiff, 3, sz_srDiff, 128);

	if (f_srDiff > 0)
		Format(sz_srDiff, 128, "%cWR: %c-%s%c", WHITE, LIGHTGREEN, sz_srDiff, WHITE);
	else
		Format(sz_srDiff, 128, "%cWR: %c+%s%c", WHITE, RED, sz_srDiff, WHITE);

	// Check for SR
	bool newRecordHolder = false;
	if (style == STYLE_NORMAL)
	{
		// Compare against 1, since the player has completed the stage already
		if (g_TotalStageRecords[stage] > 1)
		{
			// If the server already has a record
			if (g_fFinalWrcpTime[client] < g_fStageRecord[stage] && g_fFinalWrcpTime[client] > 0.0)
			{
				// New fastest time in map
				g_bStageSRVRecord[client][stage] = true;
				if (g_fWrcpRecord[client][stage][0] != g_fStageRecord[stage])
					newRecordHolder = true;
				g_fStageRecord[stage] = g_fFinalTime[client];
				Format(g_szStageRecordPlayer[stage], MAX_NAME_LENGTH, "%s", szName);
				FormatTimeFloat(1, g_fStageRecord[stage], 3, g_szRecordStageTime[stage], 64);
				CPrintToChatAll("%t", "SQL15", g_szChatPrefix, szName, stage, g_szFinalWrcpTime[client], sz_srDiff, g_TotalStageRecords[stage]);
				g_bSavingWrcpReplay[client] = true;
				// Stage_SaveRecording(client, stage, g_szFinalWrcpTime[client]);
				PlayWRCPRecord(client);
			}
			else
			{
				CPrintToChat(client, "%t", "SQL16", g_szChatPrefix, stage, g_szFinalWrcpTime[client], szDiff, sz_srDiff, g_StageRank[client][stage], g_TotalStageRecords[stage]);
				char szSpecMessage[512];
				Format(szSpecMessage, sizeof(szSpecMessage), "%t", "SQL17", g_szChatPrefix, szName, stage, g_szFinalWrcpTime[client], szDiff, sz_srDiff, g_StageRank[client][stage], g_TotalStageRecords[stage]);
				CheckpointToSpec(client, szSpecMessage);
			}
		}
		else
		{
			// Has to be the new record, since it is the first completion
			newRecordHolder = true;
			g_bStageSRVRecord[client][stage] = true;
			g_fStageRecord[stage] = g_fFinalTime[client];
			Format(g_szStageRecordPlayer[stage], MAX_NAME_LENGTH, "%s", szName);
			FormatTimeFloat(1, g_fStageRecord[stage], 3, g_szRecordStageTime[stage], 64);
			CPrintToChatAll("%t", "SQL18", g_szChatPrefix, szName, stage, g_szFinalWrcpTime[client]);
			g_bSavingWrcpReplay[client] = true;
			// Stage_SaveRecording(client, stage, g_szFinalWrcpTime[client]);
			PlayWRCPRecord(client);
		}
	}
	else if (style != STYLE_NORMAL) // styles
	{
		// Compare against 1, since the player has completed the stage already
		if (g_TotalStageStyleRecords[style][stage] > 1)
		{
			// If the server already has a record
			if (g_fFinalWrcpTime[client] < g_fStyleStageRecord[style][stage] && g_fFinalWrcpTime[client] > 0.0)
			{
				// New fastest time in map
				g_bStageSRVRecord[client][stage] = true;
				if (g_fWrcpRecord[client][stage][style] != g_fStyleStageRecord[style][stage])
					newRecordHolder = true;

				g_fStyleStageRecord[style][stage] = g_fFinalTime[client];
				Format(g_szStyleStageRecordPlayer[style][stage], MAX_NAME_LENGTH, "%s", szName);
				FormatTimeFloat(1, g_fStyleStageRecord[style][stage], 3, g_szStyleRecordStageTime[style][stage], 64);

				CPrintToChatAll("%t", "SQL19", g_szChatPrefix, szName, g_szStyleRecordPrint[style], stage, g_szFinalWrcpTime[client], sz_srDiff, g_StyleStageRank[style][client][stage], g_TotalStageStyleRecords[style][stage]);
				PlayWRCPRecord(client);
			}
			else
			{
				CPrintToChat(client, "%t", "SQL20", g_szChatPrefix, stage, g_szStyleRecordPrint[style], g_szFinalWrcpTime[client], sz_srDiff, g_StyleStageRank[style][client][stage], g_TotalStageStyleRecords[style][stage]);

				char szSpecMessage[512];
				Format(szSpecMessage, sizeof(szSpecMessage), "%t", "SQL21", g_szChatPrefix, stage, g_szStyleRecordPrint[style], g_szFinalWrcpTime[client], sz_srDiff, g_StyleStageRank[style][client][stage], g_TotalStageStyleRecords[style][stage]);
				CheckpointToSpec(client, szSpecMessage);
			}
		}
		else
		{
			// Has to be the new record, since it is the first completion
			g_bStageSRVRecord[client][stage] = true;
			newRecordHolder = true;
			g_fStyleStageRecord[style][stage] = g_fFinalTime[client];
			Format(g_szStyleStageRecordPlayer[style][stage], MAX_NAME_LENGTH, "%s", szName);
			FormatTimeFloat(1, g_fStyleStageRecord[style][stage], 3, g_szStyleRecordStageTime[style][stage], 64);

			CPrintToChatAll("%t", "SQL22", g_szChatPrefix, szName, g_szStyleRecordPrint[style], stage, g_szFinalWrcpTime[client]);
			PlayWRCPRecord(client);
		}
	}

	// Check if new record and if someone else had the old record, if so give them points
	if (g_bStageSRVRecord[client][stage])
	{
		int points = GetConVarInt(g_hWrcpPoints);
		if (style == STYLE_NORMAL)
		{
			if (newRecordHolder)
			{
				if (points > 0)
				{
					g_pr_oldpoints[client][0] = g_pr_points[client][0];
					g_pr_points[client][0] += points;
					int diff = g_pr_points[client][0] - g_pr_oldpoints[client][0];
					CPrintToChat(client, "%t", "EarnedPoints", g_szChatPrefix, szName, diff, g_pr_points[client][0]);
				}
			}
		}
		else
		{
			if (newRecordHolder)
			{
				if (points > 0)
				{
					g_pr_oldpoints[client][style] = g_pr_points[client][style];
					g_pr_points[client][style] += points;
					int diff = g_pr_points[client][style] - g_pr_oldpoints[client][style];
					CPrintToChat(client, "%t", "EarnedPoints2", g_szChatPrefix, szName, diff, g_szStyleRecordPrint[style], g_pr_points[client][style]);
				}
			}
		}
	}

	g_fWrcpRecord[client][stage][style] = time;

	db_viewStageRecords();

	if (g_players[data].repeatMode)
	{
		if (stage <= 1)
			Command_Restart(client, 1);
		else
			teleportClient(client, 0, stage, false);
	}

}

public void sql_viewWrcpMapRecordCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_viewWrcpMapRecordCallback): %s ", error);
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		if (SQL_IsFieldNull(hndl, 1))
		{
			CPrintToChat(client, "%t", "SQL24", g_szChatPrefix);
			return;
		}

		char szName[MAX_NAME_LENGTH];
		float runtimepro;
		char szRuntimepro[64];

		SQL_FetchString(hndl, 0, szName, 128);
		runtimepro = SQL_FetchFloat(hndl, 1);
		FormatTimeFloat(0, runtimepro, 3, szRuntimepro, 64);

		CPrintToChat(client, "%t", "SQL25", g_szChatPrefix, szName, szRuntimepro, g_szWrcpMapSelect[client], g_szMapName);
		return;
	}
	else
	{
		CPrintToChat(client, "%t", "SQL24", g_szChatPrefix);
	}
}

public void db_selectStageTopSurfers(int client, char info[32], char mapname[128])
{
	char szQuery[1024];
	Format(szQuery, 1024, "SELECT db2.steamid, db1.name, db2.runtimepro as overall, db1.steamid, db2.mapname FROM ck_wrcps as db2 INNER JOIN ck_playerrank as db1 on db2.steamid = db1.steamid WHERE db2.mapname = '%s' AND db2.runtimepro > -1.0 AND db2.stage = %i AND db1.style = 0 AND db2.style = 0 ORDER BY overall ASC LIMIT 50;", mapname, info);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	// WritePackCell(pack, stage);
	WritePackString(pack, info);
	WritePackString(pack, mapname);
	SQL_TQuery(g_hDb, sql_selectStageTopSurfersCallback, szQuery, pack);
}

public void sql_selectStageTopSurfersCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectStageTopSurfersCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char stage[32];
	ReadPackString(pack, stage, 32);
	char mapname[128];
	ReadPackString(pack, mapname, 128);
	delete pack;

	char szSteamID[32];
	char szName[64];
	float time;
	char szMap[128];
	char szValue[128];
	char lineBuf[256];
	Handle stringArray = CreateArray(100);
	Handle menu;
	menu = CreateMenu(StageTopMenuHandler);
	SetMenuPagination(menu, 5);
	bool bduplicat = false;
	char title[256];
	if (SQL_HasResultSet(hndl))
	{
		int i = 1;
		while (SQL_FetchRow(hndl))
		{
			bduplicat = false;
			SQL_FetchString(hndl, 0, szSteamID, 32);
			SQL_FetchString(hndl, 1, szName, 64);
			time = SQL_FetchFloat(hndl, 2);
			SQL_FetchString(hndl, 4, szMap, 128);
			if (i == 1 || (i > 1))
			{
				int stringArraySize = GetArraySize(stringArray);
				for (int x = 0; x < stringArraySize; x++)
				{
					GetArrayString(stringArray, x, lineBuf, sizeof(lineBuf));
					if (StrEqual(lineBuf, szName, false))
						bduplicat = true;
				}
				if (!bduplicat && i < 51)
				{
					char szTime[32];
					FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));
					if (time < 3600.0)
						Format(szTime, 32, "   %s", szTime);
					if (i == 100)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					if (i >= 10)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					else
						Format(szValue, 128, "[0%i.] %s |    » %s", i, szTime, szName);
					AddMenuItem(menu, szSteamID, szValue, ITEMDRAW_DEFAULT);
					PushArrayString(stringArray, szName);
					i++;
				}
			}
		}
		if (i == 1)
		{
			CPrintToChat(client, "%t", "SQL26", g_szChatPrefix, stage, mapname);
		}
	}
	else
	CPrintToChat(client, "%t", "SQL26", g_szChatPrefix, stage, mapname);

	Format(title, 256, "[Top 50 | Stage %i | %s] \n    Rank    Time               Player", stage, szMap);
	SetMenuTitle(menu, title);
	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	delete stringArray;
}

public int StageTopMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, item, info, sizeof(info));
		g_MenuLevel[client] = 3;
		db_viewPlayerProfileBySteamid(client, g_ProfileStyleSelect[client], info);
	}
	else if (action == MenuAction_Cancel)
	{
		db_viewStyleWrcpMap(client, g_szWrcpMapSelect[client], 0);
	}
	else if (action == MenuAction_End)
		delete menu;
}

// Styles for maps
public void db_selectStyleRecord(int client, int style)
{
	if (!IsValidClient(client))
	return;

	Handle stylepack = CreateDataPack();
	WritePackCell(stylepack, client);
	WritePackCell(stylepack, style);

	char szQuery[255];
	Format(szQuery, 255, "SELECT runtimepro FROM `ck_playertimes` WHERE `steamid` = '%s' AND `mapname` = '%s' AND `style` = %i AND `runtimepro` > -1.0", g_szSteamID[client], g_szMapName, style);
	SQL_TQuery(g_hDb, sql_selectStyleRecordCallback, szQuery, stylepack);
}

public void sql_selectStyleRecordCallback(Handle owner, Handle hndl, const char[] error, DataPack stylepack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectStyleRecordCallback): %s", error);
		return;
	}

	ResetPack(stylepack);
	int data = ReadPackCell(stylepack);
	int style = ReadPackCell(stylepack);
	delete stylepack;

	if (!IsValidClient(data))
	return;


	char szQuery[512];

	// Found old time from database
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		float time = SQL_FetchFloat(hndl, 0);

		// If old time was slower than the new time, update record
		if ((g_fFinalTime[data] <= time || time <= 0.0))
		{
			db_updateStyleRecord(data, style);
		}
	}
	else
	{ // No record found from database - Let's insert

	// Escape name for SQL injection protection
	char szName[MAX_NAME_LENGTH * 2 + 1], szUName[MAX_NAME_LENGTH];
	GetClientName(data, szUName, MAX_NAME_LENGTH);
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH);

	// Move required information in datapack
	DataPack pack = CreateDataPack();
	WritePackFloat(pack, g_fFinalTime[data]);
	WritePackCell(pack, data);
	WritePackCell(pack, style);

	g_StyleMapTimesCount[style]++;

	Format(szQuery, 512, "INSERT INTO ck_playertimes (steamid, mapname, name, runtimepro, startspeed, style) VALUES ('%s', '%s', '%s', '%f', %i, %i)", g_szSteamID[data], g_szMapName, szName, g_fFinalTime[data], g_iStartSpeed[data], style);
	SQL_TQuery(g_hDb, SQL_UpdateStyleRecordCallback, szQuery, pack);
}
}

// If latest record was faster than old - Update time
public void db_updateStyleRecord(int client, int style)
{
	char szUName[MAX_NAME_LENGTH];

	if (IsValidClient(client))
		GetClientName(client, szUName, MAX_NAME_LENGTH);
	else
		return;

	// Also updating name in database, escape string
	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);

	// Packing required information for later
	DataPack pack = CreateDataPack();
	WritePackFloat(pack, g_fFinalTime[client]);
	WritePackCell(pack, client);
	WritePackCell(pack, style);

	char szQuery[1024];
	// "UPDATE ck_playertimes SET name = '%s', runtimepro = '%f' WHERE steamid = '%s' AND mapname = '%s';";
	Format(szQuery, 1024, "UPDATE `ck_playertimes` SET `name` = '%s', runtimepro = '%f', startspeed = '%i' WHERE `steamid` = '%s' AND `mapname` = '%s' AND `style` = %i;", szName, g_fFinalTime[client], g_iStartSpeed[client], g_szSteamID[client], g_szMapName, style);
	SQL_TQuery(g_hDb, SQL_UpdateStyleRecordCallback, szQuery, pack);
}

public void SQL_UpdateStyleRecordCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_UpdateStyleRecordCallback): %s", error);
		return;
	}

	ResetPack(pack);
	float time = ReadPackFloat(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	Handle data = CreateDataPack();
	WritePackCell(data, client);
	WritePackCell(data, style);

	// Find out how many times are are faster than the players time
	char szQuery[512];
	Format(szQuery, 512, "SELECT count(runtimepro) FROM `ck_playertimes` WHERE `mapname` = '%s' AND `style` = %i AND `runtimepro` < %f;", g_szMapName, style, time);
	SQL_TQuery(g_hDb, SQL_UpdateStyleRecordCallback2, szQuery, data);
}

public void SQL_UpdateStyleRecordCallback2(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_UpdateStyleRecordProCallback2): %s", error);
		return;
	}
	// Get players rank, 9999999 = error
	int rank = 9999999;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		rank = (SQL_FetchInt(hndl, 0)+1);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;

	g_StyleMapRank[style][client] = rank;
	StyleFinishedMsgs(client, style);
}

public void db_GetStyleMapRecord_Pro(int style)
{
	g_fRecordStyleMapTime[style] = 9999999.0;
	char szQuery[512];
	Format(szQuery, 512, "SELECT runtimepro, name, steamid, startspeed FROM ck_playertimes WHERE mapname = '%s' AND style = %i AND runtimepro > -1.0 ORDER BY runtimepro ASC LIMIT 1", g_szMapName, style);
	SQL_TQuery(g_hDb, sql_selectStyleMapRecordCallback, szQuery, style);
}

public void sql_selectStyleMapRecordCallback(Handle owner, Handle hndl, const char[] error, int style)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectStyleMapRecordCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_fRecordStyleMapTime[style] = SQL_FetchFloat(hndl, 0);
		if (g_fRecordStyleMapTime[style] > -1.0 && !SQL_IsFieldNull(hndl, 0))
		{
			g_fRecordStyleMapTime[style] = SQL_FetchFloat(hndl, 0);
			FormatTimeFloat(0, g_fRecordStyleMapTime[style], 3, g_szRecordStyleMapTime[style], 64);
			SQL_FetchString(hndl, 1, g_szRecordStylePlayer[style], MAX_NAME_LENGTH);
			SQL_FetchString(hndl, 2, g_szRecordStyleMapSteamID[style], MAX_NAME_LENGTH);
			g_iRecordMapStartSpeed[style] = SQL_FetchInt(hndl, 3); // @IG start speed
		}
		else
		{
			Format(g_szRecordStyleMapTime[style], 64, "N/A");
			g_fRecordStyleMapTime[style] = 9999999.0;
			g_iRecordMapStartSpeed[style] = -1;
		}
	}
	else
	{
		Format(g_szRecordStyleMapTime[style], 64, "N/A");
		g_fRecordStyleMapTime[style] = 9999999.0;
		g_iRecordMapStartSpeed[style] = -1;
	}
	return;
}

public void db_viewStyleMapRankCount(int style)
{
	g_StyleMapTimesCount[style] = 0;
	char szQuery[512];
	Format(szQuery, 512, "SELECT name FROM ck_playertimes WHERE mapname = '%s' AND style = %i AND runtimepro  > -1.0;", g_szMapName, style);
	SQL_TQuery(g_hDb, sql_selectStylePlayerCountCallback, szQuery, style);
}

public void sql_selectStylePlayerCountCallback(Handle owner, Handle hndl, const char[] error, int style)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectStylePlayerCountCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		g_StyleMapTimesCount[style] = SQL_GetRowCount(hndl);
	else
		g_StyleMapTimesCount[style] = 0;

	return;
}

public void db_selectStyleMapTopSurfers(int client, char mapname[128], int style)
{
	char szQuery[1024];
	Format(szQuery, 1024, "SELECT db2.steamid, db1.name, db2.runtimepro as overall, db1.steamid, db2.mapname FROM ck_playertimes as db2 INNER JOIN ck_playerrank as db1 on db2.steamid = db1.steamid WHERE db2.mapname LIKE '%c%s%c' AND db2.style = %i AND db2.runtimepro > -1.0 ORDER BY overall ASC LIMIT 100;", PERCENT, mapname, PERCENT, style);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, mapname);
	WritePackCell(pack, style);
	SQL_TQuery(g_hDb, sql_selectTopSurfersCallback, szQuery, pack);
}

// Styles for bonuses
public void db_insertBonusStyle(int client, char szSteamId[32], char szUName[MAX_NAME_LENGTH], float FinalTime, int startSpeed, int zoneGrp, int style)
{
	char szQuery[1024];
	char szName[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, zoneGrp);
	WritePackCell(pack, style);
	Format(szQuery, 1024, "INSERT INTO ck_bonus (steamid, name, mapname, runtime, startspeed, zonegroup, style) VALUES ('%s', '%s', '%s', '%f', '%i', '%i', '%i')", szSteamId, szName, g_szMapName, FinalTime, startSpeed, zoneGrp, style);
	SQL_TQuery(g_hDb, SQL_insertBonusStyleCallback, szQuery, pack);
}

public void SQL_insertBonusStyleCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_insertBonusStyleCallback): %s", error);
		return;
	}

	ResetPack(data);
	int client = ReadPackCell(data);
	int zgroup = ReadPackCell(data);
	int style = ReadPackCell(data);
	delete data;

	db_viewBonusTotalCount();
	RefreshAndPrintRecord(client, zgroup, style);
	/*Change to update profile timer, if giving multiplier count or extra points for bonuses
	CalculatePlayerRank(client);*/
}

public void db_updateBonusStyle(int client, char szSteamId[32], char szUName[MAX_NAME_LENGTH], float FinalTime, int startSpeed, int zoneGrp, int style)
{
	char szQuery[1024];
	char szName[MAX_NAME_LENGTH * 2 + 1];
	Handle datapack = CreateDataPack();
	WritePackCell(datapack, client);
	WritePackCell(datapack, zoneGrp);
	WritePackCell(datapack, style);
	SQL_EscapeString(g_hDb, szUName, szName, MAX_NAME_LENGTH * 2 + 1);
	Format(szQuery, 1024, "UPDATE ck_bonus SET runtime = '%f', startspeed = '%i', name = '%s' WHERE steamid = '%s' AND mapname = '%s' AND zonegroup = %i AND style = %i", FinalTime, startSpeed, szName, szSteamId, g_szMapName, zoneGrp, style);
	SQL_TQuery(g_hDb, SQL_updateBonusStyleCallback, szQuery, datapack);
}


public void SQL_updateBonusStyleCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_updateBonusCallback): %s", error);
		return;
	}

	ResetPack(data);
	int client = ReadPackCell(data);
	int zgroup = ReadPackCell(data);
	int style = ReadPackCell(data);
	delete data;

	db_viewBonusTotalCount();
	RefreshAndPrintRecord(client, zgroup, style);
}

public void db_currentBonusStyleRunRank(int client, int zGroup, int style)
{
	char szQuery[512];
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, zGroup);
	WritePackCell(pack, style);
	Format(szQuery, 512, "SELECT count(runtime)+1 FROM ck_bonus WHERE mapname = '%s' AND zonegroup = '%i' AND style = '%i' AND runtime < %f", g_szMapName, zGroup, style, g_fFinalTime[client]);
	SQL_TQuery(g_hDb, db_viewBonusStyleRunRank, szQuery, pack);
}

public void db_viewBonusStyleRunRank(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_viewBonusStyleRunRank): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int zGroup = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	delete pack;
	int rank;
	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		rank = SQL_FetchInt(hndl, 0);
	}

	PrintChatBonusStyle(client, zGroup, style, rank);
}

// Style WRCPS

public void db_viewStyleWrcpMap(int client, char mapname[128], int style)
{
	char szQuery[1024];
	Format(szQuery, 512, "SELECT `mapname`, COUNT(`zonetype`) AS stages FROM `ck_zones` WHERE `zonetype` = '3' AND `mapname` = (SELECT DISTINCT `mapname` FROM `ck_zones` WHERE `zonetype` = '3' AND `mapname` LIKE '%c%s%c' LIMIT 1) GROUP BY mapname LIMIT 1", PERCENT, g_szWrcpMapSelect[client], PERCENT);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);
	WritePackString(pack, mapname);
	SQL_TQuery(g_hDb, sql_viewStyleWrcpMapCallback, szQuery, pack);
}

public void sql_viewStyleWrcpMapCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_viewStyleWrcpMapCallback): %s ", error);
	}

	int totalstages;
	char mapnameresult[128];
	char stage[MAXPLAYERS + 1];
	char szStageString[MAXPLAYERS + 1];
	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	char mapname[128];
	ReadPackString(pack, mapname, 128);
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		totalstages = SQL_FetchInt(hndl, 1) + 1;
		SQL_FetchString(hndl, 0, mapnameresult, 128);
		if (totalstages == 0 || totalstages == 1)
		{
			CPrintToChat(client, "%t", "SQL23", g_szChatPrefix, mapname);
			return;
		}

		if (pack != INVALID_HANDLE)
		{
			g_StyleStageSelect[client] = style;
			g_szWrcpMapSelect[client] = mapnameresult;
			Menu menu;
			menu = CreateMenu(StageStyleSelectMenuHandler);

			SetMenuTitle(menu, "%s: select a stage [%s]\n------------------------------\n", mapnameresult, g_szStyleMenuPrint[style]);
			int stageCount = totalstages;
			for (int i = 1; i <= stageCount; i++)
			{
				stage[0] = i;
				Format(szStageString, sizeof(szStageString), "Stage %i", i);
				AddMenuItem(menu, stage[0], szStageString);
			}
			g_bSelectWrcp[client] = true;
			SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
			return;
		}
	}
}

public void db_selectStageStyleTopSurfers(int client, char info[32], char mapname[128], int style)
{
	char szQuery[1024];
	Format(szQuery, 1024, "SELECT db2.steamid, db1.name, db2.runtimepro as overall, db1.steamid, db2.mapname FROM ck_wrcps as db2 INNER JOIN ck_playerrank as db1 on db2.steamid = db1.steamid WHERE db2.mapname = '%s' AND db2.style = %i AND db2.stage = %i AND db2.runtimepro > -1.0 ORDER BY overall ASC LIMIT 50;", mapname, style, info);
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);
	// WritePackCell(pack, stage);
	WritePackString(pack, info);
	WritePackString(pack, mapname);
	SQL_TQuery(g_hDb, sql_selectStageStyleTopSurfersCallback, szQuery, pack);
}

public void sql_selectStageStyleTopSurfersCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectStageStyleTopSurfersCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	char stage[32];
	ReadPackString(pack, stage, 32);
	char mapname[128];
	ReadPackString(pack, mapname, 128);
	delete pack;

	char szSteamID[32];
	char szName[64];
	float time;
	char szMap[128];
	char szValue[128];
	char lineBuf[256];
	Handle stringArray = CreateArray(100);
	Handle menu;
	menu = CreateMenu(StageStyleTopMenuHandler);
	SetMenuPagination(menu, 5);
	bool bduplicat = false;
	char title[256];
	if (SQL_HasResultSet(hndl))
	{
		int i = 1;
		while (SQL_FetchRow(hndl))
		{
			bduplicat = false;
			SQL_FetchString(hndl, 0, szSteamID, 32);
			SQL_FetchString(hndl, 1, szName, 64);
			time = SQL_FetchFloat(hndl, 2);
			SQL_FetchString(hndl, 4, szMap, 128);
			if (i == 1 || (i > 1))
			{
				int stringArraySize = GetArraySize(stringArray);
				for (int x = 0; x < stringArraySize; x++)
				{
					GetArrayString(stringArray, x, lineBuf, sizeof(lineBuf));
					if (StrEqual(lineBuf, szName, false))
						bduplicat = true;
				}
				if (!bduplicat && i < 51)
				{
					char szTime[32];
					FormatTimeFloat(client, time, 3, szTime, sizeof(szTime));
					if (time < 3600.0)
						Format(szTime, 32, "   %s", szTime);
					if (i == 100)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					else if (i >= 10)
						Format(szValue, 128, "[%i.] %s |    » %s", i, szTime, szName);
					else
						Format(szValue, 128, "[0%i.] %s |    » %s", i, szTime, szName);
					AddMenuItem(menu, szSteamID, szValue, ITEMDRAW_DEFAULT);
					PushArrayString(stringArray, szName);
					i++;
				}
			}
		}
		if (i == 1)
		{
			CPrintToChat(client, "%t", "SQL26", g_szChatPrefix, stage, mapname);
		}
	}
	else
	CPrintToChat(client, "%t", "SQL26", g_szChatPrefix, stage, mapname);

	Format(title, 256, "[Top 50 %s | Stage %i | %s] \n    Rank    Time               Player", g_szStyleMenuPrint[style], stage, szMap);
	SetMenuTitle(menu, title);
	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	delete stringArray;
}

public int StageStyleTopMenuHandler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, item, info, sizeof(info));
		g_MenuLevel[client] = 3;
		db_viewPlayerProfileBySteamid(client, g_ProfileStyleSelect[client], info);
	}
	else if (action == MenuAction_Cancel)
	{
			db_viewStyleWrcpMap(client, g_szWrcpMapSelect[client], g_iWrcpMenuStyleSelect[client]);
	}
	else if (action == MenuAction_End)
		delete menu;
}

public void db_selectMapRank(int client, char szSteamId[32], char szMapName[128])
{
	char szQuery[1024];
	if (StrEqual(szMapName, "surf_me"))
			Format(szQuery, 1024, "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `steamid` = '%s' AND `mapname` = '%s' AND style = 0 LIMIT 1;", szSteamId, szMapName);
	else
		Format(szQuery, 1024, "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `steamid` = '%s' AND `mapname` LIKE '%c%s%c' AND style = 0 LIMIT 1;", szSteamId, PERCENT, szMapName, PERCENT);
	SQL_TQuery(g_hDb, db_selectMapRankCallback, szQuery, client);
}

public void db_selectMapRankCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectMapRankCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szSteamId[32];
		char playername[MAX_NAME_LENGTH];
		char mapname[128];
		float runtimepro;

		SQL_FetchString(hndl, 0, szSteamId, 32);
		SQL_FetchString(hndl, 1, playername, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 2, mapname, sizeof(mapname));
		runtimepro = SQL_FetchFloat(hndl, 3);

		FormatTimeFloat(client, runtimepro, 3, g_szRuntimepro[client], sizeof(g_szRuntimepro));

		DataPack pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, szSteamId);
		WritePackString(pack, playername);
		WritePackString(pack, mapname);

		char szQuery[1024];

		Format(szQuery, 1024, "SELECT count(name) FROM `ck_playertimes` WHERE `mapname` = '%s' AND style = 0;", mapname);
		SQL_TQuery(g_hDb, db_SelectTotalMapCompletesCallback, szQuery, pack);
	}
	else
	{
		CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
	}
}

public void db_SelectTotalMapCompletesCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_SelectTotalMapCompletesCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char playername[MAX_NAME_LENGTH];
	char mapname[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, playername, sizeof(playername));
	ReadPackString(pack, mapname, sizeof(mapname));

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_totalPlayerTimes[client] = SQL_FetchInt(hndl, 0);

		char szQuery[1024];

		Format(szQuery, 1024, "SELECT name,mapname FROM ck_playertimes WHERE runtimepro <= (SELECT runtimepro FROM ck_playertimes WHERE steamid = '%s' AND mapname = '%s' AND runtimepro > -1.0 AND style = 0) AND mapname = '%s' AND style = 0 AND runtimepro > -1.0 ORDER BY runtimepro;", szSteamId, mapname, mapname);
		SQL_TQuery(g_hDb, db_SelectPlayersMapRankCallback, szQuery, pack);
	}
	else
	{
		delete pack;
	}
}

public void db_SelectPlayersMapRankCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_SelectPlayersMapRankCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char playername[MAX_NAME_LENGTH];
	char mapname[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, playername, sizeof(playername));
	ReadPackString(pack, mapname, sizeof(mapname));
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		int rank;
		rank = SQL_GetRowCount(hndl);

		if (StrEqual(mapname, g_szMapName))
		{
			char szGroup[128];
			if (rank >= 11 && rank <= g_G1Top)
				Format(szGroup, 128, "[%cGroup 1%c]", DARKRED, WHITE);
			else if (rank >= g_G2Bot && rank <= g_G2Top)
				Format(szGroup, 128, "[%cGroup 2%c]", GREEN, WHITE);
			else if (rank >= g_G3Bot && rank <= g_G3Top)
				Format(szGroup, 128, "[%cGroup 3%c]", BLUE, WHITE);
			else if (rank >= g_G4Bot && rank <= g_G4Top)
				Format(szGroup, 128, "[%cGroup 4%c]", YELLOW, WHITE);
			else if (rank >= g_G5Bot && rank <= g_G5Top)
				Format(szGroup, 128, "[%cGroup 5%c]", GRAY, WHITE);
			else
				Format(szGroup, 128, "");

			if (rank >= 11 && rank <= g_G5Top)
				CPrintToChatAll("%t", "SQL29", g_szChatPrefix, playername, rank, g_totalPlayerTimes[client], szGroup, g_szRuntimepro[client], mapname);
			else
				CPrintToChatAll("%t", "SQL30", g_szChatPrefix, playername, rank, g_totalPlayerTimes[client], g_szRuntimepro[client], mapname);
		}
		else
		{
			CPrintToChatAll("%t", "SQL31", g_szChatPrefix, playername, rank, g_totalPlayerTimes[client], g_szRuntimepro[client], mapname);
		}
	}
	else
	{
		delete pack;
	}
}

// sm_mrank @x command
public void db_selectMapRankUnknown(int client, char szMapName[128], int rank)
{
	char szQuery[1024];
	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, rank);

	rank = rank - 1;
	Format(szQuery, 1024, "SELECT `steamid`, `name`, `mapname`, `runtimepro` FROM `ck_playertimes` WHERE `mapname` LIKE '%c%s%c' AND style = 0 ORDER BY `runtimepro` ASC LIMIT %i, 1;", PERCENT, szMapName, PERCENT, rank);
	SQL_TQuery(g_hDb, db_selectMapRankUnknownCallback, szQuery, pack);
}

public void db_selectMapRankUnknownCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectMapRankUnknownCallback): %s", error);
		return;
	}

	ResetPack(data);
	int client = ReadPackCell(data);
	int rank = ReadPackCell(data);
	delete data;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szSteamId[32];
		char playername[MAX_NAME_LENGTH];
		char mapname[128];
		float runtimepro;

		SQL_FetchString(hndl, 0, szSteamId, 32);
		SQL_FetchString(hndl, 1, playername, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 2, mapname, sizeof(mapname));
		runtimepro = SQL_FetchFloat(hndl, 3);

		FormatTimeFloat(client, runtimepro, 3, g_szRuntimepro[client], sizeof(g_szRuntimepro));

		DataPack pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, rank);
		WritePackString(pack, szSteamId);
		WritePackString(pack, playername);
		WritePackString(pack, mapname);

		char szQuery[1024];

		Format(szQuery, 1024, "SELECT count(name) FROM `ck_playertimes` WHERE `mapname` = '%s' AND style = 0;", mapname);
		SQL_TQuery(g_hDb, db_SelectTotalMapCompletesUnknownCallback, szQuery, pack);
	}
	else
	{
		CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
	}
}

public void db_SelectTotalMapCompletesUnknownCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_SelectTotalMapCompletesUnknownCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int rank = ReadPackCell(pack);
	char szSteamId[32];
	char playername[MAX_NAME_LENGTH];
	char mapname[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, playername, sizeof(playername));
	ReadPackString(pack, mapname, sizeof(mapname));
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		int totalplayers = SQL_FetchInt(hndl, 0);

		if (StrEqual(mapname, g_szMapName))
		{
			char szGroup[128];
			if (rank >= 11 && rank <= g_G1Top)
				Format(szGroup, 128, "[%cGroup 1%c]", DARKRED, WHITE);
			else if (rank >= g_G2Bot && rank <= g_G2Top)
				Format(szGroup, 128, "[%cGroup 2%c]", GREEN, WHITE);
			else if (rank >= g_G3Bot && rank <= g_G3Top)
				Format(szGroup, 128, "[%cGroup 3%c]", BLUE, WHITE);
			else if (rank >= g_G4Bot && rank <= g_G4Top)
				Format(szGroup, 128, "[%cGroup 4%c]", YELLOW, WHITE);
			else if (rank >= g_G5Bot && rank <= g_G5Top)
				Format(szGroup, 128, "[%cGroup 5%c]", GRAY, WHITE);
			else
				Format(szGroup, 128, "");

			if (rank >= 11 && rank <= g_G5Top)
				CPrintToChatAll("%t", "SQL33", g_szChatPrefix, playername, rank, totalplayers, szGroup, g_szRuntimepro[client], mapname);
			else
				CPrintToChatAll("%t", "SQL34", g_szChatPrefix, playername, rank, totalplayers, g_szRuntimepro[client], mapname);
		}
		else
		{
			CPrintToChatAll("%t", "SQL35", g_szChatPrefix, playername, rank, totalplayers, g_szRuntimepro[client], mapname);
		}
	}
	else
	{
		CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
	}
}

public void db_selectBonusRank(int client, char szSteamId[32], char szMapName[128], int bonus)
{
	char szQuery[1024];
	Format(szQuery, 1024, "SELECT `steamid`, `name`, `mapname`, `runtime`, zonegroup FROM `ck_bonus` WHERE `steamid` = '%s' AND `mapname` LIKE '%c%s%c' AND zonegroup = %i AND style = 0 LIMIT 1;", szSteamId, PERCENT, szMapName, PERCENT, bonus);
	SQL_TQuery(g_hDb, db_selectBonusRankCallback, szQuery, client);
}

public void db_selectBonusRankCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectBonusRankCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szSteamId[32];
		char playername[MAX_NAME_LENGTH];
		char mapname[128];
		float runtimepro;
		int bonus;

		SQL_FetchString(hndl, 0, szSteamId, 32);
		SQL_FetchString(hndl, 1, playername, MAX_NAME_LENGTH);
		SQL_FetchString(hndl, 2, mapname, sizeof(mapname));
		runtimepro = SQL_FetchFloat(hndl, 3);
		bonus = SQL_FetchInt(hndl, 4);

		FormatTimeFloat(client, runtimepro, 3, g_szRuntimepro[client], sizeof(g_szRuntimepro));

		DataPack pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackString(pack, szSteamId);
		WritePackString(pack, playername);
		WritePackString(pack, mapname);
		WritePackCell(pack, bonus);

		char szQuery[1024];

		Format(szQuery, 1024, "SELECT count(name) FROM `ck_bonus` WHERE `mapname` = '%s' AND zonegroup = %i AND style = 0 AND runtime > 0.0;", mapname, bonus);
		SQL_TQuery(g_hDb, db_SelectTotalBonusCompletesCallback, szQuery, pack);
	}
	else
	{
		CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
	}
}

public void db_SelectTotalBonusCompletesCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_SelectTotalBonusCompletesCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char playername[MAX_NAME_LENGTH];
	char mapname[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, playername, sizeof(playername));
	ReadPackString(pack, mapname, sizeof(mapname));
	int bonus = ReadPackCell(pack);

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_totalPlayerTimes[client] = SQL_FetchInt(hndl, 0);

		char szQuery[1024];

		Format(szQuery, 1024, "SELECT name,mapname FROM ck_bonus WHERE runtime <= (SELECT runtime FROM ck_bonus WHERE steamid = '%s' AND mapname = '%s' AND zonegroup = %i AND style = 0 AND runtime > -1.0) AND mapname = '%s' AND zonegroup = %i AND runtime > -1.0 ORDER BY runtime;", szSteamId, mapname, bonus, mapname, bonus);
		SQL_TQuery(g_hDb, db_SelectPlayersBonusRankCallback, szQuery, pack);
	}
	else
	{
		delete pack;
	}
}

public void db_SelectPlayersBonusRankCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_SelectPlayersBonusRankCallback): %s ", error);
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szSteamId[32];
	char playername[MAX_NAME_LENGTH];
	char mapname[128];
	ReadPackString(pack, szSteamId, 32);
	ReadPackString(pack, playername, sizeof(playername));
	ReadPackString(pack, mapname, sizeof(mapname));
	int bonus = ReadPackCell(pack);
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		int rank;
		rank = SQL_GetRowCount(hndl);

		CPrintToChatAll("%t", "SQL36", g_szChatPrefix, playername, rank, g_totalPlayerTimes[client], g_szRuntimepro[client], bonus, mapname);
	}
}

public void db_selectMapRecordTime(int client, char szMapName[128])
{
	char szQuery[1024];

	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackString(pack, szMapName);

	Format(szQuery, 1024, "SELECT db1.runtimepro, IFNULL(db1.mapname, 'NULL'),  db2.name, db1.steamid FROM ck_playertimes db1 INNER JOIN ck_playerrank db2 ON db1.steamid = db2.steamid WHERE mapname LIKE '%c%s%c' AND runtimepro > -1.0 AND db1.style = 0 AND db2.style = 0 ORDER BY runtimepro ASC LIMIT 1", PERCENT, szMapName, PERCENT);
	SQL_TQuery(g_hDb, db_selectMapRecordTimeCallback, szQuery, pack);
}

public void db_selectMapRecordTimeCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectMapRecordTimeCallback): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	char szMapNameArg[128];
	ReadPackString(pack, szMapNameArg, sizeof(szMapNameArg));
	delete pack;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		float runtimepro;
		char szMapName[128];
		char szRecord[64];
		char szName[64];
		runtimepro = SQL_FetchFloat(hndl, 0);
		SQL_FetchString(hndl, 1, szMapName, sizeof(szMapName));
		SQL_FetchString(hndl, 2, szName, sizeof(szName));

		if (StrEqual(szMapName, "NULL"))
		{
			CPrintToChat(client, "%t", "NoMapFound", g_szChatPrefix, szMapNameArg);
		}
		else
		{
			FormatTimeFloat(client, runtimepro, 3, szRecord, sizeof(szRecord));

			CPrintToChat(client, "%t", "SQL38", g_szChatPrefix, szName, szRecord, szMapName);
		}
	}
	else
	{
		CPrintToChat(client, "%t", "NoMapFound", g_szChatPrefix, szMapNameArg);
	}
}

public void db_selectPlayerRank(int client, int rank, char szSteamId[32])
{
	char szQuery[1024];

	if (StrContains(szSteamId, "none", false)!= -1) // Select Rank Number
	{
		g_rankArg[client] = rank;
		rank -= 1;
		Format(szQuery, 1024, "SELECT `name`, `points` FROM `ck_playerrank` ORDER BY `points` DESC LIMIT %i, 1;", rank);
	}
	else if (rank == 0) // Self Rank Cmd
	{
		g_rankArg[client] = -1;
		Format(szQuery, 1024, "SELECT `name`, `points` FROM `ck_playerrank` WHERE `steamid` = '%s';", szSteamId);
	}

	SQL_TQuery(g_hDb, db_selectPlayerRankCallback, szQuery, client);
}

public void db_selectPlayerRankCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectPlayerRankCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szName[32];
		int points;
		int rank;

		SQL_FetchString(hndl, 0, szName, sizeof(szName));
		points = SQL_FetchInt(hndl, 1);

		if (g_rankArg[client] == -1)
		{
			rank = g_PlayerRank[client][0];
			g_rankArg[client] = 1;
		}
		else
			rank = g_rankArg[client];

		CPrintToChatAll("%t", "SQL39", g_szChatPrefix, szName, rank, g_pr_RankedPlayers, points);
	}
	else
		CPrintToChat(client, "%t", "SQLTwo7", g_szChatPrefix);
}

public void db_selectPlayerRankUnknown(int client, char szName[128])
{
	char szQuery[1024];
	char szNameE[MAX_NAME_LENGTH * 2 + 1];
	SQL_EscapeString(g_hDb, szName, szNameE, MAX_NAME_LENGTH * 2 + 1);
	Format(szQuery, 1024, " \
		SELECT  \
			steamid, \
			name, \
			points, \
			(SELECT COUNT(*)+1 FROM ck_playerrank WHERE points > myrank.points) AS rank \
		FROM ck_playerrank myrank \
		WHERE name LIKE '%c%s%c' \
		ORDER BY `points` DESC LIMIT 1 \
	", PERCENT, szNameE, PERCENT);

	SQL_TQuery(g_hDb, db_selectPlayerRankUnknownCallback, szQuery, client);
}

public void db_selectPlayerRankUnknownCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (db_selectPlayerRankUnknownCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)) {
		char szSteamId[32];
		SQL_FetchString(hndl, 0, szSteamId, sizeof(szSteamId));
		char szName[128];
		SQL_FetchString(hndl, 1, szName, sizeof(szName));
		int points = SQL_FetchInt(hndl, 2);
		int rank = SQL_FetchInt(hndl, 3);
		CPrintToChatAll("%t", "SQL39", g_szChatPrefix, szName, rank, g_pr_RankedPlayers, points);
	} else {
		CPrintToChat(client, "%t", "SQLTwo7", g_szChatPrefix);
	}
}

public void db_selectMapImprovement(int client, char szMapName[128])
{
	char szQuery[1024];

	Format(szQuery, 1024, "SELECT mapname, (SELECT count(1) FROM ck_playertimes b WHERE a.mapname = b.mapname AND b.style = 0) as total, (SELECT tier FROM ck_maptier b WHERE a.mapname = b.mapname) as tier FROM ck_playertimes a where mapname LIKE '%c%s%c' AND style = 0 LIMIT 1;", PERCENT, szMapName, PERCENT);
	SQL_TQuery(g_hDb, db_selectMapImprovementCallback, szQuery, client);
}

public void db_selectMapImprovementCallback(Handle owner, Handle hndl, const char[] error, any client)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectMapImprovementCallback): %s", error);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		char szMapName[32];
		int totalplayers;
		int tier;

		SQL_FetchString(hndl, 0, szMapName, sizeof(szMapName));
		totalplayers = SQL_FetchInt(hndl, 1);
		tier = SQL_FetchInt(hndl, 2);

		g_szMiMapName[client] = szMapName;
		int type;
		type = g_MiType[client];

		// Map Completion Points
		int mapcompletion;
		if (tier == 1)
			mapcompletion = 25;
		else if (tier == 2)
			mapcompletion = 50;
		else if (tier == 3)
			mapcompletion = 100;
		else if (tier == 4)
			mapcompletion = 200;
		else if (tier == 5)
			mapcompletion = 400;
		else if (tier == 6)
			mapcompletion = 600;
		else // no tier
			mapcompletion = 13;

		// Calculate Group Ranks
		float wrpoints;
		// float points;
		float g1points;
		float g2points;
		float g3points;
		float g4points;
		float g5points;

		// Group 1
		float fG1top;
		int g1top;
		int g1bot = 11;
		fG1top = (float(totalplayers) * g_Group1Pc);
		fG1top += 11.0; // Rank 11 is always End of Group 1
		g1top = RoundToCeil(fG1top);

		int g1difference = (g1top - g1bot);
		if (g1difference < 4)
			g1top = (g1bot + 4);


		// Group 2
		float fG2top;
		int g2top;
		int g2bot;
		g2bot = g1top + 1;
		fG2top = (float(totalplayers) * g_Group2Pc);
		fG2top += 11.0;
		g2top = RoundToCeil(fG2top);

		int g2difference = (g2top - g2bot);
		if (g2difference < 4)
			g2top = (g2bot + 4);

		// Group 3
		float fG3top;
		int g3top;
		int g3bot;
		g3bot = g2top + 1;
		fG3top = (float(totalplayers) * g_Group3Pc);
		fG3top += 11.0;
		g3top = RoundToCeil(fG3top);

		int g3difference = (g3top - g3bot);
		if (g3difference < 4)
			g3top = (g3bot + 4);

		// Group 4
		float fG4top;
		int g4top;
		int g4bot;
		g4bot = g3top + 1;
		fG4top = (float(totalplayers) * g_Group4Pc);
		fG4top += 11.0;
		g4top = RoundToCeil(fG4top);

		int g4difference = (g4top - g4bot);
		if (g4difference < 4)
			g4top = (g4bot + 4);

		// Group 5
		float fG5top;
		int g5top;
		int g5bot;
		g5bot = g4top + 1;
		fG5top = (float(totalplayers) * g_Group5Pc);
		fG5top += 11.0;
		g5top = RoundToCeil(fG5top);

		int g5difference = (g5top - g5bot);
		if (g5difference < 4)
			g5top = (g5bot + 4);

		// WR Points
		if (tier == 1)
		{
			wrpoints = ((float(totalplayers) * 1.75) / 6);
			wrpoints += 58.5;
			if (wrpoints < 250.0)
				wrpoints = 250.0;
		}
		else if (tier == 2)
		{
			wrpoints = ((float(totalplayers) * 2.8) / 5);
			wrpoints += 82.15;
			if (wrpoints < 500.0)
				wrpoints = 500.0;
		}
		else if (tier == 3)
		{
			wrpoints = ((float(totalplayers) * 3.5) / 4);
			if (wrpoints < 750.0)
				wrpoints = 750.0;
			else
				wrpoints += 117;
		}
		else if (tier == 4)
		{
			wrpoints = ((float(totalplayers) * 5.74) / 4);
			if (wrpoints < 1000.0)
				wrpoints = 1000.0;
			else
				wrpoints += 164.25;
		}
		else if (tier == 5)
		{
			wrpoints = ((float(totalplayers) * 7) / 4);
			if (wrpoints < 1250.0)
				wrpoints = 1250.0;
			else
				wrpoints += 234;
		}
		else if (tier == 6)
		{
			wrpoints = ((float(totalplayers) * 14) / 4);
			if (wrpoints < 1500.0)
				wrpoints = 1500.0;
			else
				wrpoints += 328;
		}
		else // no tier set
			wrpoints = 25.0;

		// Round WR points up
		int iwrpoints;
		iwrpoints = RoundToCeil(wrpoints);

		// Calculate Top 10 Points
		int rank2;
		float frank2;
		int rank3;
		float frank3;
		int rank4;
		float frank4;
		int rank5;
		float frank5;
		int rank6;
		float frank6;
		int rank7;
		float frank7;
		int rank8;
		float frank8;
		int rank9;
		float frank9;
		int rank10;
		float frank10;

		frank2 = (0.80 * iwrpoints);
		rank2 += RoundToCeil(frank2);
		frank3 = (0.75 * iwrpoints);
		rank3 += RoundToCeil(frank3);
		frank4 = (0.70 * iwrpoints);
		rank4 += RoundToCeil(frank4);
		frank5 = (0.65 * iwrpoints);
		rank5 += RoundToCeil(frank5);
		frank6 = (0.60 * iwrpoints);
		rank6 += RoundToCeil(frank6);
		frank7 = (0.55 * iwrpoints);
		rank7 += RoundToCeil(frank7);
		frank8 = (0.50 * iwrpoints);
		rank8 += RoundToCeil(frank8);
		frank9 = (0.45 * iwrpoints);
		rank9 += RoundToCeil(frank9);
		frank10 = (0.40 * iwrpoints);
		rank10 += RoundToCeil(frank10);

		// Calculate Group Points
		g1points = (wrpoints * 0.25);
		g2points = (g1points / 1.5);
		g3points = (g2points / 1.5);
		g4points = (g3points / 1.5);
		g5points = (g4points / 1.5);

		// Draw Menu Map Improvement Menu
		if (type == 0)
		{
			Menu mi = CreateMenu(MapImprovementMenuHandler);
			SetMenuTitle(mi, "[Point Reward: %s]\n------------------------------\nTier: %i\n \n[Completion Points]\n \nMap Finish Points: %i\n \n[Map Improvement Groups]\n \n[Group 1] Ranks 11-%i ~ %i Pts\n[Group 2] Ranks %i-%i ~ %i Pts\n[Group 3] Ranks %i-%i ~ %i Pts\n[Group 4] Ranks %i-%i ~ %i Pts\n[Group 5] Ranks %i-%i ~ %i Pts\n \nWR Pts: %i\n \nTotal Completions: %i\n \n",szMapName, tier, mapcompletion, g1top, RoundFloat(g1points), g2bot, g2top, RoundFloat(g2points), g3bot, g3top, RoundFloat(g3points), g4bot, g4top, RoundFloat(g4points), g5bot, g5top, RoundFloat(g5points), iwrpoints, totalplayers);
			// AddMenuItem(mi, "", "", ITEMDRAW_SPACER);
			AddMenuItem(mi, szMapName, "Top 10 Points");
			SetMenuOptionFlags(mi, MENUFLAG_BUTTON_EXIT);
			DisplayMenu(mi, client, MENU_TIME_FOREVER);
		}
		else // Draw Top 10 Points Menu
		{
			Menu mi = CreateMenu(MapImprovementTop10MenuHandler);
			SetMenuTitle(mi, "[Point Reward: %s]\n------------------------------\nTier: %i\n \n[Completion Points]\n \nMap Finish Points: %i\n \n[Top 10 Points]\n \nRank 1: %i Pts\nRank 2: %i Pts\nRank 3: %i Pts\nRank 4: %i Pts\nRank 5: %i Pts\nRank 6: %i Pts\nRank 7: %i Pts\nRank 8: %i Pts\nRank 9: %i Pts\nRank 10: %i Pts\n \nTotal Completions: %i\n",szMapName, tier, mapcompletion, iwrpoints, rank2, rank3, rank4, rank5, rank6, rank7, rank8, rank9, rank10, totalplayers);
			AddMenuItem(mi, "", "", ITEMDRAW_SPACER);
			SetMenuOptionFlags(mi, MENUFLAG_BUTTON_EXIT);
			DisplayMenu(mi, client, MENU_TIME_FOREVER);
		}
	}
	else
	{
		CPrintToChat(client, "%t", "SQL28", g_szChatPrefix);
	}
}

public int MapImprovementMenuHandler(Menu mi, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char szMapName[128];
		GetMenuItem(mi, param2, szMapName, sizeof(szMapName));
		g_MiType[param1] = 1;
		db_selectMapImprovement(param1, szMapName);
	}
	if (action == MenuAction_End)
		delete mi;
}

public int MapImprovementTop10MenuHandler(Menu mi, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Cancel)
	{
		g_MiType[param1] = 0;
		db_selectMapImprovement(param1, g_szMiMapName[param1]);
	}
	if (action == MenuAction_End)
	{
		delete mi;
	}
}

public void db_selectMapNameEquals(int client, char[] szMapName, int style)
{
	char szQuery[256];
	Format(szQuery, sizeof(szQuery), "SELECT DISTINCT mapname FROM ck_zones WHERE mapname = '%s' LIMIT 1;", szMapName);

	DataPack pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, style);
	WritePackString(pack, szMapName);

	SQL_TQuery(g_hDb, sql_selectMapNameEqualsCallback, szQuery, pack);
}

public void sql_selectMapNameEqualsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectMapNameEqualsCallback): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	char szMapName[128];
	ReadPackString(pack, szMapName, sizeof(szMapName));

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		SQL_FetchString(hndl, 0, g_szMapNameFromDatabase[client], sizeof(g_szMapNameFromDatabase));
		if (style == STYLE_NORMAL)
		{
			g_ProfileStyleSelect[client] = 0;
			db_selectMapTopSurfers(client, g_szMapNameFromDatabase[client]);
		}
		else
		{
			g_ProfileStyleSelect[client] = style;
			db_selectStyleMapTopSurfers(client, g_szMapNameFromDatabase[client], style);
		}
	}
	else
	{
		Format(g_szMapNameFromDatabase[client], sizeof(g_szMapNameFromDatabase), "invalid");
		char szQuery[256];
		Format(szQuery, sizeof(szQuery), "SELECT DISTINCT mapname FROM ck_zones WHERE mapname LIKE '%c%s%c';", PERCENT, szMapName, PERCENT);
		SQL_TQuery(g_hDb, sql_selectMapNameLikeCallback, szQuery, pack);
	}
}

public void sql_selectMapNameLikeCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectMapNameLikeCallback): %s", error);
		return;
	}

	ResetPack(pack);
	int client = ReadPackCell(pack);
	int style = ReadPackCell(pack);
	char szMapName[128];
	ReadPackString(pack, szMapName, sizeof(szMapName));
	delete pack;

	if (SQL_HasResultSet(hndl))
	{
		int count = SQL_GetRowCount(hndl);
		if (count > 1)
		{
			char szMapName2[128];
			Menu menu = CreateMenu(ChooseMapMenuHandler);
			g_ProfileStyleSelect[client] = style;

			while (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, szMapName2, sizeof(szMapName2));
				AddMenuItem(menu, szMapName2, szMapName2);
			}

			SetMenuTitle(menu, "Choose a map:");
			SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
			DisplayMenu(menu, client, MENU_TIME_FOREVER);
		}
		else
		{
			if (SQL_FetchRow(hndl))
			{
				SQL_FetchString(hndl, 0, g_szMapNameFromDatabase[client], sizeof(g_szMapNameFromDatabase));
				if (style == STYLE_NORMAL)
				{
					g_ProfileStyleSelect[client] = 0;
					db_selectMapTopSurfers(client, g_szMapNameFromDatabase[client]);
				}
				else
				{
					g_ProfileStyleSelect[client] = style;
					db_selectStyleMapTopSurfers(client, g_szMapNameFromDatabase[client], style);
				}
			}
			else
				CPrintToChat(client, "%t", "NoMapFound", g_szChatPrefix, szMapName);
		}
	}
	else
		CPrintToChat(client, "%t", "NoMapFound", g_szChatPrefix, szMapName);
}

public int ChooseMapMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, g_szMapNameFromDatabase[param1], sizeof(g_szMapNameFromDatabase));
		int style = g_ProfileStyleSelect[param1];
		if (style == STYLE_NORMAL)
		{
			g_ProfileStyleSelect[param1] = 0;
			db_selectMapTopSurfers(param1, g_szMapNameFromDatabase[param1]);
		}
		else
		{
			db_selectStyleMapTopSurfers(param1, g_szMapNameFromDatabase[param1], style);
		}
	}
	else if (action == MenuAction_End)
		delete menu;
}