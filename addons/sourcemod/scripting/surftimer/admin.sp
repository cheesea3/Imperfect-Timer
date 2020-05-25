public void Admin_renameZone(int client, const char[] name)
{
	if (!IsValidClient(client))
	{
		g_ClientRenamingZone[client] = false;
		return;
	}
	// avoid unnecessary calls by checking the first cell first. If it's 0 -> \0 then negating it will make the if check pass -> return
	if (!name[0] || StrEqual(name, " ") || StrEqual(name, ""))
	{
		CPrintToChat(client, "%t", "Admin1", g_szChatPrefix);
		return;
	}
	if (strlen(name) > 128)
	{
		CPrintToChat(client, "%t", "Admin2", g_szChatPrefix);
		return;
	}
	if (StrEqual(name, "!cancel", false)) // false -> non sensitive
	{
		CPrintToChat(client, "%t", "Admin3", g_szChatPrefix);
		g_ClientRenamingZone[client] = false;
		ListBonusSettings(client);
		return;
	}
	char szZoneName[128];

	Format(szZoneName, 128, "%s", name);
	db_setZoneNames(client, szZoneName);
	g_ClientRenamingZone[client] = false;
}

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;

	g_hAdminMenu = view_as<TopMenu>(topmenu);
	TopMenuObject serverCmds = g_hAdminMenu.FindCategory(ADMINMENU_SERVERCOMMANDS);
	//AddToTopMenu(g_hAdminMenu, "sm_ckadmin", TopMenuObject_Item, TopMenuHandler2, serverCmds, "sm_ckadmin", ADMFLAG_RCON);
	g_hAdminMenu.AddItem("sm_ckadmin", TopMenuHandler2, serverCmds, "sm_ckadmin", ADMFLAG_RCON);
}

public int TopMenuHandler2(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int param, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
		Format(buffer, maxlength, "SurfTimer");

	else
		if (action == TopMenuAction_SelectOption)
		Admin_ckPanel(param, 0);
}

public Action Admin_insertMapTier(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;

	if (!IsPlayerZoner(client))
	{
		CPrintToChat(client, "%t", "NoZoneAccess", g_szChatPrefix);
		return Plugin_Handled;
	}

	if (args == 0)
	{
		CReplyToCommand(client, "%t", "Admin5", g_szChatPrefix);
		return Plugin_Handled;
	}
	else
	{
		char arg1[3];
		int tier;
		GetCmdArg(1, arg1, sizeof(arg1));
		tier = StringToInt(arg1);
		if (tier < 7 && tier > -1)
			db_insertMapTier(tier);
		else
			CPrintToChat(client, "%t", "Admin6", g_szChatPrefix);
	}
	return Plugin_Handled;
}

public Action Admin_insertSpawnLocation(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerZoner(client))
		return Plugin_Handled;

	Menu menu = new Menu(ChooseTeleSideHandler);
	menu.SetTitle("Choose side for this spawn location");
	menu.AddItem("", "Left");
	menu.AddItem("", "Right");
	menu.OptionFlags = MENUFLAG_BUTTON_EXIT;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int ChooseTeleSideHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
		InsertSpawnLocation(param1, param2);
	else if (action == MenuAction_End)
		delete menu;
}

public void InsertSpawnLocation(int client, int teleside)
{
	float SpawnLocation[3];
	float SpawnAngle[3];
	float Velocity[3];

	GetClientAbsOrigin(client, SpawnLocation);
	GetClientEyeAngles(client, SpawnAngle);
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", Velocity);

	SpawnLocation[2] += 3.0;

	if (g_bGotSpawnLocation[g_iClientInZone[client][2]][1][teleside])
	{
		db_updateSpawnLocations(SpawnLocation, SpawnAngle, Velocity, g_iClientInZone[client][2], teleside);
		CPrintToChat(client, "%t", "Admin7", g_szChatPrefix);
	}
	else
	{
		db_insertSpawnLocations(SpawnLocation, SpawnAngle, Velocity, g_iClientInZone[client][2], teleside);
		CPrintToChat(client, "%t", "SpawnAdded", g_szChatPrefix);
	}

	CPrintToChat(client, "%f : %f : %f : %i", SpawnLocation, SpawnAngle, Velocity, g_iClientInZone[client][2]);
}

