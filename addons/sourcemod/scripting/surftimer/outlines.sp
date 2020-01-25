public void CreateOutlineCommands()
{
	RegConsoleCmd("sm_outliner", Command_Outlines, "[surftimer] [Zoner] Open the outlines menu");
	RegConsoleCmd("sm_outlines", Command_ToggleOutlines, "[surftimer] Toggle the visibility of outlines");
	RegConsoleCmd("sm_hookoutline", Command_CreateOutlineHook, "[surftimer] [Zoner] Hook an entity for outline creation");
}

public Action Command_Outlines(int client, int args)
{
	if (!IsPlayerZoner(client))
		return Plugin_Handled;

	OutlineMenu(client);
	return Plugin_Handled;
}

// creates outline based on entity properties, uses index as arg
public Action Command_CreateOutlineHook(int client, int args)
{
	if (!IsPlayerZoner(client))
		return Plugin_Handled;

	char arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (!arg1[0])
		return Plugin_Handled;

	int iEnt = StringToInt(arg1);

	if (!IsValidEntity(iEnt))
	{
		CPrintToChat(client, "Entity %i is invalid!", iEnt);
		return Plugin_Handled;
	}

	g_iOutlineStyle[client] = OUTLINE_STYLE_HOOK;

	// preview the outline box
	float origin[3], mins[3], maxs[3], angles[3];
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(iEnt, Prop_Send, "m_angRotation", angles);
	Effect_DrawBeamBoxRotatableToClient(client, origin, mins, maxs, angles, g_BeamSprite, g_HaloSprite, 0, 30, 15.0, 1.0, 1.0, 1, 1.0, view_as<int>({ 255, 255, 0, 255}), 0);

	Menu createOutlineHook = new Menu(Handle_CreateOutlineHook);
	createOutlineHook.SetTitle("Outline Hook Creation\nVerify the outline before saving!\n");
	createOutlineHook.AddItem("", "Save");
	createOutlineHook.ExitButton = true;
	createOutlineHook.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int Handle_CreateOutlineHook(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			// saving
			if (item == 0 && g_iOutlineStyle[client] == OUTLINE_STYLE_HOOK)
			{
				// we save hooks to the box array
				g_outlineBoxes[g_iOutlineBoxCount].Set(g_szMapName, g_iTotalOutlines, 1, g_fOutlineStartPos[client], g_fOutlineEndPos[client]);
				DB_InsertOutline(g_outlineBoxes[g_iOutlineBoxCount]);
				g_iOutlineBoxCount++;
				g_iTotalOutlines++;
			}
		}

		default:
		{
			g_iOutlineStyle[client] = OUTLINE_STYLE_LINE;
			delete tMenu;
		}
	}
}

public Action Command_ToggleOutlines(int client, int args)
{
	// prevent spam
	if (!CommandSpamCheck(client))
		return Plugin_Handled;

	g_players[client].outlines = !g_players[client].outlines;

	if (g_players[client].outlines)
		CPrintToChat(client, "%t", "OutlinesEnabled", g_szChatPrefix);
	else
		CPrintToChat(client, "%t", "OutlinesDisabled", g_szChatPrefix);

	return Plugin_Handled;
}

public void OutlineMenu(int client)
{
	if (!IsValidClient(client))
		return;

	if (IsPlayerZoner(client))
	{
		resetSelection(client);
		Menu outlineMenu = new Menu(Handle_OutlineMenu);
		outlineMenu.SetTitle("Outlines");
		outlineMenu.AddItem("", "Create Outlines");
		outlineMenu.AddItem("", "Delete Outlines");

		if (g_hShowOutlines.BoolValue)
			outlineMenu.AddItem("", "Hide Outlines");
		else
			outlineMenu.AddItem("", "Show Outlines");

		outlineMenu.ExitButton = true;
		outlineMenu.Display(client, MENU_TIME_FOREVER);
	}
	else
		CPrintToChat(client, "%t", "NoZoneAccess", g_szChatPrefix);
}

