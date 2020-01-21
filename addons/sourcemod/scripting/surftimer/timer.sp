public Action reloadRank(Handle timer, any client)
{
	if (IsValidClient(client))
		SetPlayerRank(client);
	return Plugin_Handled;
}

public Action AnnounceMap(Handle timer, any client)
{
	if (IsValidClient(client))
		CPrintToChat(client, "%t", "Timer1", g_szChatPrefix, g_sTierString);

	AnnounceTimer[client] = null;
	return Plugin_Handled;
}

public Action RefreshAdminMenu(Handle timer, any client)
{
	if (IsValidEntity(client) && !IsFakeClient(client))
		ckAdminMenu(client);

	return Plugin_Handled;
}

public Action RefreshZoneSettings(Handle timer, any client)
{
	if (IsValidEntity(client) && !IsFakeClient(client))
		ZoneSettings(client);

	return Plugin_Handled;
}

public Action SetPlayerWeapons(Handle timer, any client)
{
	if ((GetClientTeam(client) > 1) && IsValidClient(client))
	{
		StripAllWeapons(client);
		if (!IsFakeClient(client))
			GivePlayerItem(client, "weapon_usp_silencer");
		int weapon;
		weapon = GetPlayerWeaponSlot(client, 2);
		if (weapon != -1 && !IsFakeClient(client))
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", weapon);
	}

	return Plugin_Handled;
}

public Action PlayerRanksTimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;
		db_GetPlayerRank(i);
	}
	return Plugin_Continue;
}

// Recounts players time
public Action UpdatePlayerProfile(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int style = pack.ReadCell();

	if (IsValidClient(client) && !IsFakeClient(client))
		db_updateStat(client, style);

	return Plugin_Handled;
}

public Action StartTimer(Handle timer, any client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
		CL_OnStartTimerPress(client);

	return Plugin_Handled;
}

public Action AttackTimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;

		if (g_AttackCounter[i] > 0)
		{
			if (g_AttackCounter[i] < 5)
				g_AttackCounter[i] = 0;
			else
				g_AttackCounter[i] = g_AttackCounter[i] - 5;
		}
	}
	return Plugin_Continue;
}

public Action CKTimer1(Handle timer)
{
	if (g_bRoundEnd)
		return Plugin_Continue;
	int client;
	for (client = 1; client <= MaxClients; client++)
	{
		if (IsValidClient(client))
		{
			if (IsPlayerAlive(client))
			{
				// 1st team join + in-game
				if (g_bFirstTeamJoin[client])
				{
					g_bFirstTeamJoin[client] = false;
					CreateTimer(10.0, WelcomeMsgTimer, client, TIMER_FLAG_NO_MAPCHANGE);
					CreateTimer(70.0, HelpMsgTimer, client, TIMER_FLAG_NO_MAPCHANGE);
				}
				GetcurrentRunTime(client);

				CenterHudAlive(client);
				MovementCheck(client);
			}
			else
				CenterHudDead(client);
		}
	}
	return Plugin_Continue;
}

public Action DelayedStuff(Handle timer)
{
	if (FileExists("cfg/sourcemod/surftimer/main.cfg"))
		ServerCommand("exec sourcemod/surftimer/main.cfg");
	else
		SetFailState("<surftimer> cfg/sourcemod/surftimer/main.cfg not found.");

	return Plugin_Handled;
}

public Action LoadReplaysTimer (Handle timer)
{
	LoadReplays();
	LoadInfoBot();
	return Plugin_Handled;
}

