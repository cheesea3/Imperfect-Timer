public void CreateZoneEntity(int zoneIndex)
{
	float fMiddle[3], fMins[3], fMaxs[3];
	char sZoneName[64];
	char szHookName[128];

	if (g_mapZones[zoneIndex].PointA[0] == -1.0 && g_mapZones[zoneIndex].PointA[1] == -1.0 && g_mapZones[zoneIndex].PointA[2] == -1.0)
	{
		return;
	}

	Array_Copy(g_mapZones[zoneIndex].PointA, fMins, 3);
	Array_Copy(g_mapZones[zoneIndex].PointB, fMaxs, 3);

	Format(sZoneName, sizeof(sZoneName), "%s", g_mapZones[zoneIndex].zoneName);
	Format(szHookName, sizeof(szHookName), "%s", g_mapZones[zoneIndex].hookName);

	if (!StrEqual(szHookName, "None"))
	{
		int iEnt;
		for (int i = 0; i < GetArraySize(g_hTriggerMultiple); i++)
		{
			iEnt = GetArrayCell(g_hTriggerMultiple, i);

			if (IsValidEntity(iEnt))
			{
				char szTriggerName[128];
				GetEntPropString(iEnt, Prop_Send, "m_iName", szTriggerName, 128, 0);
				// GetEntityClassname(iEnt, szClassName, sizeof(szClassName));
				if (StrEqual(szHookName, szTriggerName))
				{
					Format(sZoneName, sizeof(sZoneName), "sm_ckZoneHooked %i", zoneIndex);
					float position[3];
					// come back
					GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
					GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
					GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);

					g_mapZones[zoneIndex].CenterPoint[0] = position[0];
					g_mapZones[zoneIndex].CenterPoint[1] = position[1];
					g_mapZones[zoneIndex].CenterPoint[2] = position[2];
					// g_mapZones[zoneIndex][zoneType]

					for (int j = 0; j < 3; j++)
					{
						fMins[j] = (fMins[j] + position[j]);
					}

					for (int j = 0; j < 3; j++)
					{
						fMaxs[j] = (fMaxs[j] + position[j]);
					}

					g_mapZones[zoneIndex].PointA[0] = fMins[0];
					g_mapZones[zoneIndex].PointA[1] = fMins[1];
					g_mapZones[zoneIndex].PointA[2] = fMins[2];
					g_mapZones[zoneIndex].PointB[0] = fMaxs[0];
					g_mapZones[zoneIndex].PointB[1] = fMaxs[1];
					g_mapZones[zoneIndex].PointB[2] = fMaxs[2];

					for (int j = 0; j < 3; j++)
					{
						g_fZoneCorners[zoneIndex][0][j] = g_mapZones[zoneIndex].PointA[j];
						g_fZoneCorners[zoneIndex][7][j] = g_mapZones[zoneIndex].PointB[j];
					}

					for(int j = 1; j < 7; j++)
					{
						for(int k = 0; k < 3; k++)
						{
							g_fZoneCorners[zoneIndex][j][k] = g_fZoneCorners[zoneIndex][((j >> (2-k)) & 1) * 7][k];
						}
					}

					DispatchKeyValue(iEnt, "targetname", sZoneName);

					SDKHook(iEnt, SDKHook_StartTouch, StartTouchTrigger);
					SDKHook(iEnt, SDKHook_EndTouch, EndTouchTrigger);

					DispatchKeyValue(iEnt, "m_iClassname", "hooked");
				}
			}
		}
	}
	else
	{
		int iEnt = CreateEntityByName("trigger_multiple");

		if (iEnt > 0 && IsValidEntity(iEnt))
		{
			SetEntityModel(iEnt, ZONE_MODEL);
			// Spawnflags:	1 - only a player can trigger this by touch, makes it so a NPC cannot fire a trigger_multiple
			// 2 - Won't fire unless triggering ent's view angles are within 45 degrees of trigger's angles (in addition to any other conditions), so if you want the player to only be able to fire the entity at a 90 degree angle you would do ",angles,0 90 0," into your spawnstring.
			// 4 - Won't fire unless player is in it and pressing use button (in addition to any other conditions), you must make a bounding box,(max\mins) for this to work.
			// 8 - Won't fire unless player/NPC is in it and pressing fire button, you must make a bounding box,(max\mins) for this to work.
			// 16 - only non-player NPCs can trigger this by touch
			// 128 - Start off, has to be activated by a target_activate to be touchable/usable
			// 256 - multiple players can trigger the entity at the same time
			DispatchKeyValue(iEnt, "spawnflags", "257");
			DispatchKeyValue(iEnt, "StartDisabled", "0");

			Format(sZoneName, sizeof(sZoneName), "sm_ckZone %i", zoneIndex);
			DispatchKeyValue(iEnt, "targetname", sZoneName);
			DispatchKeyValue(iEnt, "wait", "0");

			if (DispatchSpawn(iEnt))
			{
				ActivateEntity(iEnt);

				GetMiddleOfABox(fMins, fMaxs, fMiddle);

				TeleportEntity(iEnt, fMiddle, NULL_VECTOR, NULL_VECTOR);

				// Have the mins always be negative
				for(int i = 0; i < 3; i++){
					fMins[i] = fMins[i] - fMiddle[i];
					if (fMins[i] > 0.0)
						fMins[i] *= -1.0;
				}

				// And the maxs always be positive
				for(int i = 0; i < 3; i++){
					fMaxs[i] = fMaxs[i] - fMiddle[i];
					if (fMaxs[i] < 0.0)
						fMaxs[i] *= -1.0;
				}

				SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
				SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
				SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);

				int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
				iEffects |= 0x020;
				SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);

				SDKHook(iEnt, SDKHook_StartTouch, StartTouchTrigger);
				SDKHook(iEnt, SDKHook_EndTouch, EndTouchTrigger);
			}
			else
			{
				LogError("Not able to dispatchspawn for Entity %i in SpawnTrigger", iEnt);
			}
		}
	}
}

