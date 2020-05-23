// 0

static bool g_printRecord[MAXPLAYERS][MAX_ZONEGROUPS][MAX_STYLES];

void db_refreshPlayerMapRecords(int client, any cb=0) {
	char szQuery[] = " \
		SELECT \
			style, \
			0 AS zonegroup, \
			0 AS isstage, \
			runtimepro, \
			(SELECT COUNT(*)+1 FROM ck_playertimes a WHERE runtimepro<mytime.runtimepro AND style=mytime.style AND mapname=mytime.mapname) AS rank, \
			startspeed \
		FROM ck_playertimes mytime \
			WHERE steamid = '__steamid__' AND mapname = '__mapname__' AND runtimepro > 0.0 \
		UNION ALL SELECT \
			style, \
			zonegroup, \
			0 AS isstage, \
			runtime, \
			(SELECT COUNT(*)+1 FROM ck_bonus a WHERE runtime<mytime.runtime AND style=mytime.style AND zonegroup=mytime.zonegroup AND mapname=mytime.mapname) AS rank, \
			startspeed \
		FROM ck_bonus mytime \
			WHERE steamid = '__steamid__' AND mapname = '__mapname__' AND runtime > 0.0 \
		UNION ALL SELECT \
			style, \
			stage, \
			1 AS isstage, \
			runtimepro, \
			(SELECT COUNT(*)+1 FROM ck_wrcps a WHERE runtimepro<mytime.runtimepro AND style=mytime.style AND stage=mytime.stage AND mapname=mytime.mapname) AS rank, \
			-1 AS startspeed \
		FROM ck_wrcps mytime \
			WHERE steamid = '__steamid__' AND mapname = '__mapname__' AND runtimepro > 0.0 \
	";
	SQL_PlayerQuery(szQuery, db_refreshPlayerMapRecordsCb, client, cb);
}
void db_refreshPlayerMapRecordsCb(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (db_refreshPlayerMapRecordsCb): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (!IsPlayerLoaded(client)) {
		for (int zgroup = 0; zgroup < MAX_ZONEGROUPS; zgroup++) {
			for (int style = 0; style < MAX_STYLES; style++) {
				g_printRecord[client][zgroup][style] = false;
			}
		}
	}

	g_fPersonalRecord[client] = 0.0;
	Client_SetScore(client, 0);
	Format(g_szPersonalRecord[client], 64, "NONE");
	g_MapRank[client] = 9999999;
	g_iPBMapStartSpeed[0][client] = -1; // @IG start speeds - set normal start speed
	for (int style = 1; style < MAX_STYLES; style++) {
		Format(g_szPersonalStyleRecord[style][client], 64, "NONE");
		g_fPersonalStyleRecord[style][client] = 0.0;
		g_StyleMapRank[style][client] = 9999999;
		g_iPBMapStartSpeed[style][client] = -1; // @IG start speeds
	}
	for (int zgroup = 0; zgroup < MAX_ZONEGROUPS; zgroup++) {
		g_fPersonalRecordBonus[zgroup][client] = 0.0;
		Format(g_szPersonalRecordBonus[zgroup][client], 64, "N/A");
		g_MapRankBonus[zgroup][client] = 9999999;
		for (int style = 1; style < MAX_STYLES; style++)
		{
			g_fStylePersonalRecordBonus[style][zgroup][client] = 0.0;
			Format(g_szStylePersonalRecordBonus[style][zgroup][client], 64, "N/A");
			g_StyleMapRankBonus[style][zgroup][client] = 9999999;
		}
	}
	for (int i = 0; i < CPLIMIT; i++) {
		for (int s = 0; s < MAX_STYLES; s++) {
			g_fWrcpRecord[client][i][s] = -1.0;
		}
	}

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			int style = SQL_FetchInt(hndl, 0);
			int zgroup = SQL_FetchInt(hndl, 1);
			bool isStage = view_as<bool>(SQL_FetchInt(hndl, 2));
			float time = SQL_FetchFloat(hndl, 3);
			int rank = SQL_FetchInt(hndl, 4);
			int startSpeed = SQL_FetchInt(hndl, 5); // @IG start speeds

			if (isStage)
			{
				g_fWrcpRecord[client][zgroup][style] = time;

				if (style == STYLE_NORMAL)
					g_StageRank[client][zgroup] = rank;
				else
					g_StyleStageRank[style][client][zgroup] = rank;

			}
			else
			{
				bool print = g_printRecord[client][zgroup][style];
				g_printRecord[client][zgroup][style] = false;
				if (zgroup == 0) // main map
				{
					if (style == STYLE_NORMAL)
					{
						g_fPersonalRecord[client] = time;
						FormatTimeFloat(client, time, 3, g_szPersonalRecord[client], 64);
						g_MapRank[client] = rank;
						Client_SetScore(client, rank);
					}
					else
					{
						g_fPersonalStyleRecord[style][client] = time;
						FormatTimeFloat(client, time, 3, g_szPersonalStyleRecord[style][client], 64);
						g_StyleMapRank[style][client] = rank;
					}

					g_iPBMapStartSpeed[style][client] = startSpeed; // @IG start speeds
				}
				else // bonuses
				{
					if (style == STYLE_NORMAL) // normal
					{
						g_fPersonalRecordBonus[zgroup][client] = time;
						FormatTimeFloat(client, time, 3, g_szPersonalRecordBonus[zgroup][client], 64);
						g_MapRankBonus[zgroup][client] = rank;

						if (print)
							PrintChatBonus(client, zgroup);
					}
					else // styles
					{
						g_fStylePersonalRecordBonus[style][zgroup][client] = time;
						FormatTimeFloat(client, time, 3, g_szStylePersonalRecordBonus[style][zgroup][client], 64);
						g_StyleMapRankBonus[style][zgroup][client] = rank;

						if (print)
							PrintChatBonusStyle(client, zgroup, style);
					}

					g_iPBBonusStartSpeed[style][zgroup][client] = startSpeed; // @IG start speeds (bonus)
				}
			}
		}
	}

	RunCallback(cb);
}
void RefreshAndPrintRecord(int client, int zgroup, int style) {
	g_printRecord[client][zgroup][style] = true;
	db_refreshPlayerMapRecords(client);
}

