// 0
void db_viewMapSettings(any cb=0)
{
	char szQuery[2048];
	Format(szQuery, 2048, "SELECT `mapname`, `maxvelocity`, `announcerecord`, `gravityfix` FROM `ck_maptier` WHERE `mapname` = '%s'", g_szMapName);
	g_hDb.Query(sql_viewMapSettingsCallback, szQuery, cb, DBPrio_High);
}

void sql_viewMapSettingsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (sql_viewMapSettingsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_GetRowCount(hndl) > 0)
	{
		while (SQL_FetchRow(hndl))
		{
			g_fMaxVelocity = SQL_FetchFloat(hndl, 1);
			g_fAnnounceRecord = SQL_FetchFloat(hndl, 2);
			g_bGravityFix = view_as<bool>(SQL_FetchInt(hndl, 3));
		}
		SetConVarFloat(g_hMaxVelocity, g_fMaxVelocity, true, true);
		SetConVarFloat(g_hAnnounceRecord, g_fAnnounceRecord, true, true);
		SetConVarBool(g_hGravityFix, g_bGravityFix, true, true);
	}
	RunCallback(cb);
}

// 1
void db_selectMapZones(any cb=0)
{
	char szQuery[512];
	// SELECT zoneid, zonetype, zonetypeid, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, vis, team, zonegroup, zonename, hookname, targetname, onejumplimit, prespeed
	// FROM ck_zones WHERE mapname = '%s' ORDER BY zonetypeid ASC
	Format(szQuery, sizeof(szQuery), sql_selectMapZones, g_szMapName);
	g_hDb.Query(SQL_selectMapZonesCallback, szQuery, cb, DBPrio_High);
}

