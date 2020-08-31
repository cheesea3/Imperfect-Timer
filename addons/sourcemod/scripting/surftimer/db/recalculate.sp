/* IG POINT REWEIGHT - Not using this right now, but leave it here in case we want to adjust things. */

// #define MAX_RECALC_COUNT 250

// char g_hRecalcSteamIds[MAX_RECALC_COUNT][32];
// char g_hRecalcNames[MAX_RECALC_COUNT][64];

// int g_iRecalcCount;
// int g_iTotalPoints[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iRecalcPoints[MAX_RECALC_COUNT][MAX_STYLES][7];

// int g_iFinishedBonusCount[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iWRs[MAX_RECALC_COUNT][MAX_STYLES][3]; // 0 = wr, 1 = wrb, 2 = wrcp
// int g_iCompletedStageCount[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iCompletedMapCount[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iTop10RecalcMaps[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iGroupRecalcMaps[MAX_RECALC_COUNT][MAX_STYLES];
// int g_iHighestTierRecalc[MAX_RECALC_COUNT][MAX_STYLES];

// int g_iCurrentRecalcIndex;

// // 0. Admins counting players points starts here
// public void RecalculatePlayerRankTable(int max, int style)
// {
// 	g_pr_RankingRecalc_InProgress = true;
// 	char szQuery[255];

// 	g_iRecalcCount = 0;
// 	g_iCurrentRecalcIndex = 0;

// 	Format(szQuery, sizeof(szQuery), "SELECT steamid, name from ck_playerrank where points > 1 AND style = %i ORDER BY points DESC LIMIT %i", style, max);
// 	g_hDb.Query(SQL_SelectRankedPlayersRecalcCallback, szQuery, style);
// }

// public void SQL_SelectRankedPlayersRecalcCallback(Handle owner, Handle hndl, const char[] error, any data)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_SelectRankedPlayersRecalcCallback): %s", error);
// 		return;
// 	}

// 	if (SQL_HasResultSet(hndl))
// 	{
// 		g_iRecalcCount = SQL_GetRowCount(hndl);
// 		PrintToConsole(g_pr_Recalc_AdminID, "Recalc: g_iRecalcCount=%i", g_iRecalcCount);

// 		int style = data;
// 		int i = 0;
// 		while (SQL_FetchRow(hndl))
// 		{
// 			g_iTotalPoints[i][style] = 0;

// 			SQL_FetchString(hndl, 0, g_hRecalcSteamIds[i], sizeof(g_hRecalcSteamIds[]));
// 			SQL_FetchString(hndl, 1, g_hRecalcNames[i], sizeof(g_hRecalcNames[]));

// 			i++;
// 		}

// 		RecalculatePlayerRank(g_iCurrentRecalcIndex, style);
// 	}
// 	else
// 	{
// 		g_pr_RankingRecalc_InProgress = false;
// 		PrintToConsole(g_pr_Recalc_AdminID, " \n>> No valid players found!");
// 	}
// }

// //
// //  1. Point recalculating starts here
// //
// public void RecalculatePlayerRank(int index, int style)
// {
// 	char szQuery[255];

// 	// Initialize point recalculation
// 	g_iTotalPoints[index][style] = 0;

// 	g_iRecalcPoints[index][style][POINTS_MAP]	  = 0; // Map Points
// 	g_iRecalcPoints[index][style][POINTS_BONUS]   = 0; // Bonus Points
// 	g_iRecalcPoints[index][style][POINTS_GROUP]   = 0; // Group Points
// 	g_iRecalcPoints[index][style][POINTS_MAPWR]   = 0; // Map WR Points
// 	g_iRecalcPoints[index][style][POINTS_BONUSWR] = 0; // Bonus WR Points
// 	g_iRecalcPoints[index][style][POINTS_TOPTEN]  = 0; // Top 10 Points
// 	g_iRecalcPoints[index][style][POINTS_WRCP]	  = 0; // WRCP Points
// 	// g_GroupPoints[index][0] // G1 Points
// 	// g_GroupPoints[index][1] // G2 Points
// 	// g_GroupPoints[index][2] // G3 Points
// 	// g_GroupPoints[index][3] // G4 Points
// 	// g_GroupPoints[index][4] // G5 Points
// 	g_iGroupRecalcMaps[index][style] = 0; // Group Maps
// 	g_iTop10RecalcMaps[index][style] = 0; // Top 10 Maps
// 	g_iWRs[index][style][0] = 0; // WRs
// 	g_iWRs[index][style][1] = 0; // WRBs
// 	g_iWRs[index][style][2] = 0; // WRCPs