public Action CKTimer2(Handle timer)
{
	if (g_bRoundEnd)
		return Plugin_Continue;

	if (g_hMapEnd.BoolValue)
	{
		ConVar hTmp = FindConVar("mp_timelimit");
		int iTimeLimit;
		iTimeLimit = hTmp.IntValue;
		// Emergency reset timelimit if it's 0
		if (iTimeLimit == 0)
		{
			hTmp.SetInt(30, true);
			ServerCommand("mp_roundtime 30");
			GameRules_SetProp("m_iRoundTime", 1800, 4, 0, true);
		}
		if (hTmp != null)
			delete hTmp;
		if (iTimeLimit > 0)
		{
			int timeleft;
			GetMapTimeLeft(timeleft);
			switch (timeleft)
			{
				case 1800: CPrintToChatAll("%t", "TimeleftMinutes", g_szChatPrefix, g_szMapName, timeleft / 60);
				case 1200: CPrintToChatAll("%t", "TimeleftMinutes", g_szChatPrefix, g_szMapName, timeleft / 60);
				case 600: CPrintToChatAll("%t", "TimeleftMinutes", g_szChatPrefix, g_szMapName, timeleft / 60);
				case 300: CPrintToChatAll("%t", "TimeleftMinutes", g_szChatPrefix, g_szMapName, timeleft / 60);
				case 120: CPrintToChatAll("%t", "TimeleftMinutes", g_szChatPrefix, g_szMapName, timeleft / 60);
				case 60: CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, timeleft);
				case 30: CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, timeleft);
				case 15: CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, 15);
				case 3: CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, 3);
				case 2: CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, 2);
				case 1:
				{
					CPrintToChatAll("%t", "TimeleftCounter", g_szChatPrefix, 1);
					//ServerCommand("mp_ignore_round_win_conditions 0; mp_maxrounds 1");
					//CreateTimer(1.0, Timer_RetryPlayers, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
					//CreateTimer(1.1, ForceNextMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);
				}
			}

			if (timeleft <= -1)
			{
				g_bRoundEnd = true;
				ServerCommand("mp_match_end_restart 0"); // just in case
				char szNextMap[128];
				GetNextMap(szNextMap, 128);
				CPrintToChatAll("%t", "Timer2", g_szChatPrefix, szNextMap);
				CS_TerminateRound(16.0, CSRoundEnd_Draw, true);
				return Plugin_Continue;
			}

			if (timeleft == 60 || timeleft == 30 || timeleft == 15)
			{
				char szNextMap[128];
				GetNextMap(szNextMap, 128);
				CPrintToChatAll("%t", "Timer2", g_szChatPrefix, szNextMap);
			}
		}
	}

	// info bot name
	SetInfoBotName(g_InfoBot);

	int i;
	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i) || i == g_InfoBot)
			continue;

		// overlay check
		if (g_bOverlay[i] && GetGameTime() - g_fLastOverlay[i] > 5.0)
			g_bOverlay[i] = false;

		// stop replay to prevent server crashes because of a massive recording array (max. 2h)
		if (g_hRecording[i] != null && g_fCurrentRunTime[i] > 6720.0)
		{
			StopRecording(i);
		}

		SetClanTag(i);

		if (IsPlayerAlive(i))
		{
			// spec hud
			if (g_bSpecListOnly[i])
				SpecListMenuAlive(i);
			else if (g_bSideHud[i])
				SideHudAlive(i);

			// Last Cords & Angles
			GetClientAbsOrigin(i, g_fPlayerCordsLastPosition[i]);
			GetClientEyeAngles(i, g_fPlayerAnglesLastPosition[i]);
		}
		else
			SpecListMenuDead(i);
	}

	// clean weapons on ground
	int maxEntities;
	maxEntities = GetMaxEntities();
	char classx[20];
	if (g_hCleanWeapons.BoolValue)
	{
		int j;
		for (j = MaxClients + 1; j < maxEntities; j++)
		{
			if (IsValidEdict(j) && (GetEntDataEnt2(j, g_ownerOffset) == -1))
			{
				GetEdictClassname(j, classx, sizeof(classx));
				if ((StrContains(classx, "weapon_") != -1) || (StrContains(classx, "item_") != -1))
				{
					AcceptEntityInput(j, "Kill");
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action ReplayTimer(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidClient(client) && !IsFakeClient(client))
		SaveRecording(client, 0, 0);
	else
		g_bNewReplay[client] = false;


	return Plugin_Handled;
}

public Action BonusReplayTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int zGrp = pack.ReadCell();

	if (IsValidClient(client) && !IsFakeClient(client))
		SaveRecording(client, zGrp, 0);
	else
		g_bNewBonus[client] = false;


	return Plugin_Handled;
}

public Action StyleReplayTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int style = pack.ReadCell();

	if (IsValidClient(client) && !IsFakeClient(client))
		SaveRecording(client, 0, style);
	else
		g_bNewReplay[client] = false;

	return Plugin_Handled;
}

public Action StyleBonusReplayTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int zGrp = pack.ReadCell();
	int style = pack.ReadCell();

	if (IsValidClient(client) && !IsFakeClient(client))
		SaveRecording(client, zGrp, style);
	else
		g_bNewBonus[client] = false;


	return Plugin_Handled;
}