public Action Admin_deleteSpawnLocation(int client, int args)
{
	if (!IsValidClient(client) || !IsPlayerZoner(client))
		return Plugin_Handled;

	if (g_bGotSpawnLocation[g_iClientInZone[client][2]][1][0] || g_bGotSpawnLocation[g_iClientInZone[client][2]][1][1])
	{
		Menu menu = new Menu(DelSpawnLocationHandler);
		menu.SetTitle("Choose side of spawn location to delete");

		if (g_bGotSpawnLocation[g_iClientInZone[client][2]][1][0])
			menu.AddItem("", "Left");
		else
			menu.AddItem("", "Left", ITEMDRAW_DISABLED);

		if (g_bGotSpawnLocation[g_iClientInZone[client][2]][1][1])
			menu.AddItem("", "Right");
		else
			menu.AddItem("", "Right", ITEMDRAW_DISABLED);

		menu.OptionFlags = MENUFLAG_BUTTON_EXIT;
		menu.Display(client, MENU_TIME_FOREVER);
	}
	else
		CPrintToChat(client, "%t", "Admin9", g_szChatPrefix);

	return Plugin_Handled;
}

public int DelSpawnLocationHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
		DelSpawnLocation(param1, param2);
	else if (action == MenuAction_End)
		delete menu;
}

public void DelSpawnLocation(int client, int teleside)
{
	if (g_bGotSpawnLocation[g_iClientInZone[client][2]][1][teleside])
	{
		db_deleteSpawnLocations(g_iClientInZone[client][2], teleside);
		CPrintToChat(client, "%t", "Admin8", g_szChatPrefix);
	}
	else
		CPrintToChat(client, "%t", "Admin9", g_szChatPrefix);
}

public Action Admin_ClearAssists(int client, int args)
{
	if (IsPlayerTimerAdmin(client))
		return Plugin_Handled;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i))
		{
			CS_SetClientAssists(i, 0);
			g_fMaxPercCompleted[0] = 0.0;
			CS_SetMVPCount(i, 0);
		}
	}

	return Plugin_Handled;
}

public Action Admin_ckPanel(int client, int args)
{
	ckAdminMenu(client);
	return Plugin_Handled;
}