public Action StartTouchTrigger(int caller, int activator)
{
	int client = activator;

	// Ignore dead players
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}

	// g_bLeftZone[activator] = false;

	char sTargetName[256];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));

	if (StrContains(sTargetName, "sm_ckZoneHooked") != -1)
		ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZoneHooked ", "");
	else
		ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZone ", "");

	int id = StringToInt(sTargetName);

	int iZoneType = g_mapZones[id].zoneType;
	int iZoneTypeId = g_mapZones[id].zoneTypeId;
	int iZoneGroup = g_mapZones[id].zoneGroup;

	if (g_bUsingStageTeleport[activator])
		g_bUsingStageTeleport[activator] = false;

	// Set Client targetName
	if (!StrEqual("player", g_mapZones[id].targetName))
		DispatchKeyValue(activator, "targetname", g_mapZones[id].targetName);

	if (iZoneGroup == g_iClientInZone[activator][2]) {
		// Is touching zone in their active zonegroup
		// Set client location
		g_iClientInZone[activator][0] = iZoneType;
		g_iClientInZone[activator][1] = iZoneTypeId;
		g_iClientInZone[activator][2] = iZoneGroup;
		g_iClientInZone[activator][3] = id;
	} else if (iZoneType == 1 || iZoneType == 5) {
		// Is touching start or speedstart of some other zonegroup
		g_iClientInZone[activator][0] = iZoneType;
		g_iClientInZone[activator][1] = iZoneTypeId;
		g_iClientInZone[activator][2] = iZoneGroup;
		g_iClientInZone[activator][3] = id;
	} else if (iZoneType == 6 || iZoneType == 7 || iZoneType == 8 || iZoneType == 0 || iZoneType == 9 || iZoneType == 10 || iZoneType == 11) {
		// Is touching some MISC zone
		// (perform action but don't put the player there)
	} else {
		// Ignore this touch
		return Plugin_Handled;
	}

	// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0) // fluffys: NoBhop(9), NoCrouch(10)

	if (iZoneType == ZONETYPE_STOP) {
		Client_Stop(client, 1);
		lastCheckpoint[g_iClientInZone[client][2]][client] = 999;
	} else if (iZoneType == ZONETYPE_START || iZoneType == ZONETYPE_SPEEDSTART) {
		// Set Default Values
		Client_Stop(client, 1);
		ResetGravity(client);
		g_KeyCount[client] = 0;
		g_bInJump[client] = false;
		g_bInDuck[client] = false;
		g_bInMaxSpeed[client] = 0.0;
		g_iCurrentCheckpoint[client] = 0;
		g_Stage[g_iClientInZone[client][2]][client] = 1;
		g_bInStartZone[client] = true;
		g_bInStageZone[client] = false;
		g_iCurrentStyle[client] = g_iInitalStyle[client];
		lastCheckpoint[g_iClientInZone[client][2]][client] = 1;

		if (g_bhasStages)
		{
			g_bWrcpTimeractivated[client] = false;
			g_CurrentStage[client] = 0;
		}
	} else if (iZoneType == ZONETYPE_END) {
		if (g_iClientInZone[client][2] == iZoneGroup) // Cant end bonus timer in this zone && in the having the same timer on
		{
			// fluffys gravity
			if (g_iCurrentStyle[client] != 4) // low grav
				ResetGravity(client);

			g_bInJump[client] = false;
			g_bInDuck[client] = false;

			// fluffys wrcps
			if (g_bhasStages)
			{
				float time = g_fCurrentRunTime[client];
				g_bWrcpEndZone[client] = true;
				CL_OnEndWrcpTimerPress(client, time);
			}

			if (g_bToggleMapFinish[client])
			{
				if (GetConVarBool(g_hMustPassCheckpoints) && g_iTotalCheckpoints > 0 && iZoneGroup == 0)
				{
					if (g_bIsValidRun[client])
						CL_OnEndTimerPress(client);
					else
						CPrintToChat(client, "%t", "InvalidRun", g_szChatPrefix, g_bhasStages ? "stages" : "checkpoints");
				}
				else
					CL_OnEndTimerPress(client);
			}
			// Resetting checkpoints
			lastCheckpoint[g_iClientInZone[client][2]][client] = 999;
		}
	} else if (iZoneType == ZONETYPE_STAGE) {
		g_bInStageZone[client] = true;
		g_bInStartZone[client] = false;
		g_bInJump[client] = false;
		g_bInDuck[client] = false;
		g_KeyCount[client] = 0;

		// stop bot wrcp timer
		if (client == g_WrcpBot)
		{
			Client_Stop(client, 1);
			g_bWrcpTimeractivated[client] = false;
		}

		if (g_bPracticeMode[client]) // If practice mode is on
		{
			// TODO:
			// * Practice CPs
		}
		else
		{
			// Setting valid to false, in case of checkers
			g_bValidRun[client] = false;

			// Announcing checkpoint
			if (iZoneTypeId != lastCheckpoint[g_iClientInZone[client][2]][client] && g_iClientInZone[client][2] == iZoneGroup)
			{
				// Make sure the player is not going backwards
				if ((iZoneTypeId + 2) < g_Stage[g_iClientInZone[client][2]][client])
					g_bWrcpTimeractivated[client] = false;
				else
					g_bNewStage[client] = true;

				g_Stage[g_iClientInZone[client][2]][client] = (iZoneTypeId + 2);

				float time = g_fCurrentRunTime[client];
				float time2 = g_fCurrentWrcpRunTime[client];
				CL_OnEndWrcpTimerPress(client, time2);

				// Stage enforcer
				g_iCheckpointsPassed[client]++;
				if (g_iCheckpointsPassed[client] == g_TotalStages)
					g_bIsValidRun[client] = true;

				if (g_iCurrentStyle[client] == 0)
					Checkpoint(client, iZoneTypeId, g_iClientInZone[client][2], time);

				lastCheckpoint[g_iClientInZone[client][2]][client] = iZoneTypeId;
			}
			else if (!g_bTimerRunning[client])
				g_iCurrentStyle[client] = g_iInitalStyle[client];

			if (g_bWrcpTimeractivated[client])
				g_bWrcpTimeractivated[client] = false;
		}
	} else if (iZoneType == ZONETYPE_CHECKPOINT) {
		if (iZoneTypeId != lastCheckpoint[g_iClientInZone[client][2]][client] && g_iClientInZone[client][2] == iZoneGroup)
		{
			g_iCurrentCheckpoint[client]++;

			// Checkpoint enforcer
			if (GetConVarBool(g_hMustPassCheckpoints) && g_iTotalCheckpoints > 0)
			{
				g_iCheckpointsPassed[client]++;
				if (g_iCheckpointsPassed[client] == g_iTotalCheckpoints)
					g_bIsValidRun[client] = true;
			}

			// Announcing checkpoint in linear maps
			if (g_iCurrentStyle[client] == 0)
			{
				float time = g_fCurrentRunTime[client];
				Checkpoint(client, iZoneTypeId, g_iClientInZone[client][2], time);
				lastCheckpoint[g_iClientInZone[client][2]][client] = iZoneTypeId;
			}
		}
	} else if (iZoneType == ZONETYPE_TELETOSTART) {
		teleportClient(client, g_iClientInZone[client][2], 1, true);
	} else if (iZoneType == ZONETYPE_VALIDATOR) {
		g_bValidRun[client] = true;
	} else if (iZoneType == ZONETYPE_CHECKER) {
		if (!g_bValidRun[client]) {
			Command_Teleport(client, 1);
		}
	} else if (iZoneType == ZONETYPE_ANTIJUMP) {
		g_bInJump[client] = true;
	} else if (iZoneType == ZONETYPE_ANTIDUCK) {
		g_bInDuck[client] = true;
	} else if (iZoneType == ZONETYPE_MAXSPEED) {
		g_bInMaxSpeed[client] = g_mapZones[id].preSpeed;
	}

	return Plugin_Handled;
}