public int Handle_OutlineMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (item)
			{
				case 0: CreateOutlineMenu(client); // create new outlines
				//case 1: EditOutlineGroup(client); // edit existing outlines - @todo: IMPLEMENT
				case 2: // toggle outlines globally
				{
					SetConVarBool(g_hShowOutlines, !g_hShowOutlines.BoolValue);
					OutlineMenu(client);
				}
			}
		}

		case MenuAction_End: delete tMenu;
	}
}

public void CreateOutlineMenu(int client)
{
	if (!IsValidClient(client))
		return;

	Menu createOutlineMenu = new Menu(Handle_CreateOutlineMenu);
	createOutlineMenu.SetTitle("Select outline style");
	createOutlineMenu.AddItem("", "Line");
	createOutlineMenu.AddItem("", "Box");

	createOutlineMenu.ExitButton = true;
	createOutlineMenu.Display(client, MENU_TIME_FOREVER);
}

public int Handle_CreateOutlineMenu(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iOutlineStyle[client] = item;
			StartOutlineCreation(client); // item == 0: line creation, 1: box creation, 2: hook
		}

		case MenuAction_Cancel:
		{
			OutlineMenu(client);
		}

		case MenuAction_End: delete tMenu;
	}

	delete tMenu;
}

public void StartOutlineCreation(int client)
{
	if (!IsValidClient(client))
		return;

	Menu createOutline = new Menu(Handle_CreateOutline);
	createOutline.SetTitle("Outline Creation\nLeft click to place start position\nRight click to place end position\n");
	g_bCreatingOutline[client] = true;
	createOutline.AddItem("", "Reset");
	createOutline.AddItem("", "Save");
	//createOutline.ExitButton = true;
	createOutline.Display(client, MENU_TIME_FOREVER);
}

public int Handle_CreateOutline(Handle tMenu, MenuAction action, int client, int item)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			// reset
			if (item == 0)
			{
				g_bStartPointPlaced[client] = false;
				g_bEndPointPlaced[client] = false;
				StartOutlineCreation(client);
			}

			// saving
			if (item == 1 && g_bStartPointPlaced[client] && g_bStartPointPlaced[client])
			{
				if (g_iOutlineStyle[client] == OUTLINE_STYLE_LINE) // line
				{
					g_outlineLines[g_iOutlineLineCount].Set(g_szMapName, g_iTotalOutlines, 0, g_fOutlineStartPos[client], g_fOutlineEndPos[client]);
					DB_InsertOutline(g_outlineLines[g_iOutlineLineCount]);
					g_iOutlineLineCount++;
					g_iTotalOutlines++;
				}
				else if (g_iOutlineStyle[client] == OUTLINE_STYLE_BOX) // box
				{
					g_outlineBoxes[g_iOutlineBoxCount].Set(g_szMapName, g_iTotalOutlines, 1, g_fOutlineStartPos[client], g_fOutlineEndPos[client]);
					DB_InsertOutline(g_outlineBoxes[g_iOutlineBoxCount]);
					g_iOutlineBoxCount++;
					g_iTotalOutlines++;
				}

				g_bCreatingOutline[client] = false;
				g_bStartPointPlaced[client] = false;
				g_bEndPointPlaced[client] = false;
				OutlineMenu(client);
			}
		}
		case MenuAction_Cancel:
		{
			g_bCreatingOutline[client] = false;
			g_bStartPointPlaced[client] = false;
			g_bEndPointPlaced[client] = false;
			g_iOutlineStyle[client] = OUTLINE_STYLE_LINE;
			OutlineMenu(client);
		}
		case MenuAction_End:
		{
			g_bCreatingOutline[client] = false;
			g_bStartPointPlaced[client] = false;
			g_bEndPointPlaced[client] = false;
			g_iOutlineStyle[client] = OUTLINE_STYLE_LINE;
			OutlineMenu(client);
		}
	}

	delete tMenu;
}