public void ckAdminMenu(int client)
{
	if (!IsValidClient(client))
		return;

	if (IsPlayerTimerAdmin(client))
	{
		char szTmp[128];

		Menu adminmenu = new Menu(AdminPanelHandler);
		if (IsPlayerZoner(client))
			Format(szTmp, sizeof(szTmp), "Surftimer %s Admin Menu (full access)", VERSION);
		else
			Format(szTmp, sizeof(szTmp), "Surftimer %s Admin Menu (limited access)", VERSION);
		adminmenu.SetTitle(szTmp);

		if (!g_pr_RankingRecalc_InProgress)
			adminmenu.AddItem("[1.] Recalculate player ranks", "[1.] Recalculate player ranks");
		else
			adminmenu.AddItem("[1.] Recalculate player ranks", "[1.] Stop the recalculation");

		adminmenu.AddItem("", "", ITEMDRAW_SPACER);

		int menuItemNumber = 2;

		if (IsPlayerZoner(client))
		{
			Format(szTmp, sizeof(szTmp), "[%i.] Edit or create zones", menuItemNumber);
			adminmenu.AddItem(szTmp, szTmp);
		}
		else
		{
			Format(szTmp, sizeof(szTmp), "[%i.] Edit or create zones", menuItemNumber);
			adminmenu.AddItem(szTmp, szTmp, ITEMDRAW_DISABLED);
		}
		menuItemNumber++;

		if (g_hCvarGodMode.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Godmode  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Godmode  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hCvarNoBlock.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Noblock  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Noblock  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hAutoRespawn.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Autorespawn  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Autorespawn  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hCleanWeapons.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Strip weapons  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Strip weapons  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hcvarRestore.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Restore function  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Restore function  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hPauseServerside.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] !pause command -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] !pause command  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hGoToServer.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] !goto command  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] !goto command  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hRadioCommands.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Radio commands  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Radio commands  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		/*if (g_hAutoTimer.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Timer starts at spawn  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Timer starts at spawn  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;*/

		if (g_hReplayBot.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Replay bot  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Replay bot  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hPointSystem.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Player point system  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Player point system  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hCountry.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Player country tag  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Player country tag  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hPlayerSkinChange.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Allow custom models  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Allow custom models  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hNoClipS.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] +noclip  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] +noclip (admin/vip excluded)  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hAutoBhopConVar.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Auto bunnyhop (only surf_/bhop_ maps)  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Auto bunnyhop  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hMapEnd.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Allow map changes  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[i.] Allow map changes  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hConnectMsg.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Connect message  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Connect message  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hDisconnectMsg.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Disconnect message - Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Disconnect message - Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hInfoBot.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Info bot  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Info bot  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hAttackSpamProtection.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Attack spam protection  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Attack spam protection  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		if (g_hAllowRoundEndCvar.BoolValue)
			Format(szTmp, sizeof(szTmp), "[%i.] Allow to end the current round  -  Enabled", menuItemNumber);
		else
			Format(szTmp, sizeof(szTmp), "[%i.] Allow to end the current round  -  Disabled", menuItemNumber);
		adminmenu.AddItem(szTmp, szTmp);
		menuItemNumber++;

		adminmenu.ExitButton = true;
		adminmenu.OptionFlags = MENUFLAG_BUTTON_EXIT;
		if (g_AdminMenuLastPage[client] < 6)
			adminmenu.DisplayAt(client, 0, MENU_TIME_FOREVER);
		else
			if (g_AdminMenuLastPage[client] < 12)
				adminmenu.DisplayAt(client, 6, MENU_TIME_FOREVER);
			else
				if (g_AdminMenuLastPage[client] < 18)
					adminmenu.DisplayAt(client, 12, MENU_TIME_FOREVER);
				else
					if (g_AdminMenuLastPage[client] < 24)
						adminmenu.DisplayAt(client, 18, MENU_TIME_FOREVER);
					else
						if (g_AdminMenuLastPage[client] < 30)
							adminmenu.DisplayAt(client, 24, MENU_TIME_FOREVER);
						else
							if (g_AdminMenuLastPage[client] < 36)
								adminmenu.DisplayAt(client, 30, MENU_TIME_FOREVER);
							else
								if (g_AdminMenuLastPage[client] < 42)
									adminmenu.DisplayAt(client, 36, MENU_TIME_FOREVER);
	}
	else
	{
		CPrintToChat(client, "%t", "Admin11", g_szChatPrefix);
		return;
	}
}