public Action EndTouchTrigger(int caller, int activator)
{
	int client = activator;

	// Ignore dead players
	if (!IsValidClient(client)) {
		return Plugin_Handled;
	}

	// For new speed limiter
	g_bLeftZone[activator] = true;

	// Ignore if teleporting out of the zone
	if (g_bIgnoreZone[activator])
	{
		g_bIgnoreZone[activator] = false;
		return Plugin_Handled;
	}

	// Reset Prehop Limit
	// g_bJumpedInZone[activator] = false;

	char sTargetName[256];
	GetEntPropString(caller, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));

	if (StrContains(sTargetName, "sm_ckZoneHooked") != -1)
		ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZoneHooked ", "");
	else
		ReplaceString(sTargetName, sizeof(sTargetName), "sm_ckZone ", "");

	int id = StringToInt(sTargetName);

	int iZoneType = g_mapZones[id].zoneType;
	//int iZoneTypeId = g_mapZones[id].zoneTypeId;
	int iZoneGroup = g_mapZones[id].zoneGroup;

	if (iZoneType == ZONETYPE_ANTIJUMP) {
		g_bInJump[client] = false;
	} else if (iZoneType == ZONETYPE_ANTIDUCK) {
		g_bInDuck[client] = false;
	} else if (iZoneType == ZONETYPE_MAXSPEED) {
		g_bInMaxSpeed[client] = 0.0;
	}

	if (iZoneGroup != g_iClientInZone[activator][2]
		|| iZoneType == ZONETYPE_TELETOSTART
		|| iZoneType == ZONETYPE_CHECKER
		|| iZoneType != g_iClientInZone[activator][0]
	) {
		// Ignore end touches in other zonegroups, zones that teleports away or multiple zones on top of each other // fluffys
		return Plugin_Handled;
	}

	LimitSpeed(client);
	// Set Client targetName
	if (StrEqual(g_szMapName, "surf_forgotten"))
	{
		if (!StrEqual("player", g_mapZones[g_iClientInZone[client][3]].targetName))
			DispatchKeyValue(client, "targetname", g_mapZones[g_iClientInZone[client][3]].targetName);
	}

	if (iZoneType == ZONETYPE_START || iZoneType == ZONETYPE_SPEEDSTART)
	{
		if (g_bPracticeMode[client] && !g_bTimerRunning[client]) // If on practice mode, but timer isn't on - start timer
		{
			CL_OnStartTimerPress(client);

			int speed = RoundToNearest(g_fLastSpeed[client]); // don't care to store it if it's only practice mode
			if (speed > 0)
			{
				char szSpeed[64];
				int style = g_iCurrentStyle[client];
				int recSpeed = g_iRecordMapStartSpeed[style];
				int pbSpeed = g_iPBMapStartSpeed[style][client];

				if (pbSpeed > 0) // pb speed exists
				{
					int speedDiff = speed - pbSpeed;
					if (speedDiff < 0) // slower than pb
						Format(szSpeed, 64, "PB: {darkred}%i{default} | SR: ", speedDiff);
					else if (speedDiff > 0) // faster than pb
						Format(szSpeed, 64, "PB: {green}+%i{default} | SR: ");
					else // same as pb
						Format(szSpeed, 64, "PB: 0 | SR: ");
				}
				else // pb doesn't exist
				{
					Format(szSpeed, 64, "PB: {lightgreen}N/A{default} | SR: ");
				}

				if (recSpeed > 0) // sr start speed exists
				{
					int recSpeedDiff = speed - recSpeed;
					if (recSpeedDiff < 0)// slower than server record
						Format(szSpeed, 64, "%s{darkred}%i{default}", szSpeed, recSpeedDiff);
					else if (recSpeedDiff > 0) // faster than server record
						Format(szSpeed, 64, "%s{green}+%i{default}", szSpeed, recSpeedDiff);
					else // same as server record
						Format(szSpeed, 64, "%s{default}+0", szSpeed);
				}
				else
				{
					Format(szSpeed, 64, "%s{lightgreen}N/A{default}", szSpeed);
				}

				CPrintToChat(client, "%t", "StartSpeed", g_szChatPrefix, speed, szSpeed);
			}
		}
		else if (!g_bPracticeMode[client])
		{
			g_Stage[g_iClientInZone[client][2]][client] = 1;
			lastCheckpoint[g_iClientInZone[client][2]][client] = 999;

			// NoClip check
			if (g_bNoClip[client] || (!g_bNoClip[client] && (GetGameTime() - g_fLastTimeNoClipUsed[client]) < 3.0))
			{
				CPrintToChat(client, "%t", "SurfZones1", g_szChatPrefix);
				ClientCommand(client, "play buttons\\button10.wav");
				// fluffys
				// ClientCommand(client, "sm_stuck");
			}
			else
			{
				if (g_bhasStages && g_bTimerEnabled[client])
					CL_OnStartWrcpTimerPress(client); // fluffys only start stage timer if not in prac mode

				if (g_bTimerEnabled[client])
					CL_OnStartTimerPress(client);

				g_iStartSpeed[client] = RoundToNearest(g_fLastSpeed[client]); // store it, will save it if the run is a pb
				//if (g_iStartSpeed[client] > 0)
				//	CPrintToChat(client, "%t", "StartSpeed", g_szChatPrefix, g_iStartSpeed[client]);

				int speed = g_iStartSpeed[client];
				if (speed > 0)
				{
					char szSpeed[80];
					int style = g_iCurrentStyle[client];
					int recSpeed = g_iRecordMapStartSpeed[style];
					int pbSpeed = g_iPBMapStartSpeed[style][client];

					if (pbSpeed > 0) // pb speed exists
					{
						int speedDiff = speed - pbSpeed;
						if (speedDiff < 0) // slower than pb
							Format(szSpeed, 80, "{darkred}%i{default} | {gray}SR: ", speedDiff);
						else if (speedDiff > 0) // faster than pb
							Format(szSpeed, 80, "{green}+%i{default} | {gray}SR: ", speedDiff);
						else // same as pb
							Format(szSpeed, 80, "0{default} | {gray}SR: ");
					}
					else // pb doesn't exist
					{
						Format(szSpeed, 80, "{lightgreen}N/A{default} | {gray}SR: ");
					}

					if (recSpeed > 0) // sr start speed exists
					{
						int recSpeedDiff = speed - recSpeed;
						if (recSpeedDiff < 0) // slower than server record
							Format(szSpeed, 80, "%s{darkred}%i{default}", szSpeed, recSpeedDiff);
						else if (recSpeedDiff > 0) // faster than server record
							Format(szSpeed, 80, "%s{green}+%i{default}", szSpeed, recSpeedDiff);
						else // same as server record
								Format(szSpeed, 80, "%s{default}+0", szSpeed);
					}
					else
					{
						Format(szSpeed, 80, "%s{lightgreen}N/A{default}", szSpeed);
					}

					CPrintToChat(client, "%t", "StartSpeedNew", g_szChatPrefix, speed, szSpeed);
				}
			}

			// fluffys
			if (!g_bNoClip[client])
				g_bInStartZone[client] = false;

			g_bValidRun[client] = false;
		}
	}
	else if (iZoneType == ZONETYPE_STAGE)
	{
		// targetname filters
		if (StrEqual(g_szMapName, "surf_treespam") && g_Stage[g_iClientInZone[client][2]][client] == 4)
		{
			DispatchKeyValue(client, "targetname", "s4neutral");
		}
		else if (StrEqual(g_szMapName, "surf_looksmodern"))
		{
			if (g_Stage[g_iClientInZone[client][2]][client] == 2)
				DispatchKeyValue(client, "classname", "two_1");
			else if (g_Stage[g_iClientInZone[client][2]][client] == 3)
				DispatchKeyValue(client, "classname", "threer");
			else if (g_Stage[g_iClientInZone[client][2]][client] == 4)
				DispatchKeyValue(client, "classname", "four_1");
			else if (g_Stage[g_iClientInZone[client][2]][client] == 5)
				DispatchKeyValue(client, "classname", "five_1");
		}

		g_bInStageZone[client] = false;

		if (!g_bPracticeMode[client] && g_bTimerEnabled[client])
		{
			CL_OnStartWrcpTimerPress(client);

			// not saving stage speeds yet
			int speed = RoundToNearest(g_fLastSpeed[client]);
			if (speed > 0)
				CPrintToChat(client, "%t", "StartSpeed", g_szChatPrefix, speed);
		}
	}

	// Set client location
	g_iClientInZone[client][0] = -1;
	g_iClientInZone[client][1] = -1;
	g_iClientInZone[client][2] = iZoneGroup;
	g_iClientInZone[client][3] = -1;

	return Plugin_Handled;
}

public void InitZoneVariables()
{
	g_mapZonesCount = 0;
	for (int i = 0; i < MAXZONES; i++)
	{
		g_mapZones[i].zoneId = -1;
		//g_mapZones[i].PointA = -1.0;
		g_mapZones[i].PointA[0] = -1.0;
		g_mapZones[i].PointA[1] = -1.0;
		g_mapZones[i].PointA[2] = -1.0;
		//g_mapZones[i].PointB = -1.0;
		g_mapZones[i].PointB[0] = -1.0;
		g_mapZones[i].PointB[1] = -1.0;
		g_mapZones[i].PointB[2] = -1.0;
		g_mapZones[i].zoneType = -1;
		g_mapZones[i].zoneTypeId = -1;
		g_mapZones[i].zoneGroup = -1;
		g_mapZones[i].zoneName = "";
	}
}

public void DrawBeamBox(int client) {
	BeamBox(INVALID_HANDLE, client);
	CreateTimer(1.0, BeamBox, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action BeamBox(Handle timer, int client) {
	if (IsClientInGame(client)) {
		if (g_Editing[client] == 2) {
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 1.0, 1.0, 2, 0.0, beamColorEdit, 0, true);
			return Plugin_Continue;
		}
	}
	return Plugin_Stop;
}

public Action BeamBoxAll(Handle timer, any data) {
	ThrottledBeamBoxAll(INVALID_HANDLE, 0);
}

public Action ThrottledBeamBoxAll(Handle timer, int i) {
	if (i >= g_mapZonesCount) {
		return;
	}

	int zonesToDisplay = GetConVarInt(g_hZonesToDisplay);

	bool drawForEveryone = false;
	int iZoneType = g_mapZones[i].zoneType;
	int iZoneGroup = g_mapZones[i].zoneGroup;

	switch(iZoneType) {
		case ZONETYPE_START,
			 ZONETYPE_SPEEDSTART,
			 ZONETYPE_END: {
			drawForEveryone = zonesToDisplay >= 1;
		}
		case ZONETYPE_STAGE: {
			drawForEveryone = zonesToDisplay >= 2;
		}
		default: {
			drawForEveryone = zonesToDisplay >= 3;
		}
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
		if (g_bShowZones[p]) {
			// Player has /showzones enabled
			full = true;
			draw = true;
		} else if (GetConVarInt(g_hZoneDisplayType) >= 2) {
			// Draw full box
			full = true;
		} else if (GetConVarInt(g_hZoneDisplayType) >= 1) {
			// Draw bottom only
		} else if (GetConVarInt(g_hZoneDisplayType) == 0) {
			draw = false;
		}

		if (!draw) {
			continue;
		}

		float buffer_a[3], buffer_b[3];
		for (int x = 0; x < 3; x++)
		{
			buffer_a[x] = g_mapZones[i].PointA[x];
			buffer_b[x] = g_mapZones[i].PointB[x];
		}
		TE_SendBeamBoxToClient(p, buffer_a, buffer_b, g_BeamSprite, g_HaloSprite, 0, 30, ZONE_REFRESH_TIME, 1.0, 1.0, 2, 0.0, zColor, 0, full);
	}

	CreateTimer(0.1, ThrottledBeamBoxAll, i + 1);
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
				TE_SendBeamBoxToClient(client, g_fBonusStartPos[client][1], g_fBonusStartPos[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 1.0, 1.0, 2, 0.0, beamColorEdit, 0, true);
			} else {
				TR_GetEndPosition(g_fBonusEndPos[client][1]);
				TE_SendBeamBoxToClient(client, g_fBonusEndPos[client][1], g_fBonusEndPos[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 1.0, 1.0, 2, 0.0, beamColorEdit, 0, true);
			}
		} else {
			TE_SendBeamBoxToClient(client, g_Positions[client][1], g_Positions[client][0], g_BeamSprite, g_HaloSprite, 0, 30, 0.1, 1.0, 1.0, 2, 0.0, beamColorEdit, 0, true);
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

			TE_SendBeamBoxToClient(client, fMins, fMaxs, g_BeamSprite, g_HaloSprite, 0, 30, 1.0, 1.0, 1.0, 2, 0.0, view_as<int>({255, 255, 0, 255}), 0, true);
		}
	}
}