public void SQL_selectMapZonesCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_selectMapZonesCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	RemoveZones();

	if (SQL_HasResultSet(hndl))
	{
		g_mapZonesCount = 0;
		g_bhasStages = false;
		g_bhasBonus = false;
		g_mapZoneGroupCount = 0; // 1 = No Bonus, 2 = Bonus, >2 = Multiple bonuses
		g_iTotalCheckpoints = 0;

		for (int i = 0; i < MAX_ZONES; i++)
		{
			g_mapZones[i].Defaults();
		}

		for (int x = 0; x < MAX_ZONEGROUPS; x++)
		{
			g_mapZoneCountinGroup[x] = 0;
			for (int k = 0; k < MAX_ZONETYPES; k++)
			g_mapZonesTypeCount[x][k] = 0;
		}

		int zoneIdChecker[MAX_ZONES], zoneTypeIdChecker[MAX_ZONEGROUPS][MAX_ZONETYPES][MAX_ZONES], zoneTypeIdCheckerCount[MAX_ZONEGROUPS][MAX_ZONETYPES], zoneGroupChecker[MAX_ZONEGROUPS];

		// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		while (SQL_FetchRow(hndl))
		{
			g_mapZones[g_mapZonesCount].zoneId = SQL_FetchInt(hndl, 0);
			g_mapZones[g_mapZonesCount].zoneType = SQL_FetchInt(hndl, 1);
			g_mapZones[g_mapZonesCount].zoneTypeId = SQL_FetchInt(hndl, 2);
			g_mapZones[g_mapZonesCount].PointA[0] = SQL_FetchFloat(hndl, 3);
			g_mapZones[g_mapZonesCount].PointA[1] = SQL_FetchFloat(hndl, 4);
			g_mapZones[g_mapZonesCount].PointA[2] = SQL_FetchFloat(hndl, 5);
			g_mapZones[g_mapZonesCount].PointB[0] = SQL_FetchFloat(hndl, 6);
			g_mapZones[g_mapZonesCount].PointB[1] = SQL_FetchFloat(hndl, 7);
			g_mapZones[g_mapZonesCount].PointB[2] = SQL_FetchFloat(hndl, 8);
			g_mapZones[g_mapZonesCount].zoneGroup = SQL_FetchInt(hndl, 11);

			// Total amount of checkpoints
			if (g_mapZones[g_mapZonesCount].zoneType == 4)
				g_iTotalCheckpoints++;

			/**
			* Initialize error checking
			* 0 = zone not found
			* 1 = zone found
			*
			* IDs must be in order 0, 1, 2....
			* Duplicate zoneids not possible due to primary key
			*/
			zoneIdChecker[g_mapZones[g_mapZonesCount].zoneId]++;
			if (zoneGroupChecker[g_mapZones[g_mapZonesCount].zoneGroup] != 1)
			{
				// 1 = No Bonus, 2 = Bonus, >2 = Multiple bonuses
				g_mapZoneGroupCount++;
				zoneGroupChecker[g_mapZones[g_mapZonesCount].zoneGroup] = 1;
			}

			// You can have the same zonetype and zonetypeid values in different zonegroups
			zoneTypeIdChecker[g_mapZones[g_mapZonesCount].zoneGroup][g_mapZones[g_mapZonesCount].zoneType][g_mapZones[g_mapZonesCount].zoneTypeId]++;
			zoneTypeIdCheckerCount[g_mapZones[g_mapZonesCount].zoneGroup][g_mapZones[g_mapZonesCount].zoneType]++;

			SQL_FetchString(hndl, 12, g_mapZones[g_mapZonesCount].zoneName, 128);
			SQL_FetchString(hndl, 13, g_mapZones[g_mapZonesCount].hookName, 128);
			SQL_FetchString(hndl, 14, g_mapZones[g_mapZonesCount].targetName, 128);
			g_mapZones[g_mapZonesCount].oneJumpLimit = SQL_FetchInt(hndl, 15);
			g_mapZones[g_mapZonesCount].preSpeed = SQL_FetchFloat(hndl, 16);

			if (!g_mapZones[g_mapZonesCount].zoneName[0])
			{
				switch (g_mapZones[g_mapZonesCount].zoneType)
				{
					case 0: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Stop-%i", g_mapZones[g_mapZonesCount].zoneTypeId);

					case 1:
					{
						if (g_mapZones[g_mapZonesCount].zoneGroup > 0)
						{
							g_bhasBonus = true;
							Format(g_mapZones[g_mapZonesCount].zoneName, 128, "BonusStart-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
							Format(g_szZoneGroupName[g_mapZones[g_mapZonesCount].zoneGroup], 128, "Bonus %i", g_mapZones[g_mapZonesCount].zoneGroup);
						}
						else
							Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Start-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					}

					case 2:
					{
						if (g_mapZones[g_mapZonesCount].zoneGroup > 0)
							Format(g_mapZones[g_mapZonesCount].zoneName, 128, "BonusEnd-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
						else
							Format(g_mapZones[g_mapZonesCount].zoneName, 128, "End-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					}

					case 3:
					{
						g_bhasStages = true;
						Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Stage-%i", (g_mapZones[g_mapZonesCount].zoneTypeId + 2));
					}

					case 4: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Checkpoint-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 5: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Speed-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 6: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "TeleToStart-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 7: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Validator-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 8: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "Checker-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 9: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "AntiJump-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 10: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "AntiDuck-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
					case 11: Format(g_mapZones[g_mapZonesCount].zoneName, 128, "MaxSpeed-%i", g_mapZones[g_mapZonesCount].zoneTypeId);
				}
			}
			else
			{
				switch (g_mapZones[g_mapZonesCount].zoneType)
				{
					case 1:
					{
						if (g_mapZones[g_mapZonesCount].zoneGroup > 0)
							g_bhasBonus = true;
						Format(g_szZoneGroupName[g_mapZones[g_mapZonesCount].zoneGroup], 128, "%s", g_mapZones[g_mapZonesCount].zoneName);
					}

					case 3: g_bhasStages = true;
				}
			}

			/**
			*	Count zone center
			**/
			// Center
			float posA[3], posB[3], result[3];
			Array_Copy(g_mapZones[g_mapZonesCount].PointA, posA, 3);
			Array_Copy(g_mapZones[g_mapZonesCount].PointB, posB, 3);
			AddVectors(posA, posB, result);
			g_mapZones[g_mapZonesCount].CenterPoint[0] = result[0] / 2.0;
			g_mapZones[g_mapZonesCount].CenterPoint[1] = result[1] / 2.0;
			g_mapZones[g_mapZonesCount].CenterPoint[2] = result[2] / 2.0;

			for (int i = 0; i < 3; i++)
			{
				g_fZoneCorners[g_mapZonesCount][0][i] = g_mapZones[g_mapZonesCount].PointA[i];
				g_fZoneCorners[g_mapZonesCount][7][i] = g_mapZones[g_mapZonesCount].PointB[i];
			}

			// Zone counts:
			g_mapZonesTypeCount[g_mapZones[g_mapZonesCount].zoneGroup][g_mapZones[g_mapZonesCount].zoneType]++;
			g_mapZonesCount++;
		}
		// Count zone corners
		// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
		for (int x = 0; x < g_mapZonesCount; x++)
		{
			for(int i = 1; i < 7; i++)
			{
				for(int j = 0; j < 3; j++)
				{
					g_fZoneCorners[x][i][j] = g_fZoneCorners[x][((i >> (2-j)) & 1) * 7][j];
				}
			}
		}

		/**
		* Check for errors
		*
		* 1. ZoneId
		*/
		char szQuery[258];
		for (int i = 0; i < g_mapZonesCount; i++)
		{
			if (zoneIdChecker[i] == 0)
			{
				PrintToServer("[Surftimer] Found an error in zoneid : %i", i);
				Format(szQuery, 258, "UPDATE `ck_zones` SET zoneid = zoneid-1 WHERE mapname = '%s' AND zoneid > %i", g_szMapName, i);
				PrintToServer("Query: %s", szQuery);
				g_hDb.Query(sql_zoneFixCallback, szQuery);
				return;
			}
		}

		// 2nd ZoneGroup
		for (int i = 0; i < g_mapZoneGroupCount; i++)
		{
			if (zoneGroupChecker[i] == 0)
			{
				PrintToServer("[Surftimer] Found an error in zonegroup %i (ZoneGroups total: %i)", i, g_mapZoneGroupCount);
				Format(szQuery, 258, "UPDATE `ck_zones` SET `zonegroup` = zonegroup-1 WHERE `mapname` = '%s' AND `zonegroup` > %i", g_szMapName, i);
				g_hDb.Query(sql_zoneFixCallback, szQuery, zoneGroupChecker[i]);
				return;
			}
		}

		// 3rd ZoneTypeId
		for (int i = 0; i < g_mapZoneGroupCount; i++)
		{
			for (int k = 0; k < MAX_ZONETYPES; k++)
			{
				for (int x = 0; x < zoneTypeIdCheckerCount[i][k]; x++)
				{
					if (zoneTypeIdChecker[i][k][x] != 1 && (k == 3) || (k == 4))
					{
						if (zoneTypeIdChecker[i][k][x] == 0)
						{
							PrintToServer("[Surftimer] ZoneTypeID missing! [ZoneGroup: %i ZoneType: %i, ZonetypeId: %i]", i, k, x);
							Format(szQuery, 258, "UPDATE `ck_zones` SET zonetypeid = zonetypeid-1 WHERE mapname = '%s' AND zonetype = %i AND zonetypeid > %i AND zonegroup = %i;", g_szMapName, k, x, i);
							g_hDb.Query(sql_zoneFixCallback, szQuery);
							return;
						}
						else if (zoneTypeIdChecker[i][k][x] > 1)
						{
							char szerror[258];
							Format(szerror, 258, "[Surftimer] Duplicate Stage Zone ID's on %s [ZoneGroup: %i, ZoneType: 3, ZoneTypeId: %i]", g_szMapName, k, x);
							LogError(szerror);
						}
					}
				}
			}
		}

		RefreshZones();

		// Set mapzone count in group
		for (int x = 0; x < g_mapZoneGroupCount; x++)
			for (int k = 0; k < MAX_ZONETYPES; k++)
				if (g_mapZonesTypeCount[x][k] > 0)
					g_mapZoneCountinGroup[x]++;
	}

	RunCallback(cb);
}

// 2
void db_GetMapRecord_Pro(any cb=0)
{
	g_fRecordMapTime = 9999999.0;
	g_iRecordMapStartSpeed[0] = -1; // @IG start speeds - set normal start speed
	for (int i = 1; i < MAX_STYLES; i++)
	{
		g_fRecordStyleMapTime[i] = 9999999.0;
		g_iRecordMapStartSpeed[i] = -1; // @IG start speeds
	}

	char szQuery[512];
	// SELECT MIN(runtimepro), name, steamid, style FROM ck_playertimes WHERE mapname = '%s' AND runtimepro > -1.0 GROUP BY style
	Format(szQuery, 512, sql_selectMapRecord, g_szMapName);
	g_hDb.Query(sql_selectMapRecordCallback, szQuery, cb, DBPrio_High);
}

public void sql_selectMapRecordCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectMapRecordCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	int style;

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			style = SQL_FetchInt(hndl, 3);

			if (style == STYLE_NORMAL)
			{
				g_fRecordMapTime = SQL_FetchFloat(hndl, 0);

				if (g_fRecordMapTime > -1.0 && !SQL_IsFieldNull(hndl, 0))
				{
					g_fRecordMapTime = SQL_FetchFloat(hndl, 0);
					FormatTimeFloat(0, g_fRecordMapTime, 3, g_szRecordMapTime, 64);
					SQL_FetchString(hndl, 1, g_szRecordPlayer, MAX_NAME_LENGTH);
					SQL_FetchString(hndl, 2, g_szRecordMapSteamID, MAX_NAME_LENGTH);
				}
				else
				{
					Format(g_szRecordMapTime, 64, "N/A");
					g_fRecordMapTime = 9999999.0;
				}
			}
			else
			{
				g_fRecordStyleMapTime[style] = SQL_FetchFloat(hndl, 0);

				if (g_fRecordStyleMapTime[style] > -1.0 && !SQL_IsFieldNull(hndl, 0))
				{
					g_fRecordStyleMapTime[style] = SQL_FetchFloat(hndl, 0);
					FormatTimeFloat(0, g_fRecordStyleMapTime[style], 3, g_szRecordStyleMapTime[style], 64);
					SQL_FetchString(hndl, 1, g_szRecordStylePlayer[style], MAX_NAME_LENGTH);
					SQL_FetchString(hndl, 2, g_szRecordStyleMapSteamID[style], MAX_NAME_LENGTH);
				}
				else
				{
					Format(g_szRecordStyleMapTime[style], 64, "N/A");
					g_fRecordStyleMapTime[style] = 9999999.0;
				}
			}

			g_iRecordMapStartSpeed[style] = SQL_FetchInt(hndl, 4); // @IG start speeds
		}
	}
	else
	{
		Format(g_szRecordMapTime, 64, "N/A");
		g_fRecordMapTime = 9999999.0;

		for (int i = 1; i < MAX_STYLES; i++)
		{
			Format(g_szRecordStyleMapTime[i], 64, "N/A");
			g_fRecordStyleMapTime[i] = 9999999.0;
			g_iRecordMapStartSpeed[i] = -1; // @IG start speeds
		}
	}

	RunCallback(cb);
}

