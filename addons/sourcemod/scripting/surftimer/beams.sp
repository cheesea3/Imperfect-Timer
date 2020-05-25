
// Zone beam colours
int beamColorEdit[] = { 255, 255, 0, 235 };
int beamColorOther[] = { 255, 255, 255, 128 };

public void DrawBeamBox(int client)
{
	BeamBox(INVALID_HANDLE, client);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action BeamBox(Handle timer, int client)
{
	if (IsValidClient(client))
	{
		if (g_Editing[client] == 2 && g_bAllowBeams)
		{

			//IG_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 1.0, 1.0, 1.0, 1, 0.0, beamColorEdit, 0, true);
			IG_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], 1.0, beamColorEdit, true);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action BeamBoxAll(Handle timer, any data)
{
	ThrottledBeamBoxAll(INVALID_HANDLE, 0);
}

public Action ThrottledBeamBoxAll(Handle timer, int i)
{
	if (i >= g_mapZonesCount || !g_bAllowBeams)
		return;

	int zonesToDisplay = GetConVarInt(g_hZonesToDisplay);

	bool drawForEveryone = false;
	int iZoneType = g_mapZones[i].zoneType;
	int iZoneGroup = g_mapZones[i].zoneGroup;

	switch(iZoneType)
	{
		case ZONETYPE_START,
			 ZONETYPE_SPEEDSTART,
			 ZONETYPE_END: {
			drawForEveryone = zonesToDisplay >= 1;
		}
		case ZONETYPE_STAGE: drawForEveryone = zonesToDisplay >= 2;
		default: drawForEveryone = zonesToDisplay >= 3;
	}

	int zColor[4];
	getZoneDisplayColor(iZoneType, zColor, iZoneGroup);

	for (int p = 1; p <= MaxClients; p++)
	{
		if (!IsValidClient(p) || IsFakeClient(p) || g_ClientSelectedZone[p] == i)
			continue;

		bool full = false;
		bool draw = drawForEveryone;

		if (g_bShowZones[p])
		{
			// Player has /showzones enabled
			full = true;
			draw = true;
		}
		else if (GetConVarInt(g_hZoneDisplayType) >= 2)
		{
			// Draw full box
			full = true;
		}
		else if (GetConVarInt(g_hZoneDisplayType) >= 1)
		{
			// Draw bottom only
		}
		else if (GetConVarInt(g_hZoneDisplayType) == 0)
		{
			draw = false;
		}

		if (!draw)
			continue;

		float buffer_a[3], buffer_b[3];
		for (int x = 0; x < 3; x++)
		{
			buffer_a[x] = g_mapZones[i].PointA[x];
			buffer_b[x] = g_mapZones[i].PointB[x];
		}

		IG_SendBeamBoxToClient(p, g_mapZones[i].PointA, g_mapZones[i].PointB, ZONE_REFRESH_TIME, zColor, full);
	}

	CreateTimer(0.1, ThrottledBeamBoxAll, i + 1, TIMER_FLAG_NO_MAPCHANGE);
}

public void BeamBox_OnPlayerRunCmd(int client)
{
	if (g_bAllowBeams && (g_Editing[client] == 1 || g_Editing[client] == 3 || g_Editing[client] == 10 || g_Editing[client] == 11))
	{
		float pos[3], ang[3];
		if (g_Editing[client] == 1)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			TR_GetEndPosition(g_Positions[client][1]);
		}

		if (g_Editing[client] == 10 || g_Editing[client] == 11)
		{
			GetClientEyePosition(client, pos);
			GetClientEyeAngles(client, ang);
			TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
			if (g_Editing[client] == 10)
			{
				TR_GetEndPosition(g_fBonusStartPos[client][1]);
				IG_SendBeamBoxToClient(client, g_fBonusStartPos[client][1], g_fBonusStartPos[client][0], 0.1, beamColorEdit, true);
			}
			else
			{
				TR_GetEndPosition(g_fBonusEndPos[client][1]);
				IG_SendBeamBoxToClient(client, g_fBonusEndPos[client][1], g_fBonusEndPos[client][0], 0.1, beamColorEdit, true);
			}
		}
		else
		{
			IG_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], 0.1, beamColorEdit, true);
		}
	}

	if (g_iSelectedTrigger[client] > -1 && g_bAllowBeams)
	{
		// come back
		float position[3], fMins[3], fMaxs[3];

		int iEnt = GetArrayCell(g_hTriggerMultiple, g_iSelectedTrigger[client]);
		if (IsValidEntity(iEnt))
		{
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
			GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
			GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);

			for (int j = 0; j < 3; j++)
			{
				fMins[j] = (fMins[j] + position[j]);
			}

			for (int j = 0; j < 3; j++)
			{
				fMaxs[j] = (fMaxs[j] + position[j]);
			}

			//TE_SendBeamBoxToClient(client, fMins, fMaxs, g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 1.0, 1.0, 1.0, 1, 0.0, view_as<int>({255, 255, 0, 255}), 0, true);
			IG_SendBeamBoxToClient(client, fMins, fMaxs, 0.1, beamColorEdit, true);
		}
	}
}