#define WALL_BEAMBOX_OFFSET_UNITS 2.0

stock void TE_SendBeamBoxToClient(int client, float uppercorner[3], float bottomcorner[3], int ModelIndex, int HaloIndex, int StartFrame, int FrameRate, float Life, float Width, float EndWidth, int FadeLength, float Amplitude, const int Color[4], int Speed, bool full)
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
	for (int i = 0, i2 = 3; i2 >= 0; i+=i2--) {
		for(int j = 1; j <= 7; j += (j / 2) + 1) {
			if (j != 7-i) {
				if (!full && (corners[i][2] != min[2] || corners[j][2] != min[2])) continue;
				TE_SetupBeamPoints(corners[i], corners[j], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
				TE_SendToClient(client);
			}
		}
	}
}

// !zones menu starts here
public void ZoneMenu(int client)
{
	if (!IsValidClient(client))
		return;

	if (IsPlayerZoner(client))
	{
		resetSelection(client);
		Menu ckZoneMenu = new Menu(Handle_ZoneMenu);
		ckZoneMenu.SetTitle("Zones");
		ckZoneMenu.AddItem("", "Create a Zone");
		ckZoneMenu.AddItem("", "Edit Zones");
		ckZoneMenu.AddItem("", "Save Zones");
		ckZoneMenu.AddItem("", "Edit Zone Settings");
		ckZoneMenu.AddItem("", "Reload Zones");
		ckZoneMenu.ExitButton = true;
		ckZoneMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
		CPrintToChat(client, "%t", "NoZoneAccess", g_szChatPrefix);
}

public int Handle_ZoneMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Create a zone
					SelectZoneGroup(client);
				}
				case 1:
				{
					// Edit Zones
					EditZoneGroup(client);
				}
				case 2:
				{
					// Save Zones
					db_saveZones();
					resetSelection(client);
					ZoneMenu(client);
				}
				case 3:
				{
					// Edit Zone Settings
					ZoneSettings(client);
				}
				case 4:
				{
					// Reload Zones
					db_selectMapZones();
					CPrintToChat(client, "%t", "SurfZones3", g_szChatPrefix);
					resetSelection(client);
					ZoneMenu(client);
				}
			}
		}

		case MenuAction_End: delete tMenu;
	}
}

public void EditZoneGroup(int client)
{
	Menu editZoneGroupMenu = new Menu(h_editZoneGroupMenu);
	editZoneGroupMenu.SetTitle("Which zones do you want to edit?");
	editZoneGroupMenu.AddItem("1", "Normal map zones");
	editZoneGroupMenu.AddItem("2", "Bonus zones");
	editZoneGroupMenu.AddItem("3", "Misc zones");
	editZoneGroupMenu.ExitButton = true;
	editZoneGroupMenu.Display(client, MENU_TIME_FOREVER);
}

public int h_editZoneGroupMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: // Normal map zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					ListZones(client, true);
				}
				case 1: // Bonus Zones
				{
					ListBonusGroups(client);
				}
				case 2: // Misc zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					ListZones(client, false);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End: delete tMenu;
	}
}

public void ListBonusGroups(int client)
{
	Menu h_bonusGroupListing = new Menu(Handler_bonusGroupListing);
	h_bonusGroupListing.SetTitle("Available Bonuses");

	char listGroupName[256], ZoneId[64], Id[64];
	if (g_mapZoneGroupCount > 1)
	{ // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		for (int i = 1; i < g_mapZoneGroupCount; ++i)
		{
			Format(ZoneId, sizeof(ZoneId), "%s", g_szZoneGroupName[i]);
			IntToString(i, Id, sizeof(Id));
			Format(listGroupName, sizeof(listGroupName), ZoneId);
			h_bonusGroupListing.AddItem(Id, ZoneId);
		}
	}
	else
	{
		h_bonusGroupListing.AddItem("", "No Bonuses are available", ITEMDRAW_DISABLED);
	}
	h_bonusGroupListing.ExitButton = true;
	h_bonusGroupListing.Display(client, MENU_TIME_FOREVER);
}

public int Handler_bonusGroupListing(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentSelectedZoneGroup[client] = StringToInt(aID);
			ListBonusSettings(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			EditZoneGroup(client);
		}

		case MenuAction_End: delete tMenu;
	}
}

public void ListBonusSettings(int client)
{
	Menu h_ListBonusSettings = new Menu(Handler_ListBonusSettings);
	h_ListBonusSettings.SetTitle("Settings for %s", g_szZoneGroupName[g_CurrentSelectedZoneGroup[client]]);

	h_ListBonusSettings.AddItem("1", "Create a new zone");
	h_ListBonusSettings.AddItem("2", "List Zones in this group");
	h_ListBonusSettings.AddItem("3", "Rename Bonus");
	h_ListBonusSettings.AddItem("4", "Delete this group");

	h_ListBonusSettings.ExitButton = true;
	h_ListBonusSettings.Display(client, MENU_TIME_FOREVER);
}

public int Handler_ListBonusSettings(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:SelectBonusZoneType(client);
				case 1:listZonesInGroup(client);
				case 2:renameBonusGroup(client);
				case 3:checkForMissclick(client);
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ListBonusGroups(client);
		}

		case MenuAction_End: delete tMenu;
	}
}

public void checkForMissclick(int client)
{
	Menu h_checkForMissclick = new Menu(Handle_checkForMissclick);
	h_checkForMissclick.SetTitle("Delete all zones in %s?", g_szZoneGroupName[g_CurrentSelectedZoneGroup[client]]);

	h_checkForMissclick.AddItem("1", "NO");
	h_checkForMissclick.AddItem("2", "NO");
	h_checkForMissclick.AddItem("3", "YES");
	h_checkForMissclick.AddItem("4", "NO");

	h_checkForMissclick.ExitButton = true;
	h_checkForMissclick.Display(client, MENU_TIME_FOREVER);
}

public int Handle_checkForMissclick(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: ListBonusSettings(client);
				case 1: ListBonusSettings(client);
				case 2: db_deleteZonesInGroup(client);
				case 3: ListBonusSettings(client);
			}
		}

		case MenuAction_Cancel: ListBonusSettings(client);
		case MenuAction_End: delete tMenu;
	}
}

public void listZonesInGroup(int client)
{
	Menu h_listBonusZones = new Menu(Handler_listBonusZones);
	if (g_mapZoneCountinGroup[g_CurrentSelectedZoneGroup[client]] > 0)
	{ // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
		char listZoneName[256], ZoneId[64], Id[64];
		for (int i = 0; i < g_mapZonesCount; ++i)
		{
			if (g_mapZones[i].zoneGroup == g_CurrentSelectedZoneGroup[client])
			{
				Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i].zoneType], g_mapZones[i].zoneTypeId);
				IntToString(i, Id, sizeof(Id));
				Format(listZoneName, sizeof(listZoneName), ZoneId);
				h_listBonusZones.AddItem(Id, ZoneId);
			}
		}
	}
	else
	{
		h_listBonusZones.AddItem("", "No zones are available", ITEMDRAW_DISABLED);
	}
	h_listBonusZones.ExitButton = true;
	h_listBonusZones.Display(client, MENU_TIME_FOREVER);
}

