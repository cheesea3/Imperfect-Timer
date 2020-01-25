
// Zone beam colours
int beamColorEdit[] = { 255, 255, 0, 235 };
int beamColorOther[] = { 255, 255, 255, 128 };

// Outline colour (white)
int g_outlineBeamColor[] = { 255, 255, 255, 200 };

public void DrawBeamBox(int client)
{
	BeamBox(INVALID_HANDLE, client);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action BeamBox(Handle timer, int client)
{
	if (IsValidClient(client)) {
		if (g_Editing[client] == 2) {
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 1.0, 1.0, 1.0, 1, 0.0, beamColorEdit, 0, true);
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
	if (i >= g_mapZonesCount)
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

	for (int p = 1; p <= MaxClients; p++) {
		if (!IsValidClient(p) || IsFakeClient(p)) {
			continue;
		}
		if (g_ClientSelectedZone[p] == i) {
			continue;
		}

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
		TE_SendBeamBoxToClient(p, buffer_a, buffer_b, g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, ZONE_REFRESH_TIME, 1.0, 1.0, 1, 0.0, zColor, 0, full);
	}

	CreateTimer(0.1, ThrottledBeamBoxAll, i + 1);
}

public Action OutlineBeamsAll(Handle timer)
{
	ThrottledOutlineBeamsAll(INVALID_HANDLE);
}

public Action ThrottledOutlineBeamsAll(Handle timer)
{
	// @IG Outlines
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		// check for outline visibility
		if (g_players[i].outlines)
		{
			for (int j = 0; j < g_iOutlineBoxCount; j++)
			{
				Effect_DrawBeamBoxRotatableToClient(i, g_outlineBoxes[j].origin, g_outlineBoxes[j].startPos, g_outlineBoxes[j].endPos, g_outlineBoxes[j].angles,
													g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, OUTLINE_REFRESH_TIME, 1.0, 1.0, 1, 0.0, g_outlineBeamColor, 0);

				//if (IsPlayerZoner(j))
				//	CPrintToChat(j, "Hook at {%.1f, %.1f, %.1f} | Min: {%.1f, %.1f, %.1f} | Max: {%.1f, %.1f, %.1f}", g_outlineBoxes[j].origin[0], g_outlineBoxes[j].origin[1], g_outlineBoxes[j].origin[2],
				//					g_outlineBoxes[j].startPos[0], g_outlineBoxes[j].startPos[1], g_outlineBoxes[j].startPos[2], g_outlineBoxes[j].endPos[0], g_outlineBoxes[j].endPos[1], g_outlineBoxes[j].endPos[2]);
				//TE_SendBeamBoxToClient(i, g_outlineBoxes[j].startPos, g_outlineBoxes[j].endPos, g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, OUTLINE_REFRESH_TIME, 1.0, 1.0, 1, 0.0, g_outlineBeamColor, 0, true);
			}

			for (int j = 0; j < g_iOutlineLineCount; j++)
				TE_SendBeamLineToClient(i, g_outlineLines[j].startPos, g_outlineLines[j].endPos, g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, OUTLINE_REFRESH_TIME, 1.0, 1.0, 1, 0.0, g_outlineBeamColor, 0);
		}
	}
}

public void getZoneDisplayColor(int type, int zColor[4], int zGrp)
{
	switch (type)
	{
		case ZONETYPE_START:
		{
			if (zGrp > 0)
				zColor = g_iZoneColors[3];
			else
				zColor = g_iZoneColors[1];
		}

		case ZONETYPE_END:
		{
			if (zGrp > 0)
				zColor = g_iZoneColors[4];
			else
				zColor = g_iZoneColors[2];
		}

		case ZONETYPE_STAGE: zColor = g_iZoneColors[5];
		case ZONETYPE_CHECKPOINT: zColor = g_iZoneColors[6];
		case ZONETYPE_SPEEDSTART: zColor = g_iZoneColors[7];
		case ZONETYPE_TELETOSTART: zColor = g_iZoneColors[8];
		case ZONETYPE_VALIDATOR: zColor = g_iZoneColors[9];
		case ZONETYPE_CHECKER: zColor = g_iZoneColors[10];
		case ZONETYPE_STOP: zColor = g_iZoneColors[0];
		default: zColor = beamColorOther;
	}
}

public void BeamBox_OnPlayerRunCmd(int client)
{
	if (g_Editing[client] == 1 || g_Editing[client] == 3 || g_Editing[client] == 10 || g_Editing[client] == 11)
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
			if (g_Editing[client] == 10) {
				TR_GetEndPosition(g_fBonusStartPos[client][1]);
				TE_SendBeamBoxToClient(client, g_fBonusStartPos[client][1], g_fBonusStartPos[client][0], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 1.0, 1.0, 1, 0.0, beamColorEdit, 0, true);
			} else {
				TR_GetEndPosition(g_fBonusEndPos[client][1]);
				TE_SendBeamBoxToClient(client, g_fBonusEndPos[client][1], g_fBonusEndPos[client][0], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 1.0, 1.0, 1, 0.0, beamColorEdit, 0, true);
			}
		} else {
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 1.0, 1.0, 1, 0.0, beamColorEdit, 0, true);
		}
	}

	if (g_iSelectedTrigger[client] > -1) {
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

			TE_SendBeamBoxToClient(client, fMins, fMaxs, g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 1.0, 1.0, 1.0, 1, 0.0, view_as<int>({255, 255, 0, 255}), 0, true);
		}
	}

	// @IG outlines
	if (g_bCreatingOutline[client] && g_bStartPointPlaced[client] && g_bEndPointPlaced[client] && IsValidClient(client))
	{
		if (g_iOutlineStyle[client] == OUTLINE_STYLE_LINE)
		{
			TE_SendBeamLineToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 0.8, 0.8, 1, 0.0, g_outlineBeamColor, 0);
		}
		else if (g_iOutlineStyle[client] == OUTLINE_STYLE_BOX)
		{
			TE_SendBeamBoxToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 1.0, 1.0, 1, 0.0, g_outlineBeamColor, 0, true);
		}
	}
}

