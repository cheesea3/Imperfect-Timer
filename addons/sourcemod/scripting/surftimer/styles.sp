
void CreateStyleCommands()
{
	RegConsoleCmd("sm_style", Client_SelectStyle, "[surftimer] Open style select menu");
	RegConsoleCmd("sm_styles", Client_SelectStyle, "[surftimer] Open style select menu");
	RegConsoleCmd("sm_normal", Client_SetStyleNormal, "[surftimer] Switch to the normal surf style");
	RegConsoleCmd("sm_nrm", Client_SetStyleNormal, "[surftimer] Switch to the normal surf style");
	RegConsoleCmd("sm_sideways", Client_SetStyleSideways, "[surftimer] Switch to the sideways surf style");
	RegConsoleCmd("sm_sw", Client_SetStyleSideways, "[surftimer] Switch to the sideways surf style");
	RegConsoleCmd("sm_halfsideways", Client_SetStyleHalfSideways, "[surftimer] Switch to the half-sideways surf style");
	RegConsoleCmd("sm_hsw", Client_SetStyleHalfSideways, "[surftimer] Switch to the half-sideways surf style");
	RegConsoleCmd("sm_backwards", Client_SetStyleBackwards, "[surftimer] Switch to the backwards surf style");
	RegConsoleCmd("sm_bw", Client_SetStyleBackwards, "[surftimer] Switch to the backwards surf style");
	RegConsoleCmd("sm_fastforward", Client_SetStyleFastForward, "[surftimer] Switch to the fast forwards surf style");
	RegConsoleCmd("sm_slowmotion", Client_SetStyleSlomo, "[surftimer] Switch to the slow motion surf style");
	RegConsoleCmd("sm_slowmo", Client_SetStyleSlomo, "[surftimer] Switch to the slow motion surf style");
	RegConsoleCmd("sm_slw", Client_SetStyleSlomo, "[surftimer] Switch to the slow motion surf style");
	RegConsoleCmd("sm_lowgravity", Client_SetStyleLowGrav, "[surftimer] Switch to the low gravity surf style");
	RegConsoleCmd("sm_lowgrav", Client_SetStyleLowGrav, "[surftimer] Switch to the low gravity surf style");
	RegConsoleCmd("sm_lg", Client_SetStyleLowGrav, "[surftimer] Switch to the low gravity surf style");
	RegConsoleCmd("sm_wo", Client_SetStyleWOnly, "[surftimer] Switch to the W only surf style");
	RegConsoleCmd("sm_wonly", Client_SetStyleWOnly, "[surftimer] Switch to the W only surf style");
}

// set the style for a player
void SetStyle(int client, int style)
{
    if (style > 7 || style < 0 || style == g_players[client].currentStyle)
        return;

    g_players[client].currentStyle = style;
    g_players[client].initialStyle = style;
    SetPlayerStyleText(client, style);

    // normal, sw, hsw & bw are ranked
    if (style < 4)
    {
        g_players[client].isRankedStyle = true;
        g_players[client].isFunStyle = false;

        // reset view to first person if in angle surf
        if (g_players[client].thirdPerson)
        {
            g_players[client].thirdPerson = false;
            ClientCommand(client, "firstperson");
        }
    }
    else
    {
        g_players[client].isFunStyle = true;
        g_players[client].isRankedStyle = false;
    }

    SetPlayerStyleProperties(client, style);
    Command_Restart(client, 1); // finished, so restart
}

// Set the style properties for the player
stock void SetPlayerStyleProperties(int client, int style)
{
    switch (style)
    {
        case STYLE_LOWGRAV: 	SetEntityGravity(client, 0.5); // low gravity
        case STYLE_SLOMO: 		SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.5); // slow motion
        case STYLE_FASTFORWARD: SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.5); // fast forward

        // ranked styles
        default:
        {
            SetEntityGravity(client, 1.0);
            SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
        }
    }
}

// sets style text for player
stock void SetPlayerStyleText(int client, int style)
{
    if (style > 7 || style < 0)
        return;

    switch (style)
    {
        case STYLE_NORMAL:
        {
            g_players[client].styleText = STYLE_NORMAL_TEXT;
            g_players[client].styleTextSmall = "";
        }
        case STYLE_SW:
        {
            g_players[client].styleText = STYLE_SW_TEXT;
            g_players[client].styleTextSmall = "[SW]";
        }
        case STYLE_HSW:
        {
            g_players[client].styleText = STYLE_HSW_TEXT;
            g_players[client].styleTextSmall = "[HSW]";
        }
        case STYLE_BW:
        {
            g_players[client].styleText = STYLE_BW_TEXT;
            g_players[client].styleTextSmall = "[BW]";
        }
        case STYLE_LOWGRAV:
        {
            g_players[client].styleText = STYLE_LOWGRAV_TEXT;
            g_players[client].styleTextSmall = "[LG]";
        }
        case STYLE_SLOMO:
        {
            g_players[client].styleText = STYLE_SLOMO_TEXT;
            g_players[client].styleTextSmall = "[SLW]";
        }
        case STYLE_FASTFORWARD:
        {
            g_players[client].styleText = STYLE_FASTFORWARD_TEXT;
            g_players[client].styleTextSmall = "[FF]";
        }
        case STYLE_WONLY:
        {
            g_players[client].styleText = STYLE_WONLY_TEXT;
            g_players[client].styleTextSmall = "[WO]";
        }
    }
}


// Style commands
public Action Client_SetStyleNormal(int client, int args)
{
	// check for hsw -> normal and bw -> normal
	if (g_players[client].currentStyle != STYLE_NORMAL
        || (g_players[client].currentStyle == STYLE_NORMAL && g_players[client].initialStyle == STYLE_HSW)
        || (g_players[client].currentStyle == STYLE_NORMAL && g_players[client].initialStyle == STYLE_SW)
        || (g_players[client].currentStyle == STYLE_NORMAL && g_players[client].initialStyle == STYLE_BW)
        || (g_players[client].currentStyle == STYLE_NORMAL && g_players[client].initialStyle == STYLE_WONLY))
	{
		SetStyle(client, STYLE_NORMAL);
		CReplyToCommand(client, "%t", "CommandsNormal", g_szChatPrefix);
	}

	return Plugin_Handled;
}

public Action Client_SetStyleSideways(int client, int args)
{
	SetStyle(client, STYLE_SW);
	CReplyToCommand(client, "%t", "CommandsSideways", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleHalfSideways(int client, int args)
{
	SetStyle(client, STYLE_HSW);
	CReplyToCommand(client, "%t", "CommandsHalfSideways", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleBackwards(int client, int args)
{
	SetStyle(client, STYLE_BW);
	CReplyToCommand(client, "%t", "CommandsBackwards", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleLowGrav(int client, int args)
{
	SetStyle(client, STYLE_LOWGRAV);
	CReplyToCommand(client, "%t", "CommandsLowGravity", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleSlomo(int client, int args)
{
	SetStyle(client, STYLE_SLOMO);
	CReplyToCommand(client, "%t", "CommandsSlowMotion", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleFastForward(int client, int args)
{
	SetStyle(client, STYLE_FASTFORWARD);
	CReplyToCommand(client, "%t", "CommandsFastForward", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SetStyleWOnly(int client, int args)
{
	SetStyle(client, STYLE_WONLY);
	CReplyToCommand(client, "%t", "CommandsWOnly", g_szChatPrefix);
	return Plugin_Handled;
}

public Action Client_SelectStyle(int client, int args)
{
	styleSelectMenu(client);
	return Plugin_Handled;
}