// 	DataPack pack = CreateDataPack();
// 	WritePackCell(pack, index);
// 	WritePackCell(pack, style);

// 	Format(szQuery, sizeof(szQuery), "SELECT name FROM ck_playerrank WHERE steamid = '%s' AND style = '%i';", g_hRecalcSteamIds[index], style);
// 	g_hDb.Query(SQL_RecalculatePlayerRankCallback, szQuery, pack);
// }


// //
// // 2. See if player exists
// // Fetched values: name
// //
// public void SQL_RecalculatePlayerRankCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_RecalculatePlayerRankCallback): %s", error);
// 		delete pack;
// 		return;
// 	}

// 	ResetPack(pack);
// 	int index = ReadPackCell(pack);
// 	int style = ReadPackCell(pack);

// 	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
// 	{
// 		// Next up, calculate bonus points:
// 		char szQuery[512];
// 		Format(szQuery, sizeof(szQuery), "SELECT a.mapname, (SELECT count(1)+1 FROM ck_bonus b WHERE a.mapname=b.mapname AND a.runtime > b.runtime AND a.zonegroup = b.zonegroup AND b.style = %i) AS rank, (SELECT count(1) FROM ck_bonus b WHERE a.mapname = b.mapname AND a.zonegroup = b.zonegroup AND b.style = %i) as total FROM ck_bonus a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname WHERE steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", style, style, g_hRecalcSteamIds[index], style);
// 		g_hDb.Query(SQL_RecalculateBonusPointsCallback, szQuery, pack);
// 	}
// }

// //
// // 3. Recalculate points gained from bonuses
// // Fetched values
// // mapname, rank, total
// //
// public void SQL_RecalculateBonusPointsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_RecalculateBonusPointsCallback): %s", error);
// 		delete pack;
// 		return;
// 	}

// 	ResetPack(pack);
// 	int index = ReadPackCell(pack);
// 	int style = ReadPackCell(pack);

// 	char szMap[128];
// 	int totalPlayers;
// 	int rank;

// 	int finishedBonuses = 0;
// 	int wrbs = 0;

// 	if (SQL_HasResultSet(hndl))
// 	{
// 		while (SQL_FetchRow(hndl))
// 		{
// 			finishedBonuses++;
// 			rank = SQL_FetchInt(hndl, 1);
// 			totalPlayers = SQL_FetchInt(hndl, 2);
// 			SQL_FetchString(hndl, 0, szMap, sizeof(szMap));

// 			int points = 0;

// 			switch (rank)
// 			{
// 				case 1:
// 				{
// 					int p = totalPlayers >= 3 ? 58 : 50;
// 					g_iTotalPoints[index][style] += p;
// 					g_iRecalcPoints[index][style][POINTS_BONUSWR] += p;

// 					wrbs++;
// 				}

// 				case 2:  points = totalPlayers >= 3 ? 48 : 38;
// 				case 3:  points = totalPlayers >= 3 ? 42 : 36;
// 				case 4:  points = 32;
// 				case 5:  points = 30;
// 				case 6:  points = 28;
// 				case 7:  points = 26;
// 				case 8:  points = 24;
// 				case 9:  points = 22;
// 				case 10: points = 20;
// 				case 11: points = 18;
// 				case 12: points = 17;
// 				case 13: points = 16;
// 				case 14: points = 15;
// 				case 15: points = 14;
// 				case 16: points = 13;
// 				case 17: points = 12;
// 				case 18: points = 11;
// 				case 19: points = 10;
// 				case 20: points = 10;
// 				default: points = 5;
// 			}

// 			if (rank != 1)
// 			{
// 				g_iTotalPoints[index][style] += points;
// 				g_iRecalcPoints[index][style][POINTS_BONUS] += points;
// 			}
// 		}
// 	}

// 	g_iFinishedBonusCount[index][style] = finishedBonuses;
// 	g_iWRs[index][style][1] = wrbs;
// 	// Next up: Points from stages
// 	char szQuery[512];
// 	Format(szQuery, sizeof(szQuery), "SELECT a.mapname, a.stage, (select count(1)+1 from ck_wrcps b where a.mapname=b.mapname and a.runtimepro > b.runtimepro and a.style = b.style and a.stage = b.stage) AS `rank` FROM ck_wrcps a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname where steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", g_hRecalcSteamIds[index], style);
// 	g_hDb.Query(SQL_CountFinishedStagesCallback, szQuery, pack);
// }