// 1

void db_refreshPlayerPoints(int client, any cb=0) {
	char szQuery[] = "SELECT steamid, name, points, finishedmapspro, country, lastseen, timealive, timespec, connections, readchangelog, style from ck_playerrank where steamid='__steamid__'";
	SQL_PlayerQuery(szQuery, db_refreshPlayerPointsCallback, client, cb);
}
void db_refreshPlayerPointsCallback(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (db_refreshPlayerPointsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	for (int i = 0; i < MAX_STYLES; i++) {
		g_pr_finishedmaps[client][i] = 0;
		g_pr_points[client][i] = 0;
	}
	g_bPrestigeCheck[client] = false;
	g_iPlayTimeAlive[client] = 0;
	g_iPlayTimeSpec[client] = 0;
	g_iTotalConnections[client] = 0;

	int normalPoints = 0;

	while (SQL_FetchRow(hndl)) {
		int style = SQL_FetchInt(hndl, 10);
		int points = SQL_FetchInt(hndl, 2);
		int finishedMaps = SQL_FetchInt(hndl, 3);

		g_pr_points[client][style] = points;
		g_pr_finishedmaps[client][style] = finishedMaps;
		if (style == STYLE_NORMAL) {
			normalPoints = points;
			g_iPlayTimeAlive[client] = SQL_FetchInt(hndl, 6);
			g_iPlayTimeSpec[client] = SQL_FetchInt(hndl, 7);
			g_iTotalConnections[client] = SQL_FetchInt(hndl, 8);

			if (IsValidClient(client))
			{
				CS_SetClientAssists(client, g_pr_finishedmaps[client][0]);
			}
		}
	}

	int minRank = g_hPrestigeRank.IntValue;
	if (!IsPlayerVip(client) && minRank == -1 && normalPoints == 0) {
		KickClient(client, "Visit our beginner server at 74.91.112.208");
	}

	g_iTotalConnections[client]++;
	char updateConnections[1024];
	Format(updateConnections, 1024, "UPDATE ck_playerrank SET connections = connections + 1 WHERE steamid = '%s';", g_szSteamID[client]);
	g_hDb.Query(SQL_CheckCallback, updateConnections);

	RunCallback(cb);
}

// 2

void db_GetPlayerRank(int client, any cb=0) {
	char szQuery[] = " \
		SELECT \
			style, \
			(SELECT COUNT(*)+1 FROM ck_playerrank WHERE points > myrank.points AND style=myrank.style) AS rank \
		FROM ck_playerrank myrank \
		WHERE steamid = '__steamid__' \
	";
	SQL_PlayerQuery(szQuery, sql_getPlayerRankCallback, client, cb);
}
void sql_getPlayerRankCallback(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (sql_getPlayerRankCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	int normalRank = 0;

	while (SQL_FetchRow(hndl)) {
		int style = SQL_FetchInt(hndl, 0);
		int rank = SQL_FetchInt(hndl, 1);

		g_PlayerRank[client][style] = rank;
		if (style == STYLE_NORMAL) {
			normalRank = rank;
		}

		// Sort players by rank in scoreboard
		if (style == STYLE_NORMAL) {
			if (g_pr_AllPlayers[style] < g_PlayerRank[client][style])
				CS_SetClientContributionScore(client, -99998);
			else
				CS_SetClientContributionScore(client, -rank);
		}
	}

	int minRank = g_hPrestigeRank.IntValue;
	if (!IsPlayerVip(client) && minRank > 0 && (normalRank == 0 || normalRank > minRank)) {
		KickClient(client, "You must be at least rank %i to join this server", minRank);
	}

	RunCallback(cb);
}

// 3

void db_viewPlayerOptions(int client, any cb=0) {

	char szQuery[] = " \
		SELECT \
			timer, hide, sounds, chat, viewmodel, autobhop, checkpoints, \
			gradient, speedmode, centrespeed, centrehud, teleside, hideweapons, outlines, \
			module1c, module2c, module3c, module4c, module5c, module6c, \
			sidehud, module1s, module2s, module3s, module4s, module5s \
		FROM ck_playeroptions2 WHERE steamid = '__steamid__'";
	SQL_PlayerQuery(szQuery, db_viewPlayerOptionsCallback, client, cb);
}
void db_viewPlayerOptionsCallback(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (db_viewPlayerOptionsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_bTimerEnabled[client] = view_as<bool>(SQL_FetchInt(hndl, 0));
		g_bHide[client] = view_as<bool>(SQL_FetchInt(hndl, 1));
		g_bEnableQuakeSounds[client] = view_as<bool>(SQL_FetchInt(hndl, 2));
		g_bHideChat[client] = view_as<bool>(SQL_FetchInt(hndl, 3));
		g_bViewModel[client] = view_as<bool>(SQL_FetchInt(hndl, 4));
		g_bAutoBhopClient[client] = view_as<bool>(SQL_FetchInt(hndl, 5));
		g_bCheckpointsEnabled[client] = view_as<bool>(SQL_FetchInt(hndl, 6));
		g_SpeedGradient[client] = SQL_FetchInt(hndl, 7);
		g_SpeedMode[client] = SQL_FetchInt(hndl, 8);
		g_players[client].speedDisplay = view_as<bool>(SQL_FetchInt(hndl, 9));
		g_bCentreHud[client] = view_as<bool>(SQL_FetchInt(hndl, 10));
		g_iTeleSide[client] = SQL_FetchInt(hndl, 11);
		g_players[client].hideWeapons = view_as<bool>(SQL_FetchInt(hndl, 12));
		g_players[client].outlines = view_as<bool>(SQL_FetchInt(hndl, 13));
		g_iCentreHudModule[client][0] = SQL_FetchInt(hndl, 14);
		g_iCentreHudModule[client][1] = SQL_FetchInt(hndl, 15);
		g_iCentreHudModule[client][2] = SQL_FetchInt(hndl, 16);
		g_iCentreHudModule[client][3] = SQL_FetchInt(hndl, 17);
		g_iCentreHudModule[client][4] = SQL_FetchInt(hndl, 18);
		g_iCentreHudModule[client][5] = SQL_FetchInt(hndl, 19);
		g_bSideHud[client] = view_as<bool>(SQL_FetchInt(hndl, 20));
		g_iSideHudModule[client][0] = SQL_FetchInt(hndl, 21);
		g_iSideHudModule[client][1] = SQL_FetchInt(hndl, 22);
		g_iSideHudModule[client][2] = SQL_FetchInt(hndl, 23);
		g_iSideHudModule[client][3] = SQL_FetchInt(hndl, 24);
		g_iSideHudModule[client][4] = SQL_FetchInt(hndl, 25);

		// Functionality for normal spec list
		if (g_iSideHudModule[client][0] == 5 && (g_iSideHudModule[client][1] == 0 && g_iSideHudModule[client][2] == 0 && g_iSideHudModule[client][3] == 0 && g_iSideHudModule[client][4] == 0))
			g_bSpecListOnly[client] = true;
		else
			g_bSpecListOnly[client] = false;

		g_bLoadedModules[client] = true;
	}
	else
	{
		char szQuery[512];
		if (!IsValidClient(client))
			return;

		char sql_insertPlayerOptions[] = "INSERT INTO ck_playeroptions2 (steamid) VALUES ('%s');";
		Format(szQuery, 1024, sql_insertPlayerOptions, g_szSteamID[client]);
		g_hDb.Query(SQL_CheckCallback, szQuery);

		g_bTimerEnabled[client] = true;
		g_bHide[client] = false;
		g_bEnableQuakeSounds[client] = true;
		g_bHideChat[client] = false;
		g_bViewModel[client] = true;
		g_bAutoBhopClient[client] = true;
		g_bCheckpointsEnabled[client] = true;
		g_SpeedGradient[client] = 3;
		g_SpeedMode[client] = 0;
		g_players[client].speedDisplay = false;
		g_bCentreHud[client] = true;
		g_iTeleSide[client] = 0;
		g_players[client].hideWeapons = false;
		g_players[client].outlines = true;
		g_iCentreHudModule[client][0] = 1;
		g_iCentreHudModule[client][1] = 2;
		g_iCentreHudModule[client][2] = 3;
		g_iCentreHudModule[client][3] = 4;
		g_iCentreHudModule[client][4] = 5;
		g_iCentreHudModule[client][5] = 6;
		g_bSideHud[client] = true;
		g_iSideHudModule[client][0] = 5;
		g_iSideHudModule[client][1] = 0;
		g_iSideHudModule[client][2] = 0;
		g_iSideHudModule[client][3] = 0;
		g_iSideHudModule[client][4] = 0;
		g_bSpecListOnly[client] = true;
	}

	RunCallback(cb);
}

// 4

void db_refreshCustomTitles(int client, any cb=0) {
	char szQuery[] = "SELECT `title`, `namecolour`, `textcolour` FROM ck_vipadmins WHERE steamid = '__steamid__'";
	SQL_PlayerQuery(szQuery, db_refreshCustomTitlesCb, client, cb);
}
void FormatTitle(int client, char[] raw, char[] out, int size) {
	char parts[32][32];
	char colored[32] = "";
	int numParts = ExplodeString(raw, "`", parts, sizeof(parts), sizeof(parts[]));
	if (numParts >= 1) {
		int num = StringToInt(parts[0]);
		if (num == 0) {
			if (StrEqual(parts[0], "vip")) {
				if (IsPlayerVip(client, true, false)) {
					colored = "{green}VIP";
				}
			} else if (StrEqual(parts[0], "admin")) {
				if (CheckCommandAccess(client, "", ADMFLAG_ROOT)) {
					colored = "{red}ADMIN";
				}
			} else if (StrEqual(parts[0], "mod")) {
				if (CheckCommandAccess(client, "", ADMFLAG_KICK)) {
					colored = "{yellow}MOD";
				}
			}
		} else if (num > 0 && num < numParts) {
			strcopy(colored, sizeof(colored), parts[num]);
		}
	}
	FormatTitleSlug(colored, out, size);
}
void FormatTitleSlug(const char[] raw, char[] out, int size) {
	strcopy(out, size, raw);
	char rawNoColor[32];
	strcopy(rawNoColor, sizeof(rawNoColor), raw);
	String_ToLower(rawNoColor, rawNoColor, sizeof(rawNoColor));

	if (StrEqual(rawNoColor, "rapper")) strcopy(out, size, "{yellow}RAPPER");
	if (StrEqual(rawNoColor, "beat")) strcopy(out, size, "{yellow}BEATBOXER");
	if (StrEqual(rawNoColor, "dj")) strcopy(out, size, "{yellow}DJ");
	ReplaceString(out, size, "{red}", "{lightred}", false);
	ReplaceString(out, size, "{limegreen}", "{lime}", false);
	ReplaceString(out, size, "{white}", "{default}", false);
}
void db_refreshCustomTitlesCb(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[surftimer] SQL Error (db_refreshCustomTitlesCb): %s ", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, g_szCustomTitleRaw[client], sizeof(g_szCustomTitleRaw[]));
		g_iCustomColours[client][0] = SQL_FetchInt(hndl, 1);
		g_iCustomColours[client][1] = SQL_FetchInt(hndl, 2);
	} else {
		g_szCustomTitleRaw[client] = "";
		g_iCustomColours[client][0] = 0;
		g_iCustomColours[client][1] = 0;
	}

	char formatted[32];
	FormatTitle(client, g_szCustomTitleRaw[client], formatted, sizeof(formatted));

	if (!StrEqual(formatted, "")) {
		strcopy(g_pr_chat_coloredrank[client], sizeof(g_pr_chat_coloredrank[]), formatted);
		strcopy(g_pr_rankname[client], sizeof(g_pr_rankname[]), formatted);
		parseColorsFromString(g_pr_rankname[client], sizeof(g_pr_rankname[]));
		g_bDbCustomTitleInUse[client] = true;
	} else {
		g_bDbCustomTitleInUse[client] = false;
	}

	if (g_bUpdatingColours[client])
		CustomTitleMenu(client);

	g_bUpdatingColours[client] = false;

	RunCallback(cb);
}

// 5

void db_refreshCheckpoints(int client, any cb=0) {
	char szQuery[] = " \
		SELECT \
			zonegroup, \
			cp1, cp2, cp3, cp4, cp5, cp6, cp7, cp8, cp9, cp10, \
			cp11, cp12, cp13, cp14, cp15, cp16, cp17, cp18, cp19, cp20, \
			cp21, cp22, cp23, cp24, cp25, cp26, cp27, cp28, cp29, cp30, \
			cp31, cp32, cp33, cp34, cp35 \
		FROM ck_checkpoints \
		WHERE mapname='__mapname__' AND steamid = '__steamid__' \
	";
	SQL_PlayerQuery(szQuery, db_refreshCheckpointsCb, client, cb);
}
void db_refreshCheckpointsCb(Handle hndl, const char[] error, int client, any cb) {
	if (hndl == null) {
		LogError("[Surftimer] SQL Error (db_refreshCheckpointsCb): %s", error);
		RunCallback(cb, true);
		return;
	}

	for (int i = 0; i < MAX_ZONEGROUPS; i++) {
		g_bCheckpointsFound[i][client] = false;
	}

	while (SQL_FetchRow(hndl)) {
		int zoneGrp = SQL_FetchInt(hndl, 0);
		g_bCheckpointsFound[zoneGrp][client] = true;
		int k = 1;
		for (int i = 0; i < 35; i++) {
			g_fCheckpointTimesRecord[zoneGrp][client][i] = SQL_FetchFloat(hndl, k);
			k++;
		}
	}

	RunCallback(cb);
}