public int Handler_listBonusZones(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			g_CurrentZoneType[client] = g_mapZones[g_ClientSelectedZone[client]].zoneType;
			DrawBeamBox(client);
			g_Editing[client] = 2;
			if (g_ClientSelectedZone[client] != -1)
			{
				GetClientSelectedZone(client);
			}
			EditorMenu(client);
		}
		case MenuAction_Cancel: ListBonusSettings(client);
		case MenuAction_End: delete tMenu;
	}
}

public void renameBonusGroup(int client)
{
	if (!IsValidClient(client))
		return;

	CPrintToChat(client, "%t", "SurfZones4", g_szChatPrefix);
	g_ClientRenamingZone[client] = true;
}

// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
public void SelectBonusZoneType(int client)
{
	Menu h_selectBonusZoneType = new Menu(Handler_selectBonusZoneType);
	h_selectBonusZoneType.SetTitle("Select Bonus Zone Type");

	h_selectBonusZoneType.AddItem("1", "Start");
	h_selectBonusZoneType.AddItem("2", "End");
	h_selectBonusZoneType.AddItem("3", "Stage");
	h_selectBonusZoneType.AddItem("4", "Checkpoint");

	h_selectBonusZoneType.ExitButton = true;
	h_selectBonusZoneType.Display(client, MENU_TIME_FOREVER);
}

public int Handler_selectBonusZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentZoneType[client] = StringToInt(aID);
			if (g_bEditZoneType[client]) {
				db_selectzoneTypeIds(g_CurrentZoneType[client], client, g_CurrentSelectedZoneGroup[client]);
			}
			else
				EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

// Create zone 2nd
public void SelectZoneGroup(int client)
{
	Menu newZoneGroupMenu = new Menu(h_newZoneGroupMenu);
	newZoneGroupMenu.SetTitle("Which zones do you want to create?");

	newZoneGroupMenu.AddItem("1", "Normal map zones");
	newZoneGroupMenu.AddItem("2", "Bonus zones");
	newZoneGroupMenu.AddItem("3", "Misc zones");

	newZoneGroupMenu.ExitButton = true;
	newZoneGroupMenu.Display(client, MENU_TIME_FOREVER);
}