// //
// // 4. Calculate points gained from stages
// // Fetched values
// // mapname, stage, rank, total
// //
// public void SQL_CountFinishedStagesCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_CountFinishedStagesCallback): %s", error);
// 		delete pack;
// 		return;
// 	}

// 	ResetPack(pack);
// 	int index = ReadPackCell(pack);
// 	int style = ReadPackCell(pack);

// 	char szMap[128];
// 	// int totalPlayers, rank;

// 	int finishedStages = 0;
// 	int rank;
// 	int wrcps = 0;

// 	if (SQL_HasResultSet(hndl))
// 	{
// 		while (SQL_FetchRow(hndl))
// 		{
// 			finishedStages++;
// 			// Total amount of players who have finished the bonus
// 			// totalPlayers = SQL_FetchInt(hndl, 2);
// 			SQL_FetchString(hndl, 0, szMap, 128);
// 			rank = SQL_FetchInt(hndl, 2);

// 			if (rank == 1)
// 			{
// 				wrcps++;
// 				int wrcpPoints = GetConVarInt(g_hWrcpPoints);
// 				if (wrcpPoints > 0)
// 				{
// 					g_iTotalPoints[index][style] += wrcpPoints;
// 					g_iRecalcPoints[index][style][POINTS_WRCP] += wrcpPoints;
// 				}
// 			}
// 		}
// 	}

// 	g_iCompletedStageCount[index][style] = finishedStages;
// 	g_iWRs[index][style][2] = wrcps;

// 	// Next up: Points from maps
// 	char szQuery[512];
// 	Format(szQuery, sizeof(szQuery), "SELECT a.mapname, (select count(1)+1 from ck_playertimes b where a.mapname=b.mapname and a.runtimepro > b.runtimepro AND b.style = %i) AS `rank`, (SELECT count(1) FROM ck_playertimes b WHERE a.mapname = b.mapname AND b.style = %i) as total, tier.tier FROM ck_playertimes a INNER JOIN ck_maptier tier ON a.mapname=tier.mapname where steamid = '%s' AND style = %i AND tier.ranked = 1 AND tier.tier > 0;", style, style, g_hRecalcSteamIds[index], style);
// 	g_hDb.Query(SQL_RecalculateMapPointsCallback, szQuery, pack);
// }

// // 5. Count the points gained from regular maps
// // Fetching:
// // mapname, rank, total, tier
// public void SQL_RecalculateMapPointsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_RecalculateMapPointsCallback): %s", error);
// 		delete pack;
// 		return;
// 	}

// 	ResetPack(pack);
// 	int index = ReadPackCell(pack);
// 	int style = ReadPackCell(pack);
// 	delete pack;

// 	bool isAngleSurf = (style == STYLE_HSW || style == STYLE_SW || style == STYLE_BW || style == STYLE_WONLY) ? true : false;

// 	char szMap[128];
// 	int finishedMaps = 0, totalPlayers, rank, tier, wrs;
// 	g_iHighestTierRecalc[index][style] = 0;

// 	if (SQL_HasResultSet(hndl))
// 	{
// 		while (SQL_FetchRow(hndl))
// 		{
// 			// Total amount of players who have finished the map
// 			totalPlayers = SQL_FetchInt(hndl, 2);
// 			// Rank in that map
// 			rank = SQL_FetchInt(hndl, 1);
// 			// Map name
// 			SQL_FetchString(hndl, 0, szMap, 128);
// 			// Map tier
// 			tier = SQL_FetchInt(hndl, 3);

// 			if (tier > g_iHighestTierRecalc[index][style])
// 				g_iHighestTierRecalc[index][style] = tier;

// 			finishedMaps++;
// 			float wrpoints;
// 			int iwrpoints;
// 			float points;
// 			// bool wr;
// 			// bool top10;
// 			float g1points;
// 			float g2points;
// 			float g3points;
// 			float g4points;
// 			float g5points;

// 			// Calculate Group Ranks
// 			// Group 1
// 			float fG1top;
// 			int g1top;
// 			int g1bot = 11;
// 			fG1top = (float(totalPlayers) * g_Group1Pc);
// 			fG1top += 11.0; // Rank 11 is always End of Group 1
// 			g1top = RoundToCeil(fG1top);