// 3
void db_viewMapProRankCount(any cb=0)
{
	g_MapTimesCount = 0;
	char szQuery[512];
	Format(szQuery, 512, sql_selectPlayerProCount, g_szMapName);
	g_hDb.Query(sql_selectPlayerProCountCallback, szQuery, cb, DBPrio_High);
}

void sql_selectPlayerProCountCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectPlayerProCountCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	int style;
	int count;
	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			style = SQL_FetchInt(hndl, 0);
			count = SQL_FetchInt(hndl, 1);
			if (style == STYLE_NORMAL)
				g_MapTimesCount = count;
			else
				g_StyleMapTimesCount[style] = count;
		}
	}
	else
	{
		g_MapTimesCount = 0;
		for (int i = 1; i < MAX_STYLES; i++)
			g_StyleMapTimesCount[style] = 0;
	}

	RunCallback(cb);
}

// 4
void db_viewFastestBonus(any cb=0)
{
	char szQuery[1024];
	// SELECT name, MIN(runtime), zonegroup, style FROM ck_bonus WHERE mapname = '%s' GROUP BY zonegroup, style;
	Format(szQuery, 1024, sql_selectFastestBonus, g_szMapName);
	g_hDb.Query(SQL_selectFastestBonusCallback, szQuery, cb, DBPrio_High);
}