public int h_newZoneGroupMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: // Normal map zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					SelectNormalZoneType(client);
				}
				case 1: // Bonus Zones
				{
					g_CurrentSelectedZoneGroup[client] = -1;
					StartBonusZoneCreation(client);
				}
				case 2: // Misc zones
				{
					g_CurrentSelectedZoneGroup[client] = 0;
					SelectMiscZoneType(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void StartBonusZoneCreation(int client)
{
	Menu CreateBonusFirst = new Menu(H_CreateBonusFirst);
	CreateBonusFirst.SetTitle("Create the Bonus Start Zone:");
	if (g_Editing[client] == 0)
		CreateBonusFirst.AddItem("1", "Start Drawing");
	else
	{
		CreateBonusFirst.AddItem("1", "Restart Drawing");
		CreateBonusFirst.AddItem("2", "Save Bonus Start Zone");

	}
	CreateBonusFirst.ExitButton = true;
	CreateBonusFirst.Display(client, MENU_TIME_FOREVER);
}

public int H_CreateBonusFirst(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 10;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_fBonusStartPos[client][0]);
					StartBonusZoneCreation(client);
				}
				case 1:
				{
					if (!IsValidClient(client))
						return;

					g_Editing[client] = 2;
					CPrintToChat(client, "%t", "SurfZones5", g_szChatPrefix);
					EndBonusZoneCreation(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void EndBonusZoneCreation(int client)
{
	Menu CreateBonusSecond = new Menu(H_CreateBonusSecond);
	CreateBonusSecond.SetTitle("Create the Bonus End Zone:");
	if (g_Editing[client] == 2)
		CreateBonusSecond.AddItem("1", "Start Drawing");
	else
	{
		CreateBonusSecond.AddItem("1", "Restart Drawing");
		CreateBonusSecond.AddItem("2", "Save Bonus End Zone");
	}
	CreateBonusSecond.ExitButton = true;
	CreateBonusSecond.Display(client, MENU_TIME_FOREVER);
}

public int H_CreateBonusSecond(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 11;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_fBonusEndPos[client][0]);
					EndBonusZoneCreation(client);
				}
				case 1:
				{
					g_Editing[client] = 2;
					SaveBonusZones(client);
					ZoneMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void SaveBonusZones(int client)
{
	if ((g_fBonusEndPos[client][0][0] != -1.0 && g_fBonusEndPos[client][0][1] != -1.0 && g_fBonusEndPos[client][0][2] != -1.0) || (g_fBonusStartPos[client][1][0] != -1.0 && g_fBonusStartPos[client][1][1] != -1.0 && g_fBonusStartPos[client][1][2] != -1.0))
	{
		int id2 = g_mapZonesCount + 1;
		db_insertZone(g_mapZonesCount, 1, 0, g_fBonusStartPos[client][0][0], g_fBonusStartPos[client][0][1], g_fBonusStartPos[client][0][2], g_fBonusStartPos[client][1][0], g_fBonusStartPos[client][1][1], g_fBonusStartPos[client][1][2], 0, 0, g_mapZoneGroupCount);
		db_insertZone(id2, 2, 0, g_fBonusEndPos[client][0][0], g_fBonusEndPos[client][0][1], g_fBonusEndPos[client][0][2], g_fBonusEndPos[client][1][0], g_fBonusEndPos[client][1][1], g_fBonusEndPos[client][1][2], 0, 0, g_mapZoneGroupCount);
		CPrintToChat(client, "%t", "SurfZones6", g_szChatPrefix);
	}
	else
		CPrintToChat(client, "%t", "SurfZones7", g_szChatPrefix);

	resetSelection(client);
	ZoneMenu(client);
	db_selectMapZones();
}

public void SelectNormalZoneType(int client)
{
	Menu SelectNormalZoneMenu = new Menu(Handle_SelectNormalZoneType);
	SelectNormalZoneMenu.SetTitle("Select Zone Type");
	SelectNormalZoneMenu.AddItem("1", "Start");
	SelectNormalZoneMenu.AddItem("2", "End");
	if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] == 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] == 0)
	{
		SelectNormalZoneMenu.AddItem("3", "Stage");
		SelectNormalZoneMenu.AddItem("4", "Checkpoint");
	}
	else if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] > 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] == 0)
	{
		SelectNormalZoneMenu.AddItem("3", "Stage");
	}
	else if (g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][3] == 0 && g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][4] > 0)
		SelectNormalZoneMenu.AddItem("4", "Checkpoint");

	SelectNormalZoneMenu.AddItem("hook", "Hook Zone");

	SelectNormalZoneMenu.ExitButton = true;
	SelectNormalZoneMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_SelectNormalZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			if (StrEqual(aID, "hook"))
				HookZonesMenu(client);
			else
			{
				g_CurrentZoneType[client] = StringToInt(aID);
				if (g_bEditZoneType[client])
					db_selectzoneTypeIds(g_CurrentZoneType[client], client, 0);
				else
					EditorMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ZoneSettings(int client)
{
	Menu ZoneSettingMenu = new Menu(Handle_ZoneSettingMenu);
	ZoneSettingMenu.SetTitle("Global Zone Settings");
	switch (GetConVarInt(g_hZoneDisplayType))
	{
		case 0: ZoneSettingMenu.AddItem("1", "Visible: Nothing");
		case 1: ZoneSettingMenu.AddItem("1", "Visible: Lower edges");
		case 2: ZoneSettingMenu.AddItem("1", "Visible: All sides");
	}

	switch (GetConVarInt(g_hZonesToDisplay))
	{
		case 1:	ZoneSettingMenu.AddItem("2", "Draw Zones: Start & End");
		case 2: ZoneSettingMenu.AddItem("2", "Draw Zones: Start, End, Stage, Bonus");
		case 3: ZoneSettingMenu.AddItem("2", "Draw Zones: All zones");
	}

	ZoneSettingMenu.ExitButton = true;
	ZoneSettingMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_ZoneSettingMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{

		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					if (GetConVarInt(g_hZoneDisplayType) < 2)
						SetConVarInt(g_hZoneDisplayType, (GetConVarInt(g_hZoneDisplayType) + 1));
					else
						SetConVarInt(g_hZoneDisplayType, 0);
				}
				case 1:
				{
					if (GetConVarInt(g_hZonesToDisplay) < 3)
						SetConVarInt(g_hZonesToDisplay, (GetConVarInt(g_hZonesToDisplay) + 1));
					else
						SetConVarInt(g_hZonesToDisplay, 1);
				}
			}
			CreateTimer(0.1, RefreshZoneSettings, client, TIMER_FLAG_NO_MAPCHANGE);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void SelectMiscZoneType(int client)
{
	Menu SelectZoneMenu = new Menu(Handle_SelectMiscZoneType);
	SelectZoneMenu.SetTitle("Select Misc Zone Type");

	SelectZoneMenu.AddItem("6", "TeleToStart");
	SelectZoneMenu.AddItem("7", "Validator");
	SelectZoneMenu.AddItem("8", "Checker");
	// fluffys add antijump and antiduck zones to menu
	SelectZoneMenu.AddItem("9", "AntiJump");
	SelectZoneMenu.AddItem("10", "AntiDuck");
	SelectZoneMenu.AddItem("11", "MaxSpeed");
	SelectZoneMenu.AddItem("0", "Stop");

	SelectZoneMenu.ExitButton = true;
	SelectZoneMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_SelectMiscZoneType(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[12];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_CurrentZoneType[client] = StringToInt(aID);
			if (g_bEditZoneType[client]) {
				db_selectzoneTypeIds(g_CurrentZoneType[client], client, 0);
			}
			else
				EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			SelectZoneGroup(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}
// Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0)
public int Handle_EditZoneTypeId(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char selection[12];
			GetMenuItem(tMenu, item, selection, sizeof(selection));
			g_CurrentZoneTypeId[client] = StringToInt(selection);
			EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			SelectNormalZoneType(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void ListZones(int client, bool mapzones)
{
	Menu ZoneList = new Menu(MenuHandler_ZoneModify);
	ZoneList.SetTitle("Available Zones");

	char listZoneName[256], ZoneId[64], Id[64];
	if (g_mapZonesCount > 0)
	{ // Types: Start(1), End(2), Stage(3), Checkpoint(4), Speed(5), TeleToStart(6), Validator(7), Chekcer(8), Stop(0) // fluffys AntiJump (9), AntiDuck (10)
		if (mapzones)
		{
			for (int i = 0; i < g_mapZonesCount; ++i)
			{
				if (g_mapZones[i].zoneGroup == 0 && 0 < g_mapZones[i].zoneType < 6)
				{
					// Make stages match the stage number, rather than the ID, to make it more clear for the user
					if (g_mapZones[i].zoneType == 3)
						Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i].zoneType], (g_mapZones[i].zoneTypeId + 2));
					else
						Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i].zoneType], g_mapZones[i].zoneTypeId);
					IntToString(i, Id, sizeof(Id));
					Format(listZoneName, sizeof(listZoneName), ZoneId);
					ZoneList.AddItem(Id, ZoneId);
				}
			}
		}
		else
		{
			for (int i = 0; i < g_mapZonesCount; ++i)
			{
				if (g_mapZones[i].zoneGroup == 0 && (g_mapZones[i].zoneType == 0 || g_mapZones[i].zoneType > 5))
				{
					Format(ZoneId, sizeof(ZoneId), "%s-%i", g_szZoneDefaultNames[g_mapZones[i].zoneType], g_mapZones[i].zoneTypeId);
					IntToString(i, Id, sizeof(Id));
					Format(listZoneName, sizeof(listZoneName), ZoneId);
					ZoneList.AddItem(Id, ZoneId);
				}
			}
		}
	}
	else
	{
		ZoneList.AddItem("", "No zones are available", ITEMDRAW_DISABLED);
	}
	ZoneList.ExitButton = true;
	ZoneList.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ZoneModify(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char aID[64];
			GetMenuItem(tMenu, item, aID, sizeof(aID));
			g_ClientSelectedZone[client] = StringToInt(aID);
			g_CurrentZoneType[client] = g_mapZones[g_ClientSelectedZone[client]].zoneType;
			DrawBeamBox(client);
			g_Editing[client] = 2;
			if (g_ClientSelectedZone[client] != -1)
			{
				GetClientSelectedZone(client);
			}
			EditorMenu(client);
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

/*
g_Editing:
0: Starting a new zone, not yet drawing
1: Drawing a new zone
2: Editing paused
3: Scaling zone
10: Creating bonus start
11: creating bonus end
*/

public void EditorMenu(int client)
{
	// If scaling zone
	if (g_Editing[client] == 3)
	{
		DrawBeamBox(client);
		g_Editing[client] = 2;
	}

	Menu editMenu = new Menu(MenuHandler_Editor);
	// If a zone is selected
	if (g_ClientSelectedZone[client] != -1)
		editMenu.SetTitle("Editing Zone: %s-%i", g_szZoneDefaultNames[g_CurrentZoneType[client]], g_mapZones[g_ClientSelectedZone[client]].zoneTypeId);
	else
		editMenu.SetTitle("Creating a New %s Zone", g_szZoneDefaultNames[g_CurrentZoneType[client]]);

	// If creating a completely new zone, or editing an existing one
	if (g_Editing[client] == 0)
		editMenu.AddItem("", "Start Drawing the Zone");
	else
		editMenu.AddItem("", "Restart the Zone Drawing");

	// If editing an existing zone
	if (g_Editing[client] > 0)
	{
		editMenu.AddItem("", "Set zone type");

		// If editing is paused
		if (g_Editing[client] == 2)
			editMenu.AddItem("", "Continue Editing");
		else
			editMenu.AddItem("", "Pause Editing");

		editMenu.AddItem("", "Delete Zone");
		editMenu.AddItem("", "Save Zone");

		editMenu.AddItem("", "Go to Zone");
		editMenu.AddItem("", "Stretch Zone");

		if (g_ClientSelectedZone[client] != -1)
		{
			char szMenuItem[128];
			// Hookname
			Format(szMenuItem, sizeof(szMenuItem), "Hook Name: %s", g_mapZones[g_ClientSelectedZone[client]].hookName);
			editMenu.AddItem("", szMenuItem, ITEMDRAW_DISABLED);

			// Targetname
			Format(szMenuItem, sizeof(szMenuItem), "Target Name: %s", g_mapZones[g_ClientSelectedZone[client]].targetName);
			editMenu.AddItem("", szMenuItem);

			// One jump limit
			if (g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit == 1)
				editMenu.AddItem("", "Disable One Jump Limit");
			else
				editMenu.AddItem("", "Enable One Jump Limit");

			// Prespeed
			Format(szMenuItem, sizeof(szMenuItem), "Prespeed: %.1f", g_mapZones[g_ClientSelectedZone[client]].preSpeed);
			editMenu.AddItem("", szMenuItem);
		}
	}

	editMenu.ExitButton = true;
	editMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Editor(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					// Start
					g_Editing[client] = 1;
					float pos[3], ang[3];
					GetClientEyePosition(client, pos);
					GetClientEyeAngles(client, ang);
					TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
					TR_GetEndPosition(g_Positions[client][0]);
					EditorMenu(client);
				}
				case 1: // Setting zone type
				{
					g_bEditZoneType[client] = true;
					if (g_CurrentSelectedZoneGroup[client] == 0)
						SelectNormalZoneType(client);
					else if (g_CurrentSelectedZoneGroup[client] > 0)
						SelectBonusZoneType(client);

				}
				case 2:
				{
					// Pause
					if (g_Editing[client] == 2)
					{
						g_Editing[client] = 1;
					} else {
						DrawBeamBox(client);
						g_Editing[client] = 2;
					}
					EditorMenu(client);
				}
				case 3:
				{
					// Delete
					if (g_ClientSelectedZone[client] != -1)
					{
						db_deleteZone(client, g_mapZones[g_ClientSelectedZone[client]].zoneId);
						resetZone(g_ClientSelectedZone[client]);
					}
					resetSelection(client);
					ZoneMenu(client);
				}
				case 4:
				{
					// Save
					if (g_ClientSelectedZone[client] != -1)
					{
						if (!g_bEditZoneType[client])
							db_updateZone(g_mapZones[g_ClientSelectedZone[client]].zoneId, g_mapZones[g_ClientSelectedZone[client]].zoneType, g_mapZones[g_ClientSelectedZone[client]].zoneTypeId, g_Positions[client][0], g_Positions[client][1], 0, 0, g_CurrentSelectedZoneGroup[client], g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit, g_mapZones[g_ClientSelectedZone[client]].preSpeed, g_mapZones[g_ClientSelectedZone[client]].hookName, g_mapZones[g_ClientSelectedZone[client]].targetName);
						else
							db_updateZone(g_mapZones[g_ClientSelectedZone[client]].zoneId, g_CurrentZoneType[client], g_CurrentZoneTypeId[client], g_Positions[client][0], g_Positions[client][1], 0, 0, g_CurrentSelectedZoneGroup[client], g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit, g_mapZones[g_ClientSelectedZone[client]].preSpeed, g_mapZones[g_ClientSelectedZone[client]].hookName, g_mapZones[g_ClientSelectedZone[client]].targetName);
						g_bEditZoneType[client] = false;
					}
					else
					{
						db_insertZone(g_mapZonesCount, g_CurrentZoneType[client], g_mapZonesTypeCount[g_CurrentSelectedZoneGroup[client]][g_CurrentZoneType[client]], g_Positions[client][0][0], g_Positions[client][0][1], g_Positions[client][0][2], g_Positions[client][1][0], g_Positions[client][1][1], g_Positions[client][1][2], 0, 0, g_CurrentSelectedZoneGroup[client]);
						g_bEditZoneType[client] = false;
					}
					CPrintToChat(client, "%t", "SurfZones8", g_szChatPrefix);
					resetSelection(client);
					ZoneMenu(client);
				}
				case 5:
				{
					// Teleport
					float ZonePos[3];
					surftimer_StopTimer(client);
					AddVectors(g_Positions[client][0], g_Positions[client][1], ZonePos);
					ZonePos[0] = FloatDiv(ZonePos[0], 2.0);
					ZonePos[1] = FloatDiv(ZonePos[1], 2.0);
					ZonePos[2] = FloatDiv(ZonePos[2], 2.0);

					TeleportEntity(client, ZonePos, NULL_VECTOR, NULL_VECTOR);
					EditorMenu(client);
				}
				case 6:
				{
					// Scaling
					ScaleMenu(client, 0);
				}
				case 7:
				{
					ChangeZonesHook(client);
				}
				case 8:
				{
					// Set Target Name
					g_iWaitingForResponse[client] = 5;
					CPrintToChat(client, "%t", "SurfZones9", g_szChatPrefix);
				}
				case 9:
				{
					// One jump limit
					if (g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit == 1)
						g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit = 0;
					else
						g_mapZones[g_ClientSelectedZone[client]].oneJumpLimit = 1;

					EditorMenu(client);
				}
				case 10:
				{
					// prespeed
					PrespeedMenu(client);
				}
			}
		}
		case MenuAction_Cancel:
		{
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

public void resetSelection(int client)
{
	g_CurrentSelectedZoneGroup[client] = -1;
	g_ClientSelectedZone[client] = -1;
	g_Editing[client] = 0;
	g_CurrentZoneTypeId[client] = -1;
	g_CurrentZoneType[client] = -1;
	g_bEditZoneType[client] = false;

	float resetArray[] = { -1.0, -1.0, -1.0 };
	Array_Copy(resetArray, g_Positions[client][0], 3);
	Array_Copy(resetArray, g_Positions[client][1], 3);
	Array_Copy(resetArray, g_fBonusEndPos[client][0], 3);
	Array_Copy(resetArray, g_fBonusEndPos[client][1], 3);
	Array_Copy(resetArray, g_fBonusStartPos[client][0], 3);
	Array_Copy(resetArray, g_fBonusStartPos[client][1], 3);
}

public void ScaleMenu(int client, int firstItem)
{
	g_Editing[client] = 3;
	Menu ckScaleMenu = new Menu(MenuHandler_Scale);
	ckScaleMenu.SetTitle("Stretch Zone");

	if (g_ClientSelectedPoint[client] == 1)
		ckScaleMenu.AddItem("", "Point B");
	else
		ckScaleMenu.AddItem("", "Point A");

	ckScaleMenu.AddItem("", "Width +");
	ckScaleMenu.AddItem("", "Width -");
	ckScaleMenu.AddItem("", "Length +");
	ckScaleMenu.AddItem("", "Length -");
	ckScaleMenu.AddItem("", "Height +");
	ckScaleMenu.AddItem("", "Height -");

	char ScaleSize[128];
	Format(ScaleSize, sizeof(ScaleSize), "Scale Size %.1f", g_AvaliableScales[g_ClientSelectedScale[client]]);
	ckScaleMenu.AddItem("", ScaleSize);

	ckScaleMenu.ExitButton = true;
	ckScaleMenu.DisplayAt(client, firstItem, MENU_TIME_FOREVER);
}

public int MenuHandler_Scale(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0:
				{
					if (g_ClientSelectedPoint[client] == 1)
						g_ClientSelectedPoint[client] = 0;
					else
						g_ClientSelectedPoint[client] = 1;
				}
				case 1:	g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 2: g_Positions[client][g_ClientSelectedPoint[client]][0] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][0], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 3: g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 4:	g_Positions[client][g_ClientSelectedPoint[client]][1] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][1], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 5:	g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatAdd(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 6:	g_Positions[client][g_ClientSelectedPoint[client]][2] = FloatSub(g_Positions[client][g_ClientSelectedPoint[client]][2], g_AvaliableScales[g_ClientSelectedScale[client]]);
				case 7:
				{
					++g_ClientSelectedScale[client];
					if (g_ClientSelectedScale[client] == 5)
						g_ClientSelectedScale[client] = 0;
				}
			}

			if (item < 6)
				ScaleMenu(client, 0);
			else
				ScaleMenu(client, 6);
		}

		case MenuAction_Cancel: EditorMenu(client);
		case MenuAction_End: delete tMenu;
	}
}