public int AdminPanelHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		bool refresh = true;
		switch (param2)
		{
			case 0:
			{
				if (!g_pr_RankingRecalc_InProgress)
				{
					CPrintToChat(param1, "%t", "PrUpdateStarted", g_szChatPrefix);
					g_bManualRecalc = true;
					g_pr_Recalc_AdminID = param1;
					RefreshPlayerRankTable(MAX_PR_PLAYERS);
				}
				else
				{
					for (int i = 66; i < MAX_PR_PLAYERS; i++)
						g_bProfileRecalc[i] = false;
					g_bManualRecalc = false;
					g_pr_RankingRecalc_InProgress = false;
					CPrintToChat(param1, "%t", "StopRecalculation", g_szChatPrefix);
				}
			}

			case 2:
			{
				ZoneMenu(param1);
				refresh = false;
			}

			case 3:
			{
				if (!g_hCvarGodMode.BoolValue)
					ServerCommand("ck_godmode 1");
				else
					ServerCommand("ck_godmode 0");
			}

			case 4:
			{
				if (!g_hCvarNoBlock.BoolValue)
					ServerCommand("ck_noblock 1");
				else
					ServerCommand("ck_noblock 0");
			}

			case 5:
			{
				if (!g_hAutoRespawn.BoolValue)
					ServerCommand("ck_autorespawn 1");
				else
					ServerCommand("ck_autorespawn 0");
			}

			case 6:
			{
				if (!g_hCleanWeapons.BoolValue)
					ServerCommand("ck_clean_weapons 1");
				else
					ServerCommand("ck_clean_weapons 0");
			}

			case 7:
			{
				if (!g_hcvarRestore.BoolValue)
					ServerCommand("ck_restore 1");
				else
					ServerCommand("ck_restore 0");
			}

			case 8:
			{
				if (!g_hPauseServerside.BoolValue)
					ServerCommand("ck_pause 1");
				else
					ServerCommand("ck_pause 0");
			}

			case 9:
			{
				if (!g_hGoToServer.BoolValue)
					ServerCommand("ck_goto 1");
				else
					ServerCommand("ck_goto 0");
			}

			case 10:
			{
				if (!g_hRadioCommands.BoolValue)
					ServerCommand("ck_use_radio 1");
				else
					ServerCommand("ck_use_radio 0");
			}

			case 11:
			{
				if (!g_hReplayBot.BoolValue)
					ServerCommand("ck_replay_bot 1");
				else
					ServerCommand("ck_replay_bot 0");
			}

			case 12:
			{
				if (!g_hPointSystem.BoolValue)
					ServerCommand("ck_point_system 1");
				else
					ServerCommand("ck_point_system 0");
			}

			case 13:
			{
				if (!g_hCountry.BoolValue)
					ServerCommand("ck_country_tag 1");
				else
					ServerCommand("ck_country_tag 0");
			}

			case 14:
			{
				if (!g_hPlayerSkinChange.BoolValue)
					ServerCommand("ck_custom_models 1");
				else
					ServerCommand("ck_custom_models 0");
			}

			case 15:
			{
				if (!g_hNoClipS.BoolValue)
					ServerCommand("ck_noclip 1");
				else
					ServerCommand("ck_noclip 0");
			}

			case 16:
			{
				if (!g_hAutoBhopConVar.BoolValue)
					ServerCommand("ck_auto_bhop 1");
				else
					ServerCommand("ck_auto_bhop 0");
			}

			case 17:
			{
				if (!g_hMapEnd.BoolValue)
					ServerCommand("ck_map_end 1");
				else
					ServerCommand("ck_map_end 0");
			}

			case 18:
			{
				if (!g_hConnectMsg.BoolValue)
					ServerCommand("ck_connect_msg 1");
				else
					ServerCommand("ck_connect_msg 0");
			}

			case 19:
			{
				if (!g_hDisconnectMsg.BoolValue)
					ServerCommand("ck_disconnect_msg 1");
				else
					ServerCommand("ck_disconnect_msg 0");
			}

			case 20:
			{
				if (!g_hInfoBot.BoolValue)
					ServerCommand("ck_info_bot 1");
				else
					ServerCommand("ck_info_bot 0");
			}

			case 21:
			{
				if (!g_hAttackSpamProtection.BoolValue)
					ServerCommand("ck_attack_spam_protection 1");
				else
					ServerCommand("ck_attack_spam_protection 0");
			}

			case 22:
			{
				if (!g_hAllowRoundEndCvar.BoolValue)
					ServerCommand("ck_round_end 1");
				else
					ServerCommand("ck_round_end 0");
			}
		}

		g_AdminMenuLastPage[param1] = param2;
		delete menu;

		if (refresh)
			CreateTimer(0.1, RefreshAdminMenu, param1, TIMER_FLAG_NO_MAPCHANGE);
	}

	if (action == MenuAction_End)
	{
		// Test
		if (IsValidClient(param1))
		{
			delete menu;
		}
	}
}

public Action Admin_RefreshProfile(int client, int args)
{
	if (!IsPlayerTimerAdmin(client))
		return Plugin_Handled;

	if (args == 0)
	{
		CReplyToCommand(client, "%t", "Admin12", g_szChatPrefix);
		return Plugin_Handled;
	}
	if (args > 0)
	{
		char szSteamID[128];
		char szArg[128];
		Format(szSteamID, 128, "");
		for (int i = 1; i < 6; i++)
		{
			GetCmdArg(i, szArg, 128);
			if (!StrEqual(szArg, "", false))
				Format(szSteamID, 128, "%s%s", szSteamID, szArg);
		}
		RecalcPlayerRank(client, szSteamID);
	}
	return Plugin_Handled;
}