// 			int g1difference = (g1top - g1bot);
// 			if (g1difference < 4)
// 				g1top = (g1bot + 4);

// 			// Group 2
// 			float fG2top;
// 			int g2top;
// 			int g2bot;
// 			g2bot = g1top + 1;
// 			fG2top = (float(totalPlayers) * g_Group2Pc);
// 			fG2top += 11.0;
// 			g2top = RoundToCeil(fG2top);

// 			int g2difference = (g2top - g2bot);
// 			if (g2difference < 4)
// 				g2top = (g2bot + 4);

// 			// Group 3
// 			float fG3top;
// 			int g3top;
// 			int g3bot;
// 			g3bot = g2top + 1;
// 			fG3top = (float(totalPlayers) * g_Group3Pc);
// 			fG3top += 11.0;
// 			g3top = RoundToCeil(fG3top);

// 			int g3difference = (g3top - g3bot);
// 			if (g3difference < 4)
// 				g3top = (g3bot + 4);

// 			// Group 4
// 			float fG4top;
// 			int g4top;
// 			int g4bot;
// 			g4bot = g3top + 1;
// 			fG4top = (float(totalPlayers) * g_Group4Pc);
// 			fG4top += 11.0;
// 			g4top = RoundToCeil(fG4top);

// 			int g4difference = (g4top - g4bot);
// 			if (g4difference < 4)
// 				g4top = (g4bot + 4);

// 			// Group 5
// 			float fG5top;
// 			int g5top;
// 			int g5bot;
// 			g5bot = g4top + 1;
// 			fG5top = (float(totalPlayers) * g_Group5Pc);
// 			fG5top += 11.0;
// 			g5top = RoundToCeil(fG5top);

// 			int g5difference = (g5top - g5bot);
// 			if (g5difference < 4)
// 				g5top = (g5bot + 4);

// 			switch (tier)
// 			{
// 				case 1:
// 				{
// 					if (totalPlayers < 250 && !isAngleSurf)
// 					{
// 						wrpoints = float(totalPlayers); // reduce points when total completion count is low
// 					}
// 					else
// 					{
// 						wrpoints = ((float(totalPlayers) * 1.75) / 6);
// 						wrpoints += 58.5;

// 						if (wrpoints < 250.0)
// 							wrpoints = 250.0;
// 					}

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 15;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 15;
// 				}

// 				case 2:
// 				{
// 					if (totalPlayers < 250 && !isAngleSurf)
// 					{
// 						wrpoints = float(totalPlayers * 2); // reduce points when total completion count is low
// 					}
// 					else
// 					{
// 						wrpoints = ((float(totalPlayers) * 2.8) / 5);
// 						wrpoints += 82.15;

// 						if (wrpoints < 500.0)
// 							wrpoints = 500.0;
// 					}

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 30;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 30;
// 				}

// 				case 3:
// 				{
// 					if (totalPlayers < 250 && !isAngleSurf)
// 					{
// 						wrpoints = float(totalPlayers * 3); // reduce points when total completion count is low
// 					}
// 					else
// 					{
// 						wrpoints = ((float(totalPlayers) * 3.5) / 4);

// 						if (wrpoints < 750.0)
// 							wrpoints = 750.0;
// 						else
// 							wrpoints += 117.0;
// 					}

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 100;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 100;
// 				}

// 				case 4:
// 				{
// 					wrpoints = ((float(totalPlayers) * 5.74) / 4);

// 					if (wrpoints < 1000.0)
// 						wrpoints = 1000.0;
// 					else
// 						wrpoints += 164.25;

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 200;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 200;
// 				}

// 				case 5:
// 				{
// 					wrpoints = ((float(totalPlayers) * 7) / 4);

// 					if (wrpoints < 1250.0)
// 						wrpoints = 1250.0;
// 					else
// 						wrpoints += 234.0;

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 400;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 400;
// 				}

// 				case 6:
// 				{
// 					wrpoints = ((float(totalPlayers) * 14) / 4);
					
// 					if (wrpoints < 1500.0)
// 						wrpoints = 1500.0;
// 					else
// 						wrpoints += 328.0;

// 					// Map completion points
// 					g_iTotalPoints[index][style] += 600;
// 					g_iRecalcPoints[index][style][POINTS_MAP] += 600;
// 				}

// 				default: wrpoints = 5.0; // no tier set
// 			}