#define WALL_BEAMBOX_OFFSET_UNITS 2.0

stock void TE_SendBeamBoxToClient(  int client,
									float uppercorner[3],
									float bottomcorner[3],
									int ModelIndex,
									int HaloIndex,
									int StartFrame,
									int FrameRate,
									float Life,
									float Width,
									float EndWidth,
									int FadeLength,
									float Amplitude,
									const int Color[4],
									int Speed,
									bool full)
{
	float corners[8][3];
	Array_Copy(uppercorner, corners[0], 3);
	Array_Copy(bottomcorner, corners[7], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++) {
		min[i] = corners[0][i];
		if (corners[7][i] < min[i]) min[i] = corners[7][i];
	}

	// Calculate all corners from two provided
	for(int i = 1; i < 7; i++) {
		for(int j = 0; j < 3; j++) {
			corners[i][j] = corners[((i >> (2-j)) & 1) * 7][j];
		}
	}

	// Pull corners in by 1 unit to prevent them being hidden inside the ground / walls / ceiling
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 8; i++) {
			if (corners[i][j] == min[j]) {
				corners[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			} else {
				corners[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
			}
		}
		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	// Send beams to client
	// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
	for (int i = 0, i2 = 3; i2 >= 0; i+=i2--)
	{
		for(int j = 1; j <= 7; j += (j / 2) + 1)
		{
			if (j != 7-i)
			{
				if (!full && (corners[i][2] != min[2] || corners[j][2] != min[2]))
					continue;
				TE_SetupBeamPoints(corners[i], corners[j], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
				TE_SendToClient(client);
			}
		}
	}
}

stock void TE_SendBeamLineToClient( int client,
									float start[3],
									float end[3],
									int modelIndex,
									int haloIndex,
									int startFrame,
									int frameRate,
									float life,
									float width,
									float endWidth,
									int fadeLength,
									float amplitude,
									const int color[4],
									int speed)
{
	float points[2][3];
	Array_Copy(start, points[0], 3);
	Array_Copy(end, points[1], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++) {
		min[i] = points[0][i];
		if (points[1][i] < min[i])
			min[i] = points[1][i];
	}

	// Pull points in by 1 unit to prevent them being hidden inside the ground / walls / ceiling
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 2; i++) {
			if (points[i][j] == min[j])
				points[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			else
				points[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
		}

		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	TE_SetupBeamPoints(points[0], points[1], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
	TE_SendToClient(client);
}