public void SQL_selectFastestBonusCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_selectFastestBonusCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	for (int i = 0; i < MAX_ZONEGROUPS; i++)
	{
		Format(g_szBonusFastestTime[i], 64, "N/A");
		g_fBonusFastest[i] = 9999999.0;

		for (int s = 1; s < MAX_STYLES; s++)
		{
			Format(g_szStyleBonusFastestTime[s][i], 64, "N/A");
			g_fStyleBonusFastest[s][i] = 9999999.0;
			g_iRecordBonusStartSpeed[s][i] = -1; // @IG start speeds (bonus)
		}
	}

	if (SQL_HasResultSet(hndl))
	{
		int zonegroup;
		int style;
		while (SQL_FetchRow(hndl))
		{
			zonegroup = SQL_FetchInt(hndl, 2);
			style = SQL_FetchInt(hndl, 3);

			if (style == STYLE_NORMAL)
			{
				SQL_FetchString(hndl, 0, g_szBonusFastest[zonegroup], MAX_NAME_LENGTH);
				g_fBonusFastest[zonegroup] = SQL_FetchFloat(hndl, 1);
				FormatTimeFloat(1, g_fBonusFastest[zonegroup], 3, g_szBonusFastestTime[zonegroup], 64);
			}
			else
			{
				SQL_FetchString(hndl, 0, g_szStyleBonusFastest[style][zonegroup], MAX_NAME_LENGTH);
				g_fStyleBonusFastest[style][zonegroup] = SQL_FetchFloat(hndl, 1);
				FormatTimeFloat(1, g_fStyleBonusFastest[style][zonegroup], 3, g_szStyleBonusFastestTime[style][zonegroup], 64);
			}

			// style does matter, its all stored in the same array
			g_iRecordBonusStartSpeed[style][zonegroup] = SQL_FetchInt(hndl, 4); // @IG start speeds (bonus)
		}
	}

	for (int i = 0; i < MAX_ZONEGROUPS; i++)
	{
		if (g_fBonusFastest[i] == 0.0)
			g_fBonusFastest[i] = 9999999.0;

		for (int s = 1; s < MAX_STYLES; s++)
		{
			if (g_fStyleBonusFastest[s][i] == 0.0)
				g_fStyleBonusFastest[s][i] = 9999999.0;
		}
	}

	RunCallback(cb);
}

// 5
void db_viewBonusTotalCount(any cb=0)
{
	char szQuery[1024];
	// SELECT zonegroup, style, count(*) FROM ck_bonus WHERE mapname = '%s' GROUP BY zonegroup, style;
	Format(szQuery, 1024, sql_selectBonusCount, g_szMapName);
	g_hDb.Query(SQL_selectBonusTotalCountCallback, szQuery, cb, DBPrio_High);
}

void SQL_selectBonusTotalCountCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_selectBonusTotalCountCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	for (int i = 1; i < MAX_ZONEGROUPS; i++)
		g_iBonusCount[i] = 0;

	if (SQL_HasResultSet(hndl))
	{
		int zonegroup;
		int style;
		while (SQL_FetchRow(hndl))
		{
			zonegroup = SQL_FetchInt(hndl, 0);
			style = SQL_FetchInt(hndl, 1);

			if (style == STYLE_NORMAL)
				g_iBonusCount[zonegroup] = SQL_FetchInt(hndl, 2);
			else
				g_iStyleBonusCount[style][zonegroup] = SQL_FetchInt(hndl, 2);
		}
	}

	RunCallback(cb);
}

// 6
void db_selectMapTier(any cb=0)
{
	char szQuery[1024];
	Format(szQuery, 1024, sql_selectMapTier, g_szMapName);
	g_hDb.Query(SQL_selectMapTierCallback, szQuery, cb, DBPrio_High);
}