static char oldTags[MAXPLAYERS][128];
void SetClanTag(int client) {
	if (!IsValidClient(client) || IsFakeClient(client))
		return;

	SetPlayerRank(client);

	char tag[128] = "";
	bool announce = false;
	PlayerLoadState playerState = GetPlayerLoadState(client);
	if (playerState == PLS_PENDING) {
		strcopy(tag, sizeof(tag), "WAITING");
	} else if (playerState == PLS_LOADING) {
		Format(tag, sizeof(tag), "LOAD %i/%i", GetPlayerLoadStep(client), GetPlayerLoadStepMax());
	} else if (playerState != PLS_LOADED) {
		Format(tag, sizeof(tag), "ERROR %i/%i", GetPlayerLoadStep(client), GetPlayerLoadStepMax());
	} else if (!StrEqual(g_pr_rankname[client], "")) {
		strcopy(tag, sizeof(tag), g_pr_rankname[client]);
		ReplaceString(tag, sizeof(tag), "{style}", "");
		announce = true;
	}

	bool changed = false;
	if (!StrEqual(oldTags[client], tag)) {
		strcopy(oldTags[client], sizeof(oldTags[]), tag);
		changed = true;
	}

	if (!StrEqual(tag, "")) {
		if (changed && announce) {
			CPrintToChat(client, "%t", "SkillGroup", g_szChatPrefix, g_pr_chat_coloredrank[client]);
		}
		if (strlen(tag) <= 10) {
			Format(tag, sizeof(tag), "[%s]", tag);
		}
		CS_SetClientClanTag(client, tag);
	} else {
		CS_SetClientClanTag(client, "");
	}
}

public Action Timer_RetryPlayers(Handle hTimer) {
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			ClientCommand(i, "retry");
			LogMessage("Sending retry to %N", i);
		}
	}
	return Plugin_Stop;
}

public Action ForceNextMap(Handle timer) {
	char szNextMap[128];
	GetNextMap(szNextMap, 128);
	if (IsMapValid(szNextMap))  {
		ForceChangeLevel(szNextMap, "Map Time Ended");
	} else {
		ForceChangeLevel("surf_progress", "Map Time Ended");
	}
	return Plugin_Handled;
}

public Action WelcomeMsgTimer(Handle timer, any client)
{
	char szBuffer[512];
	g_hWelcomeMsg.GetString(szBuffer, 512);
	if (IsValidClient(client) && !IsFakeClient(client) && szBuffer[0])
		CPrintToChat(client, "%s", szBuffer);

	return Plugin_Handled;
}

public Action HelpMsgTimer(Handle timer, any client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
		CPrintToChat(client, "%t", "HelpMsg", g_szChatPrefix);
	return Plugin_Handled;
}

public Action AdvertTimer(Handle timer)
{
	g_Advert++;
	if ((g_Advert % 2) == 0)
	{
		if (g_bhasBonus)
		{
			CPrintToChatAll("%t", "AdvertBonus", g_szChatPrefix);
		}
		else if (g_bhasStages)
		{
			CPrintToChatAll("%t", "AdvertWRCP", g_szChatPrefix);
		}
	}
	else
	{
		if (g_bhasStages)
		{
			CPrintToChatAll("%t", "AdvertWRCP", g_szChatPrefix);
		}
		else if (g_bhasBonus)
		{
			CPrintToChatAll("%t", "AdvertBonus", g_szChatPrefix);
		}
	}
	return Plugin_Continue;
}

public Action CenterMsgTimer(Handle timer, any client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		if (g_bRestorePositionMsg[client])
		{
			g_fLastOverlay[client] = GetGameTime();
			g_bOverlay[client] = true;
			// fluffys
			// PrintHintText(client, "%t", "PositionRestored");
		}
		g_bRestorePositionMsg[client] = false;
	}

	return Plugin_Handled;
}