// 			// Round WR points up
// 			iwrpoints = RoundToCeil(wrpoints);

// 			// Top 10 Points - only rewarded if certain style, tier or completion count target met
// 			if (rank < 11 && (totalPlayers > 20 || tier > 3 || isAngleSurf))
// 			{
// 				g_iTop10RecalcMaps[index][style]++;

// 				switch (rank)
// 				{
// 					case 1:
// 					{
// 						g_iTotalPoints[index][style] += iwrpoints;
// 						g_iRecalcPoints[index][style][POINTS_MAPWR] += iwrpoints;
// 						wrs++;
// 					}

// 					case 2:  points = (0.80 * iwrpoints);
// 					case 3:  points = (0.75 * iwrpoints);
// 					case 4:  points = (0.70 * iwrpoints);
// 					case 5:  points = (0.65 * iwrpoints);
// 					case 6:  points = (0.60 * iwrpoints);
// 					case 7:  points = (0.55 * iwrpoints);
// 					case 8:  points = (0.50 * iwrpoints);
// 					case 9:  points = (0.45 * iwrpoints);
// 					case 10: points = (0.40 * iwrpoints);
// 				}

// 				if (rank != 1)
// 				{
// 					g_iTotalPoints[index][style] += RoundToCeil(points);
// 					g_iRecalcPoints[index][style][POINTS_TOPTEN] += RoundToCeil(points);
// 				}
// 			}
// 			else if (rank > 10 && rank <= g5top)
// 			{
// 				// Group 1-5 Points
// 				g_iGroupRecalcMaps[index][style]++;

// 				// Calculate Group Points
// 				g1points = (iwrpoints * 0.25);
// 				g2points = (g1points / 1.5);
// 				g3points = (g2points / 1.5);
// 				g4points = (g3points / 1.5);
// 				g5points = (g4points / 1.5);

// 				if (rank >= g1bot && rank <= g1top) // Group 1
// 				{
// 					g_iTotalPoints[index][style] += RoundFloat(g1points);
// 					g_iRecalcPoints[index][style][POINTS_GROUP] += RoundFloat(g1points);
// 				}
// 				else if (rank >= g2bot && rank <= g2top) // Group 2
// 				{
// 					g_iTotalPoints[index][style] += RoundFloat(g2points);
// 					g_iRecalcPoints[index][style][POINTS_GROUP] += RoundFloat(g2points);
// 				}
// 				else if (rank >= g3bot && rank <= g3top) // Group 3
// 				{
// 					g_iTotalPoints[index][style] += RoundFloat(g3points);
// 					g_iRecalcPoints[index][style][POINTS_GROUP] += RoundFloat(g3points);
// 				}
// 				else if (rank >= g4bot && rank <= g4top) // Group 4
// 				{
// 					g_iTotalPoints[index][style] += RoundFloat(g4points);
// 					g_iRecalcPoints[index][style][POINTS_GROUP] += RoundFloat(g4points);
// 				}
// 				else if (rank >= g5bot && rank <= g5top) // Group 5
// 				{
// 					g_iTotalPoints[index][style] += RoundFloat(g5points);
// 					g_iRecalcPoints[index][style][POINTS_GROUP] += RoundFloat(g5points);
// 				}
// 			}
// 		}

// 		// multiply points based on highest tier completed - helps reward skilled surfers
// 		float tierMultiplier = 1.0;

// 		switch (g_iHighestTierRecalc[index][style])
// 		{
// 			case 0: tierMultiplier = 1.0;
// 			case 1: tierMultiplier = 1.0;
// 			case 2: tierMultiplier = 1.04;
// 			case 3: tierMultiplier = 1.08;
// 			case 4: tierMultiplier = 1.16;
// 			case 5: tierMultiplier = 1.32;
// 			case 6: tierMultiplier = 1.48;

// 			default: tierMultiplier = 1.0;
// 		}

// //#if defined DEBUG_LOGGING
// //		char sName[MAX_NAME_LENGTH];
// //		GetClientName(index, sName, MAX_NAME_LENGTH);
// //		LogToFileEx(g_szLogFile, "[IG] Tier mutliplier for %s: %f (highest tier: %i)", sName, tierMultiplier, g_iHighestTierRecalc[index][style]);
// //#endif