public void SQL_selectMapTierCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_selectMapTierCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	g_bRankedMap = false;
	g_bTierFound = false;
	g_iMapTier = 0;

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		int tier;

		// Format tier string
		tier = SQL_FetchInt(hndl, 0);
		g_bRankedMap = view_as<bool>(SQL_FetchInt(hndl, 1));
		if (0 < tier < 7)
		{
			g_bTierFound = true;
			g_iMapTier = tier;
			Format(g_sTierString, 512, "%c%s %c- ", BLUE, g_szMapName, WHITE);
			switch (tier)
			{
				case 1:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, GRAY, tier, WHITE);
				case 2:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, BLUEGREY, tier, WHITE);
				case 3:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, BLUE, tier, WHITE);
				case 4:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, DARKBLUE, tier, WHITE);
				case 5:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, RED, tier, WHITE);
				case 6:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, DARKRED, tier, WHITE);
				default:Format(g_sTierString, 512, "%s%cTier %i %c- ", g_sTierString, GRAY, tier, WHITE);
			}
			if (g_bhasStages)
				Format(g_sTierString, 512, "%s%c%i Stages", g_sTierString, LIGHTGREEN, (g_mapZonesTypeCount[0][3] + 1));
			else
				Format(g_sTierString, 512, "%s%cLinear", g_sTierString, LIMEGREEN);

			if (g_bhasBonus)
				if (g_mapZoneGroupCount > 2)
					Format(g_sTierString, 512, "%s %c-%c %i Bonuses", g_sTierString, WHITE, ORANGE, (g_mapZoneGroupCount - 1));
				else
					Format(g_sTierString, 512, "%s %c-%c Bonus", g_sTierString, WHITE, ORANGE, (g_mapZoneGroupCount - 1));
		}
	}

	RunCallback(cb);
}

// 7
void db_viewRecordCheckpointInMap(any cb=0)
{
	for (int k = 0; k < MAX_ZONEGROUPS; k++)
	{
		g_bCheckpointRecordFound[k] = false;
		for (int i = 0; i < CPLIMIT; i++)
		g_fCheckpointServerRecord[k][i] = 0.0;
	}

	// "SELECT c.zonegroup, c.cp1, c.cp2, c.cp3, c.cp4, c.cp5, c.cp6, c.cp7, c.cp8, c.cp9, c.cp10, c.cp11, c.cp12, c.cp13, c.cp14, c.cp15, c.cp16, c.cp17, c.cp18, c.cp19, c.cp20, c.cp21, c.cp22, c.cp23, c.cp24, c.cp25, c.cp26, c.cp27, c.cp28, c.cp29, c.cp30, c.cp31, c.cp32, c.cp33, c.cp34, c.cp35 FROM ck_checkpoints c WHERE steamid = '%s' AND mapname='%s' UNION SELECT a.zonegroup, b.cp1, b.cp2, b.cp3, b.cp4, b.cp5, b.cp6, b.cp7, b.cp8, b.cp9, b.cp10, b.cp11, b.cp12, b.cp13, b.cp14, b.cp15, b.cp16, b.cp17, b.cp18, b.cp19, b.cp20, b.cp21, b.cp22, b.cp23, b.cp24, b.cp25, b.cp26, b.cp27, b.cp28, b.cp29, b.cp30, b.cp31, b.cp32, b.cp33, b.cp34, b.cp35 FROM ck_bonus a LEFT JOIN ck_checkpoints b ON a.steamid = b.steamid AND a.zonegroup = b.zonegroup WHERE a.mapname = '%s' GROUP BY a.zonegroup";
	char szQuery[1028];
	Format(szQuery, 1028, sql_selectRecordCheckpoints, g_szRecordMapSteamID, g_szMapName, g_szMapName);
	g_hDb.Query(sql_selectRecordCheckpointsCallback, szQuery, cb, DBPrio_High);
}

void sql_selectRecordCheckpointsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_selectRecordCheckpointsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int zonegroup;
		while (SQL_FetchRow(hndl))
		{
			zonegroup = SQL_FetchInt(hndl, 0);
			for (int i = 0; i < 35; i++)
			{
				g_fCheckpointServerRecord[zonegroup][i] = SQL_FetchFloat(hndl, (i + 1));
				if (!g_bCheckpointRecordFound[zonegroup] && g_fCheckpointServerRecord[zonegroup][i] > 0.0)
				g_bCheckpointRecordFound[zonegroup] = true;
			}
		}
	}

	RunCallback(cb);
}

// 8
void db_CalcAvgRunTime(any cb=0)
{
	char szQuery[256];
	Format(szQuery, 256, sql_selectAllMapTimesinMap, g_szMapName);
	g_hDb.Query(SQL_db_CalcAvgRunTimeCallback, szQuery, cb, DBPrio_High);
}

void SQL_db_CalcAvgRunTimeCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_db_CalcAvgRunTimeCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	g_favg_maptime = 0.0;
	if (SQL_HasResultSet(hndl))
	{
		int rowcount = SQL_GetRowCount(hndl);
		int i, protimes;
		float ProTime;

		while (SQL_FetchRow(hndl))
		{
			float pro = SQL_FetchFloat(hndl, 0);
			if (pro > 0.0)
			{
				ProTime += pro;
				protimes++;
			}

			i++;
			if (rowcount == i)
				g_favg_maptime = ProTime / protimes;

		}
	}
	RunCallback(cb);
}