public Action RemoveRagdoll(Handle timer, any victim)
{
	if (IsValidEntity(victim) && !IsPlayerAlive(victim))
	{
		int player_ragdoll;
		player_ragdoll = GetEntDataEnt2(victim, g_ragdolls);
		if (player_ragdoll != -1)
			RemoveEdict(player_ragdoll);
	}
	return Plugin_Handled;
}

public Action HideHud(Handle timer, any client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		SetEntPropEnt(client, Prop_Send, "m_bSpotted", 0);

		// ViewModel
		Client_SetDrawViewModel(client, g_bViewModel[client]);

		// Crosshair and Chat
		if (g_bViewModel[client])
		{
			// Display
			if (!g_bHideChat[client])
				SetEntProp(client, Prop_Send, "m_iHideHUD", HIDE_RADAR);
			else
				SetEntProp(client, Prop_Send, "m_iHideHUD", HIDE_RADAR | HIDE_CHAT);

		}
		else
		{
			// Hiding
			if (!g_bHideChat[client])
				SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR | HIDE_CROSSHAIR);
			else
				SetEntProp(client, Prop_Send, "m_iHideHUD", GetEntProp(client, Prop_Send, "m_iHideHUD") | HIDE_RADAR | HIDE_CHAT | HIDE_CROSSHAIR);
		}
	}
	return Plugin_Handled;
}

public Action LoadPlayerSettings(Handle timer)
{
	for (int c = 1; c <= MaxClients; c++)
	{
		if (IsValidClient(c))
			OnClientPutInServer(c);
	}
	return Plugin_Handled;
}

// fluffys
public Action StartJumpZonePrintTimer(Handle timer, any client)
{
	g_bJumpZoneTimer[client] = false;
	return Plugin_Handled;
}


public Action Block2Unload(Handle timer, any client)
{
	ServerCommand("sm plugins unload block2");
}

public Action Block2Load(Handle timer, any client)
{
	ServerCommand("sm plugins load block2");
}

// Replay Bot Fixes

public Action FixBot_Off(Handle timer)
{
	ServerCommand("ck_replay_bot 0");
	ServerCommand("ck_bonus_bot 0");
	ServerCommand("ck_wrcp_bot 0");
	return Plugin_Handled;
}

public Action FixBot_On(Handle timer)
{
	ServerCommand("ck_replay_bot 1");
	ServerCommand("ck_bonus_bot 1");
	ServerCommand("ck_wrcp_bot 1");
	return Plugin_Handled;
}

public Action PlayTimeTimer(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && !IsFakeClient(i) && IsClientInGame(i))
		{
			int team = GetClientTeam(i);

			if (team == 2 || team == 3)
			{
				g_iPlayTimeAliveSession[i]++;
			}
			else
			{
				g_iPlayTimeSpecSession[i]++;
			}
		}
	}
}

public Action AnnouncementTimer(Handle timer)
{
	if (g_bHasLatestID)
		db_checkAnnouncements();

	return Plugin_Continue;
}

public Action CenterSpeedDisplayTimer(Handle timer, any client)
{
	if (IsValidClient(client) && !IsFakeClient(client) && g_bCenterSpeedDisplay[client])
	{
		char szSpeed[128];
		if (IsPlayerAlive(client))
			Format(szSpeed, sizeof(szSpeed), "%i", RoundToNearest(g_fLastSpeed[client]));
		else if (g_SpecTarget[client] != -1)
			Format(szSpeed, sizeof(szSpeed), "%i", RoundToNearest(g_fLastSpeed[g_SpecTarget[client]]));

		ShowHudText(client, 2, szSpeed);
	}
	else
		return Plugin_Stop;

	return Plugin_Continue;
}

public Action SetArmsModel(Handle timer, any client)
{
	if (IsValidClient(client) && IsPlayerAlive(client))
	{
		char szBuffer[256];
		g_hArmModel.GetString(szBuffer, 256);
		SetEntPropString(client, Prop_Send, "m_szArmsModel", szBuffer);
	}
}

public Action SpecBot(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int bot = pack.ReadCell();

	ChangeClientTeam(client, 1);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
	g_bWrcpTimeractivated[client] = false;

	return Plugin_Handled;
}

public Action RestartPlayer(Handle timer, any client)
{
	if (IsValidClient(client))
		Command_Restart(client, 1);
}