public void PrespeedMenu(int client)
{
	Menu menu = new Menu(MenuHandler_Prespeed);
	char szTitle[128];
	if ( g_mapZones[g_ClientSelectedZone[client]].preSpeed == 0.0)
		Format(szTitle, sizeof(szTitle), "Zone Prespeed (No Limit)");
	else
		Format(szTitle, sizeof(szTitle), "Zone Prespeed (%.1f)", g_mapZones[g_ClientSelectedZone[client]].preSpeed);
	SetMenuTitle(menu, szTitle);

	AddMenuItem(menu, "285.0", "285.0");
	AddMenuItem(menu, "300.0", "300.0");
	AddMenuItem(menu, "350.0", "350.0");
	AddMenuItem(menu, "500.0", "500.0");
	AddMenuItem(menu, "-1.0", "Custom Limit");
	AddMenuItem(menu, "-2.0", "Remove Limit");

	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_Prespeed(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char szPrespeed[32];
			GetMenuItem(tMenu, item, szPrespeed, sizeof(szPrespeed));
			float prespeed = StringToFloat(szPrespeed);
			if (prespeed == -1.0)
			{
				CPrintToChat(client, "%t", "SurfZones10", g_szChatPrefix, g_szZoneDefaultNames[g_CurrentZoneType[client]], g_mapZones[g_ClientSelectedZone[client]].zoneTypeId);
				g_iWaitingForResponse[client] = 0;
				return;
			}
			else if (prespeed == -2.0)
				g_mapZones[g_ClientSelectedZone[client]].preSpeed = 0.0;
			else
				g_mapZones[g_ClientSelectedZone[client]].preSpeed = prespeed;
			PrespeedMenu(client);
		}

		case MenuAction_Cancel: EditorMenu(client);
		case MenuAction_End: delete tMenu;
	}
}