// 9
void db_CalcAvgRunTimeBonus(any cb=0)
{
	if (!g_bhasBonus)
	{
		RunCallback(cb);
		return;
	}

	char szQuery[256];
	Format(szQuery, 256, sql_selectAllBonusTimesinMap, g_szMapName);
	g_hDb.Query(SQL_db_CalcAvgRunBonusTimeCallback, szQuery, cb, DBPrio_High);
}

void SQL_db_CalcAvgRunBonusTimeCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_db_CalcAvgRunTimeCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	for (int i = 1; i < MAX_ZONEGROUPS; i++)
		g_fAvg_BonusTime[i] = 0.0;

	if (SQL_HasResultSet(hndl))
	{
		int zonegroup, runtimes[MAX_ZONEGROUPS];
		float runtime[MAX_ZONEGROUPS], time;
		while (SQL_FetchRow(hndl))
		{
			zonegroup = SQL_FetchInt(hndl, 0);
			time = SQL_FetchFloat(hndl, 1);
			if (time > 0.0)
			{
				runtime[zonegroup] += time;
				runtimes[zonegroup]++;
			}
		}

		for (int i = 1; i < MAX_ZONEGROUPS; i++)
			g_fAvg_BonusTime[i] = runtime[i] / runtimes[i];
	}

	RunCallback(cb);
}

// 10
void db_CalculatePlayerCount(any cb=0)
{
	char szQuery[255];
	Format(szQuery, 255, sql_CountRankedPlayers, 0);
	g_hDb.Query(sql_CountRankedPlayersCallback, szQuery, cb, DBPrio_High);
}

void sql_CountRankedPlayersCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CountRankedPlayersCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		g_pr_AllPlayers[0] = SQL_FetchInt(hndl, 0);
	else
		g_pr_AllPlayers[0] = 1;

	RunCallback(cb);
}

// 11
void db_CalculatePlayersCountGreater0(any cb=0)
{
	char szQuery[255];
	Format(szQuery, 255, sql_CountRankedPlayers2, 0);
	g_hDb.Query(sql_CountRankedPlayers2Callback, szQuery, cb, DBPrio_High);
}

void sql_CountRankedPlayers2Callback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_CountRankedPlayers2Callback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
		g_pr_RankedPlayers[0] = SQL_FetchInt(hndl, 0);
	else
		g_pr_RankedPlayers[0] = 0;

	RunCallback(cb);
}

// 12
void db_selectSpawnLocations(any cb=0)
{
	for (int s = 0; s < CPLIMIT; s++)
	{
		for (int i = 0; i < MAX_ZONEGROUPS; i++)
		{
			g_bGotSpawnLocation[i][s][0] = false;
			g_bGotSpawnLocation[i][s][1] = false;
		}
	}

	char szQuery[254];
	Format(szQuery, 254, sql_selectSpawnLocations, g_szMapName);
	g_hDb.Query(db_selectSpawnLocationsCallback, szQuery, cb, DBPrio_High);
}

void db_selectSpawnLocationsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectSpawnLocationsCallback): %s ", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			int zonegroup = SQL_FetchInt(hndl, 10);
			int stage = SQL_FetchInt(hndl, 11);
			int teleside = SQL_FetchInt(hndl, 12);

			g_bGotSpawnLocation[zonegroup][stage][teleside] = true;
			g_fSpawnLocation[zonegroup][stage][teleside][0] = SQL_FetchFloat(hndl, 1);
			g_fSpawnLocation[zonegroup][stage][teleside][1] = SQL_FetchFloat(hndl, 2);
			g_fSpawnLocation[zonegroup][stage][teleside][2] = SQL_FetchFloat(hndl, 3);
			g_fSpawnAngle[zonegroup][stage][teleside][0] = SQL_FetchFloat(hndl, 4);
			g_fSpawnAngle[zonegroup][stage][teleside][1] = SQL_FetchFloat(hndl, 5);
			g_fSpawnAngle[zonegroup][stage][teleside][2] = SQL_FetchFloat(hndl, 6);
			g_fSpawnVelocity[zonegroup][stage][teleside][0] = SQL_FetchFloat(hndl, 7);
			g_fSpawnVelocity[zonegroup][stage][teleside][1] = SQL_FetchFloat(hndl, 8);
			g_fSpawnVelocity[zonegroup][stage][teleside][2] = SQL_FetchFloat(hndl, 9);
		}
	}

	RunCallback(cb);
}

// 13
void db_ClearLatestRecords(any cb=0)
{
	if (g_DbType == MYSQL)
		g_hDb.Query(SQL_CheckCallback, "DELETE FROM ck_latestrecords WHERE date < NOW() - INTERVAL 1 WEEK");
	else
		g_hDb.Query(SQL_CheckCallback, "DELETE FROM ck_latestrecords WHERE date <= date('now','-7 day')");

	RunCallback(cb);
}

// 14
void db_GetDynamicTimelimit(any cb=0)
{
	if (!g_hDynamicTimelimit.BoolValue)
	{
		RunCallback(cb);
		return;
	}
	char szQuery[256];
	Format(szQuery, 256, sql_selectAllMapTimesinMap, g_szMapName);
	g_hDb.Query(SQL_db_GetDynamicTimelimitCallback, szQuery, cb, DBPrio_High);
}