// 		g_iRecalcPoints[index][style][POINTS_MAP]	  = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_MAP]) * tierMultiplier); // Map Points
// 		//g_iRecalcPoints[index][style][POINTS_BONUS]   = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_BONUS]) * tierMultiplier); // Bonus Points
// 		g_iRecalcPoints[index][style][POINTS_GROUP]   = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_GROUP]) * tierMultiplier); // Group Points
// 		g_iRecalcPoints[index][style][POINTS_MAPWR]   = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_MAPWR]) * tierMultiplier); // Map WR Points
// 		//g_iRecalcPoints[index][style][POINTS_BONUSWR] = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_BONUSWR]) * tierMultiplier); // Bonus WR Points
// 		g_iRecalcPoints[index][style][POINTS_TOPTEN]  = RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_TOPTEN]) * tierMultiplier); // Top 10 Points
// 		//g_iRecalcPoints[index][style][POINTS_WRCP]	= RoundToCeil(float(g_iRecalcPoints[index][style][POINTS_WRCP]) * tierMultiplier); // WRCP Points
// 	}

// 	// Finished maps amount is stored in memory
// 	g_iCompletedMapCount[index][style] = finishedMaps;

// 	// WRs
// 	g_iWRs[index][style][0] = wrs;

// 	// Done checking, update points
// 	DB_UpdateRecalculatedPoints(index, style);
// }

// // 6. Updating points to database
// public void DB_UpdateRecalculatedPoints(int index, int style)
// {
// 	DataPack pack = CreateDataPack();
// 	WritePackCell(pack, index);
// 	WritePackCell(pack, style);

// 	char szQuery[512];
// 	char szNameEscaped[MAX_NAME_LENGTH * 2 + 1];

// 	if (IsValidClient(g_pr_Recalc_AdminID))
// 		PrintToConsole(g_pr_Recalc_AdminID, "[%i] %s", index, g_hRecalcNames[index]);

// 	if (g_pr_RankingRecalc_InProgress)
// 	{
// 		SQL_EscapeString(g_hDb, g_hRecalcNames[index], szNameEscaped, sizeof(szNameEscaped));
// 		Format(szQuery, sizeof(szQuery), sql_updatePlayerRankPoints, szNameEscaped, 
// 																	g_iTotalPoints[index][style], 
// 																	g_iRecalcPoints[index][style][POINTS_MAPWR],
// 																	g_iRecalcPoints[index][style][POINTS_BONUSWR],
// 																	g_iRecalcPoints[index][style][POINTS_WRCP],
// 																	g_iRecalcPoints[index][style][POINTS_TOPTEN],
// 																	g_iRecalcPoints[index][style][POINTS_GROUP],
// 																	g_iRecalcPoints[index][style][POINTS_MAP],
// 																	g_iRecalcPoints[index][style][POINTS_BONUS],
// 																	g_iCompletedMapCount[index][style],
// 																	g_iFinishedBonusCount[index][style], 
// 																	g_iCompletedStageCount[index][style],
// 																	g_iWRs[index][style][0],
// 																	g_iWRs[index][style][1],
// 																	g_iWRs[index][style][2],
// 																	g_iTop10RecalcMaps[index][style],
// 																	g_iGroupRecalcMaps[index][style],
// 																	g_hRecalcSteamIds[index],
// 																	style);
// 		g_hDb.Query(SQL_UpdateRecalculatedPlayerPointsCallback, szQuery, pack);
// 	}
// }

// // 7. Finish recalculations for player
// public void SQL_UpdateRecalculatedPlayerPointsCallback(Handle owner, Handle hndl, const char[] error, DataPack pack)
// {
// 	if (hndl == null)
// 	{
// 		LogError("[Surftimer] SQL Error (SQL_UpdateRecalculatedPlayerPointsCallback): %s", error);
// 		delete pack;
// 		return;
// 	}

// 	ResetPack(pack);
// 	//int index = 
// 	ReadPackCell(pack);
// 	int style = ReadPackCell(pack);
// 	delete pack;

// 	if (g_iCurrentRecalcIndex < g_iRecalcCount - 1)
// 	{
// 		g_iCurrentRecalcIndex++;
// 		RecalculatePlayerRank(g_iCurrentRecalcIndex, style);
// 	}
// 	else
// 	{
// 		g_pr_RankingRecalc_InProgress = false;
// 	}
// 	//else
// 	//{
// 	//	g_pr_Calculating[index] = false;
// 	//	db_GetPlayerRankRecalc(index);
// 	//}
// }