public void ChangeZonesHook(int client)
{
	Menu menu = CreateMenu(ChangeZonesHookMenuHandler);
	SetMenuTitle(menu, "Select a trigger");

	for (int i = 0; i < GetArraySize(g_TriggerMultipleList); i++)
	{
		char szTriggerName[128];
		GetArrayString(g_TriggerMultipleList, i, szTriggerName, sizeof(szTriggerName));
		AddMenuItem(menu, szTriggerName, szTriggerName);
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ChangeZonesHookMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
		SelectTrigger(param1, param2);
	else if (action == MenuAction_Cancel)
		g_iSelectedTrigger[param1] = -1;
	else if (action == MenuAction_End)
		delete menu;
}

public void SelectTrigger(int client, int index)
{
	g_iSelectedTrigger[client] = index;
	char szTriggerName[128];
	GetArrayString(g_TriggerMultipleList, index, szTriggerName, sizeof(szTriggerName));

	Menu menu = CreateMenu(ZoneHookHandler);
	SetMenuTitle(menu, szTriggerName);

	char szParam[128];
	IntToString(index, szParam, sizeof(szParam));
	AddMenuItem(menu, szParam, "Teleport to zone");
	AddMenuItem(menu, szParam, "Hook zone");
	AddMenuItem(menu, szParam, "Back");

	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int ZoneHookHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char szTriggerIndex[128];
		GetMenuItem(menu, param2, szTriggerIndex, sizeof(szTriggerIndex));
		int index = StringToInt(szTriggerIndex);
		int iEnt = GetArrayCell(g_hTriggerMultiple, index);
		g_iSelectedTrigger[param1] = index;
		char szTriggerName[128];
		GetArrayString(g_TriggerMultipleList, index, szTriggerName, sizeof(szTriggerName));

		switch (param2)
		{
			case 0: // teleport
			{
				float position[3];
				float angles[3];
				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
				GetClientEyeAngles(param1, angles);

				CPrintToChat(param1, "%t", "TeleportingTo", g_szChatPrefix, szTriggerName, position[0], position[1], position[2]);

				teleportEntitySafe(param1, position, angles, view_as<float>( { 0.0, 0.0, -100.0 } ), true);
				SelectTrigger(param1, index);
			}
			case 1: // hook zone
			{
				float position[3], fMins[3], fMaxs[3];

				GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", position);
				GetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
				GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);


				g_mapZones[g_ClientSelectedZone[param1]].CenterPoint[0] = position[0];
				g_mapZones[g_ClientSelectedZone[param1]].CenterPoint[1] = position[1];
				g_mapZones[g_ClientSelectedZone[param1]].CenterPoint[2] = position[2];

				for (int j = 0; j < 3; j++)
				{
					fMins[j] = (fMins[j] + position[j]);
				}

				for (int j = 0; j < 3; j++)
				{
					fMaxs[j] = (fMaxs[j] + position[j]);
				}

				g_mapZones[g_ClientSelectedZone[param1]].PointA[0] = fMins[0];
				g_mapZones[g_ClientSelectedZone[param1]].PointA[1] = fMins[1];
				g_mapZones[g_ClientSelectedZone[param1]].PointA[2] = fMins[2];
				g_mapZones[g_ClientSelectedZone[param1]].PointB[0] = fMaxs[0];
				g_mapZones[g_ClientSelectedZone[param1]].PointB[1] = fMaxs[1];
				g_mapZones[g_ClientSelectedZone[param1]].PointB[2] = fMaxs[2];

				for (int j = 0; j < 3; j++)
				{
					g_fZoneCorners[g_ClientSelectedZone[param1]][0][j] = g_mapZones[g_ClientSelectedZone[param1]].PointA[j];
					g_fZoneCorners[g_ClientSelectedZone[param1]][7][j] = g_mapZones[g_ClientSelectedZone[param1]].PointB[j];
				}

				for(int j = 1; j < 7; j++)
				{
					for(int k = 0; k < 3; k++)
					{
						g_fZoneCorners[g_ClientSelectedZone[param1]][j][k] = g_fZoneCorners[g_ClientSelectedZone[param1]][((j >> (2-k)) & 1) * 7][k];
					}
				}

				g_Positions[param1][0] = fMins;
				g_Positions[param1][1] = fMaxs;

				Format(g_mapZones[g_ClientSelectedZone[param1]].hookName, sizeof(g_mapZones), szTriggerName);

				CPrintToChat(param1, "%t", "SurfZones12", g_szChatPrefix, g_szZoneDefaultNames[g_CurrentZoneType[param1]], g_mapZones[g_ClientSelectedZone[param1]].zoneTypeId, szTriggerName);
				SelectTrigger(param1, index);
			}
			case 2: // Back
			{
				g_iSelectedTrigger[param1] = -1;
				EditorMenu(param1);
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void GetClientSelectedZone(int client)
{
	if (g_ClientSelectedZone[client] != -1)
	{
		Format(g_CurrentZoneName[client], 32, "%s", g_mapZones[g_ClientSelectedZone[client]].zoneName);
		Array_Copy(g_mapZones[g_ClientSelectedZone[client]].PointA, g_Positions[client][0], 3);
		Array_Copy(g_mapZones[g_ClientSelectedZone[client]].PointB, g_Positions[client][1], 3);
	}
}

public void ClearZonesMenu(int client)
{
	Menu hClearZonesMenu = new Menu(MenuHandler_ClearZones);

	hClearZonesMenu.SetTitle("Are you sure, you want to clear all zones on this map?");
	hClearZonesMenu.AddItem("", "NO GO BACK!");
	hClearZonesMenu.AddItem("", "NO GO BACK!");
	hClearZonesMenu.AddItem("", "YES! DO IT!");

	hClearZonesMenu.Display(client, 20);
}

public int MenuHandler_ClearZones(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (item == 2)
			{
				for (int i = 0; i < MAXZONES; i++)
				{
					g_mapZones[i].zoneId = -1;
					//g_mapZones[i].PointA = -1.0;
					g_mapZones[i].PointA[0] = -1.0;
					g_mapZones[i].PointA[1] = -1.0;
					g_mapZones[i].PointA[2] = -1.0;
					//g_mapZones[i].PointB = -1.0;
					g_mapZones[i].PointB[0] = -1.0;
					g_mapZones[i].PointB[1] = -1.0;
					g_mapZones[i].PointB[2] = -1.0;
					g_mapZones[i].zoneType = -1;
					g_mapZones[i].zoneTypeId = -1;
					g_mapZones[i].zoneName = "";
				}
				g_mapZonesCount = 0;
				db_deleteMapZones();
				CPrintToChat(client, "%t", "SurfZones13", g_szChatPrefix);
				RemoveZones();
			}
			resetSelection(client);
			ZoneMenu(client);
		}
		case MenuAction_End:
		{
			delete tMenu;
		}
	}
}

stock void GetMiddleOfABox(const float vec1[3], const float vec2[3], float buffer[3])
{
	float mid[3];
	MakeVectorFromPoints(vec1, vec2, mid);
	mid[0] = mid[0] / 2.0;
	mid[1] = mid[1] / 2.0;
	mid[2] = mid[2] / 2.0;
	AddVectors(vec1, mid, buffer);
}

stock void RefreshZones()
{
	RemoveZones();
	for (int i = 0; i < g_mapZonesCount; i++)
	{
		CreateZoneEntity(i);
	}
}

stock void RemoveZones()
{
	// First remove any old zone triggers
	int iEnts = GetMaxEntities();
	char sClassName[64];
	for (int i = MaxClients; i < iEnts; i++)
	{
		if (IsValidEntity(i)
			 && IsValidEdict(i)
			 && GetEdictClassname(i, sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "trigger_multiple") != -1
			 && GetEntPropString(i, Prop_Data, "m_iName", sClassName, sizeof(sClassName))
			 && StrContains(sClassName, "sm_ckZone") != -1)
		{
			// Don't destroy hooked zone entities
			if (StrContains(sClassName, "sm_ckZoneHooked") == -1)
			{
				SDKUnhook(i, SDKHook_StartTouch, StartTouchTrigger);
				SDKUnhook(i, SDKHook_EndTouch, EndTouchTrigger);
				AcceptEntityInput(i, "Disable");
				AcceptEntityInput(i, "Kill");
			}
		}
	}
}

void resetZone(int zoneIndex)
{
	g_mapZones[zoneIndex].zoneId = -1;
	//g_mapZones[zoneIndex].PointA = -1.0;
	g_mapZones[zoneIndex].PointA[0] = -1.0;
	g_mapZones[zoneIndex].PointA[1] = -1.0;
	g_mapZones[zoneIndex].PointA[2] = -1.0;
	//g_mapZones[zoneIndex].PointB = -1.0;
	g_mapZones[zoneIndex].PointB[0] = -1.0;
	g_mapZones[zoneIndex].PointB[1] = -1.0;
	g_mapZones[zoneIndex].PointB[2] = -1.0;
	g_mapZones[zoneIndex].zoneType = -1;
	g_mapZones[zoneIndex].zoneTypeId = -1;
	g_mapZones[zoneIndex].zoneName = "";
	g_mapZones[zoneIndex].zoneGroup = 0;
}