void SQL_db_GetDynamicTimelimitCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (SQL_db_GetDynamicTimelimitCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int maptimes = 0;
		float total = 0.0, time = 0.0;
		while (SQL_FetchRow(hndl))
		{
			time = SQL_FetchFloat(hndl, 0);
			if (time > 0.0)
			{
				total += time;
				maptimes++;
			}
		}

		// requires min. 5 map times
		int timelimit = 30;
		if (maptimes > 5)
		{
			int scale_factor = 3;
			int avg = RoundToNearest((total) / 60.0 / float(maptimes));

			// scale factor
			if (avg <= 10)
				scale_factor = 5;
			if (avg <= 5)
				scale_factor = 8;
			if (avg <= 3)
				scale_factor = 10;
			if (avg <= 2)
				scale_factor = 12;
			if (avg <= 1)
				scale_factor = 14;

			avg = avg * scale_factor;

			// timelimit: min 20min, max 120min
			if (avg < 20)
				avg = 20;
			if (avg > 60)
				avg = 60;

			timelimit = avg;
		}

		// set timelimit
		char szTimelimit[32];
		Format(szTimelimit, sizeof(szTimelimit), "mp_timelimit %i;mp_roundtime %i;mp_roundtime_defuse %i;mp_roundtime_deployment %i;mp_roundtime_hostage %i", timelimit, timelimit, timelimit, timelimit, timelimit);
		ServerCommand(szTimelimit);
		ServerCommand("mp_restartgame 1");
	}

	RunCallback(cb);
}

// 15
void db_GetTotalStages(any cb=0)
{
	// Check if map has stages, if not don't bother loading this
	if (!g_bhasStages)
	{
		RunCallback(cb);
		return;
	}

	char szQuery[512];
	Format(szQuery, 512, "SELECT COUNT(`zonetype`) AS stages FROM `ck_zones` WHERE `zonetype` = '3' AND `mapname` = '%s'", g_szMapName);
	g_hDb.Query(db_GetTotalStagesCallback, szQuery, cb, DBPrio_High);
}

void db_GetTotalStagesCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_GetTotalStagesCallback): %s ", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		g_TotalStages = SQL_FetchInt(hndl, 0) + 1;

		for(int i = 1; i <= g_TotalStages; i++)
		{
			g_fStageRecord[i] = 0.0;
			// fluffys comeback yo
		}
	}
	RunCallback(cb);
}

// 16
void db_viewStageRecords(any cb=0)
{
	if (!g_bhasStages)
	{
		RunCallback(cb);
		return;
	}

	char szQuery[512];
	Format(szQuery, 512, "SELECT full.name, full.runtimepro, full.stage, full.style FROM ( SELECT MIN(runtimepro) AS time, stage, style, mapname FROM ck_wrcps WHERE mapname = '%s' GROUP BY stage, style ) as mins INNER JOIN ck_wrcps AS full ON mins.time = full.runtimepro AND mins.stage = full.stage AND mins.style = full.style AND mins.mapname = full.mapname;", g_szMapName);
	g_hDb.Query(sql_viewStageRecordsCallback, szQuery, cb, DBPrio_High);
}

void sql_viewStageRecordsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_viewStageRecordsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int stage;
		int style;
		char szName[MAX_NAME_LENGTH];

		while (SQL_FetchRow(hndl))
		{
			SQL_FetchString(hndl, 0, szName, sizeof(szName));
			stage = SQL_FetchInt(hndl, 2);
			style = SQL_FetchInt(hndl, 3);

			if (style == STYLE_NORMAL)
			{
				g_fStageRecord[stage] = SQL_FetchFloat(hndl, 1);
				if (g_fStageRecord[stage] > -1.0 && !SQL_IsFieldNull(hndl, 1))
				{
					g_fStageRecord[stage] = SQL_FetchFloat(hndl, 1);
					Format(g_szStageRecordPlayer[stage], sizeof(g_szStageRecordPlayer), szName);
					FormatTimeFloat(0, g_fStageRecord[stage], 3, g_szRecordStageTime[stage], 64);
				}
				else
				{
					Format(g_szStageRecordPlayer[stage], sizeof(g_szStageRecordPlayer), "N/A");
					Format(g_szRecordStageTime[stage], 64, "N/A");
					g_fStageRecord[stage] = 9999999.0;
				}
			}
			else
			{
				g_fStyleStageRecord[style][stage] = SQL_FetchFloat(hndl, 1);
				if (g_fStyleStageRecord[style][stage] > -1.0 && !SQL_IsFieldNull(hndl, 1))
				{
					g_fStyleStageRecord[style][stage] = SQL_FetchFloat(hndl, 1);
					FormatTimeFloat(0, g_fStyleStageRecord[style][stage], 3, g_szStyleRecordStageTime[style][stage], 64);
				}
				else
				{
					Format(g_szStyleRecordStageTime[style][stage], 64, "N/A");
					g_fStyleStageRecord[style][stage] = 9999999.0;
				}
			}
		}
	}
	else
	{
		for (int i = 1; i <= g_TotalStages; i++)
		{
			Format(g_szRecordStageTime[i], 64, "N/A");
			g_fStageRecord[i] = 9999999.0;
			for (int s = 1; s < MAX_STYLES; s++)
			{
				Format(g_szStyleRecordStageTime[s][i], 64, "N/A");
				g_fStyleStageRecord[s][i] = 9999999.0;
			}
		}
	}

	RunCallback(cb);
}

// 17
void db_viewTotalStageRecords(any cb=0)
{
	if (!g_bhasStages)
	{
		RunCallback(cb);
		return;
	}

	char szQuery[512];
	Format(szQuery, 512, "SELECT stage, style, count(1) FROM ck_wrcps WHERE mapname = '%s' GROUP BY stage, style;", g_szMapName);
	g_hDb.Query(sql_viewTotalStageRecordsCallback, szQuery, cb, DBPrio_High);
}

void sql_viewTotalStageRecordsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (sql_viewTotalStageRecordsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		int stage;
		int style;

		for (int i = 0; i < CPLIMIT; i++)
		{
			g_TotalStageRecords[i] = 0;
		}

		while (SQL_FetchRow(hndl))
		{
			stage = SQL_FetchInt(hndl, 0);
			style = SQL_FetchInt(hndl, 1);

			if (style == STYLE_NORMAL)
			{
				g_TotalStageRecords[stage] = SQL_FetchInt(hndl, 2);

				if (g_TotalStageRecords[stage] > -1.0 && !SQL_IsFieldNull(hndl, 2))
					g_TotalStageRecords[stage] = SQL_FetchInt(hndl, 2);
				else
					g_TotalStageRecords[stage] = 0;
				
			}
			else
			{
				g_TotalStageStyleRecords[style][stage] = SQL_FetchInt(hndl, 2);

				if (g_TotalStageStyleRecords[style][stage] > -1.0 && !SQL_IsFieldNull(hndl, 2))
					g_TotalStageStyleRecords[style][stage] = SQL_FetchInt(hndl, 2);
				else
					g_TotalStageStyleRecords[style][stage] = 0;
			}
		}
	}
	else
	{
		for (int i = 1; i <= g_TotalStages; i++)
		{
			g_TotalStageRecords[i] = 0;
			for (int s = 1; i < MAX_STYLES; s++)
			{
				g_TotalStageStyleRecords[s][i] = 0;
			}
		}
	}

	RunCallback(cb);
}

// 18
void db_selectCurrentMapImprovement(any cb=0)
{
	char szQuery[1024];
	Format(szQuery, 1024, "SELECT mapname, (SELECT count(1) FROM ck_playertimes b WHERE a.mapname = b.mapname AND b.style = 0) as total FROM ck_playertimes a where mapname = '%s' AND style = 0 LIMIT 0, 1;", g_szMapName);
	g_hDb.Query(db_selectMapCurrentImprovementCallback, szQuery, cb, DBPrio_High);
}

void db_selectMapCurrentImprovementCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[Surftimer] SQL Error (db_selectMapCurrentImprovementCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl) && SQL_FetchRow(hndl))
	{
		int totalplayers;
		totalplayers = SQL_FetchInt(hndl, 1);

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

		g_G1Top = g1top;

		// Group 2
		float fG2top;
		int g2top;
		int g2bot;
		g2bot = g1top + 1;
		fG2top = (float(totalplayers) * g_Group2Pc);
		fG2top += 11.0;
		g2top = RoundToCeil(fG2top);
		g_G2Bot = g2bot;
		g_G2Top = g2top;

		int g2difference = (g2top - g2bot);
		if (g2difference < 4)
			g2top = (g2bot + 4);

		g_G2Bot = g2bot;
		g_G2Top = g2top;

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

		g_G3Bot = g3bot;
		g_G3Top = g3top;

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

		g_G4Bot = g4bot;
		g_G4Top = g4top;

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

		g_G5Bot = g5bot;
		g_G5Top = g5top;
	} else {
		PrintToServer("surftimer | No result found for map %s (db_selectMapCurrentImprovementCallback)", g_szMapName);
	}

	RunCallback(cb);
}

// 19

void db_selectAnnouncements(any cb=0)
{
	char szQuery[1024];
	char szEscServerName[128];
	SQL_EscapeString(g_hDb, g_sServerName, szEscServerName, sizeof(szEscServerName));
	Format(szQuery, 1024, "SELECT `id` FROM `ck_announcements` WHERE `server` != '%s' AND `id` > %d", szEscServerName, g_iLastID);
	g_hDb.Query(SQL_SelectAnnouncementsCallback, szQuery, cb, DBPrio_High);
}

void SQL_SelectAnnouncementsCallback(Handle owner, Handle hndl, const char[] error, any cb)
{
	if (hndl == null)
	{
		LogError("[surftimer] SQL Error (SQL_SelectAnnouncementsCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (SQL_HasResultSet(hndl))
	{
		while (SQL_FetchRow(hndl))
		{
			int id = SQL_FetchInt(hndl, 0);
			if (id > g_iLastID)
				g_iLastID = id;
		}
	}

	g_bHasLatestID = true;

	RunCallback(cb);
}
