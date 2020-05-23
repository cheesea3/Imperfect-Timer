#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

#pragma semicolon 1

public Plugin myinfo =
{
	name = "IG Outlines",
	description = "Manage and create outlines",
	author = "derwangler",
	version = "1.0",
	url = "http://www.imperfectgamers.org/"
};

#include <colorvariables>
#include <ig_surf/surftimer>
#include <ig_surf/ig_core>
#include <ig_surf/ig_beams>
#include <ig_surf/ig_entitymanager>
#include <ig_surf/ig_outlines>

#define OUTLINE_LOGGING
#define OUTLINE_LOGGING_PATH "addons/sourcemod/logs/ig_logs/outlines"

#define MYSQL 0

char g_szMapName[128];

#if defined OUTLINE_LOGGING
char g_szLogFile[PLATFORM_MAX_PATH];
#endif

/*----------  @IG Outlines  ----------*/
// Is the player is in outline creation mode?
bool g_bCreatingOutline[MAXPLAYERS + 1];

// What style is the outline creator using? 0 = line, 1 = box
int g_iOutlineStyle[MAXPLAYERS + 1];

// Has the start point been created?
bool g_bStartPointPlaced[MAXPLAYERS + 1];

// Has the end point been created?
bool g_bEndPointPlaced[MAXPLAYERS + 1];

// Outline start position
float g_fOutlineStartPos[MAXPLAYERS + 1][3];

// Outline end position
float g_fOutlineEndPos[MAXPLAYERS + 1][3];

int g_iOutlineBoxCount;
int g_iOutlineLineCount;
int g_iTotalOutlines;

bool g_bAllowBeams;

ConVar g_hShowOutlines = null; // Show outlines

MapOutline g_outlineLines[MAX_OUTLINE_LINES];
MapOutline g_outlineBoxes[MAX_OUTLINE_BOXES];

int g_iSelectedEntity[MAXPLAYERS + 1]; // for hooking entities on outline creation

// SQL driver
Database g_hDb = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("ig_outlines.phrases");

#if defined OUTLINE_LOGGING
	if (!DirExists(OUTLINE_LOGGING_PATH))
		CreateDirectory(OUTLINE_LOGGING_PATH, 511);
#endif

	// list all entities in console, optional arg to use class name
	RegAdminCmd("sm_outliner", Command_Outlines, ADMFLAG_ROOT, "[surftimer] [Zoner] Open the outlines menu");
	RegAdminCmd("sm_outlines", Command_ToggleOutlines, ADMFLAG_ROOT, "[surftimer] Toggle the visibility of outlines");
	RegAdminCmd("sm_hookoutline", Command_CreateOutlineHook, ADMFLAG_ROOT, "[surftimer] [Zoner] Hook an entity for outline creation");
	g_hShowOutlines = CreateConVar("ck_outlines", "1", "Toggle outline visibility", FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void OnPluginStop()
{
	delete g_hDb;
}

public void OnMapStart()
{
	GetCurrentMap(g_szMapName, 128);
#if defined OUTLINE_LOGGING
	FormatEx(g_szLogFile, sizeof(g_szLogFile), "%s/%s.log", OUTLINE_LOGGING_PATH, g_szMapName);
#endif

	CreateTimer(4.0, StartMapOutlines, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(OUTLINE_REFRESH_TIME, ThrottledOutlineBeamsAll, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public Action StartMapOutlines(Handle timer)
{
	DB_SetupDatabase();
	DB_SelectMapOutlines();
	return Plugin_Handled;
}

public void OnMapEnd()
{
	Format(g_szMapName, sizeof(g_szMapName), "");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual("ig_beams", name))
		g_bAllowBeams = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual("ig_beams", name))
		g_bAllowBeams = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsValidClient(client) && IsPlayerAlive(client) && g_bAllowBeams)
	{
		if (g_bCreatingOutline[client] && (buttons & IN_ATTACK || buttons & IN_ATTACK2))
		{
			float pos[3], ang[3];

			if (buttons & IN_ATTACK && !(buttons & IN_ATTACK2)) // start pos of outline
			{
				GetClientEyePosition(client, pos);
				GetClientEyeAngles(client, ang);
				TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
				TR_GetEndPosition(g_fOutlineStartPos[client]);
				g_bStartPointPlaced[client] = true;
			}
			else if (buttons & IN_ATTACK2 && !(buttons & IN_ATTACK)) // end pos of outline
			{
				GetClientEyePosition(client, pos);
				GetClientEyeAngles(client, ang);
				TR_TraceRayFilter(pos, ang, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
				TR_GetEndPosition(g_fOutlineEndPos[client]);
				g_bEndPointPlaced[client] = true;
			}
		}

		BeamBox_OnPlayerRunCmd(client);
	}

	return Plugin_Continue;
}

public void BeamBox_OnPlayerRunCmd(int client)
{
	// @IG outlines
	if (g_bCreatingOutline[client] && g_bStartPointPlaced[client] && g_bEndPointPlaced[client] && IsValidClient(client) && g_bAllowBeams)
	{
		if (g_iOutlineStyle[client] == OUTLINE_STYLE_LINE)
		{
			//TE_SendBeamLineToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 0.8, 0.8, 2, 0.0, OUTLINE_BEAM_COLOR, 0);
			IG_SendBeamToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], 0.1, OUTLINE_BEAM_COLOR);
		}
		else if (g_iOutlineStyle[client] == OUTLINE_STYLE_BOX)
		{
			//TE_SendBeamBoxToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], g_BeamSprite, g_HaloSprite, 0, BEAM_FRAMERATE, 0.1, 1.0, 1.0, 2, 0.0, OUTLINE_BEAM_COLOR, 0, true);
			IG_SendBeamBoxToClient(client, g_fOutlineStartPos[client], g_fOutlineEndPos[client], 0.1, OUTLINE_BEAM_COLOR, false);
		}
	}
}

public Action Command_ToggleOutlines(int client, int args)
{
	// @todo: fix
	//g_players[client].outlines = !g_players[client].outlines;

	//if (g_players[client].outlines)
	//	CPrintToChat(client, "%t", "OutlinesEnabled", g_szChatPrefix);
	//else
	//	CPrintToChat(client, "%t", "OutlinesDisabled", g_szChatPrefix);

	return Plugin_Handled;
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
	g_iSelectedEntity[client] = iEnt;

	// preview the outline box
	if (g_bAllowBeams)
	{
		float origin[3], mins[3], maxs[3], angles[3];
		GetEntityVectors(iEnt, origin, mins, maxs, angles);
		IG_SendBeamBoxRotatableToClient(client, origin, mins, maxs, angles, 15.0, OUTLINE_BEAM_COLOR);
	}

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
				float origin[3], mins[3], maxs[3], angles[3];
				GetEntityVectors(g_iSelectedEntity[client], origin, mins, maxs, angles);

				// we save hooks to the box array
				g_outlineBoxes[g_iOutlineBoxCount].Set(g_szMapName, g_iTotalOutlines, OUTLINE_STYLE_HOOK, origin, mins, maxs, angles);
				DB_InsertOutline(g_outlineBoxes[g_iOutlineBoxCount]);
				g_iOutlineBoxCount++;
				g_iTotalOutlines++;
			}
		}

		default:
		{
			g_iOutlineStyle[client] = OUTLINE_STYLE_LINE;
			g_iSelectedEntity[client] = -1;
			delete tMenu;
		}
	}
}

stock void OutlineMenu(int client)
{
	if (!IsValidClient(client) || !IsPlayerZoner(client))
		return;

	if (IsPlayerZoner(client))
	{
		//resetSelection(client); // is this needed?
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
		CPrintToChat(client, "%t", "NoZoneAccess", CHAT_PREFIX);
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

stock void CreateOutlineMenu(int client)
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

		case MenuAction_Cancel: OutlineMenu(client);
		case MenuAction_End: OutlineMenu(client);
	}
}

stock void StartOutlineCreation(int client)
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
					float tmp[3];
					g_outlineLines[g_iOutlineLineCount].Set(g_szMapName, g_iTotalOutlines, OUTLINE_STYLE_LINE, tmp, g_fOutlineStartPos[client], g_fOutlineEndPos[client], tmp);
					DB_InsertOutline(g_outlineLines[g_iOutlineLineCount]);
					g_iOutlineLineCount++;
					g_iTotalOutlines++;
				}
				else if (g_iOutlineStyle[client] == OUTLINE_STYLE_BOX) // box
				{
					float tmp[3];
					g_outlineBoxes[g_iOutlineBoxCount].Set(g_szMapName, g_iTotalOutlines, OUTLINE_STYLE_BOX, tmp, g_fOutlineStartPos[client], g_fOutlineEndPos[client], tmp);
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
}


public Action OutlineBeamsAll(Handle timer)
{
	ThrottledOutlineBeamsAll(INVALID_HANDLE);
}

public Action ThrottledOutlineBeamsAll(Handle timer)
{
	if (g_bAllowBeams)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsValidClient(i) || IsFakeClient(i))
				continue;

			// check for outline visibility - FIX THIS
			//if (g_players[i].outlines)
			//{
			for (int j = 0; j < g_iOutlineBoxCount; j++)
			{
				if (g_outlineBoxes[j].type == OUTLINE_STYLE_HOOK)
					SendOutlineBeamBoxRotatable(i, g_outlineBoxes[j].origin, g_outlineBoxes[j].startPos, g_outlineBoxes[j].endPos, g_outlineBoxes[j].angles);
				else if (g_outlineBoxes[j].type == OUTLINE_STYLE_BOX) // just in case
					SendOutlineBeamBox(i, g_outlineBoxes[j].startPos, g_outlineBoxes[j].endPos);
			}

			for (int j = 0; j < g_iOutlineLineCount; j++)
				SendOutlineBeam(i, g_outlineLines[j].startPos, g_outlineLines[j].endPos);
			//}
		}
	}
}

// ck_outlines
#define SQL_CREATE_OUTLINE_TABLE "CREATE TABLE IF NOT EXISTS `ck_outlines` (`mapname` varchar(32) NOT NULL DEFAULT '', `id` int(11) NOT NULL DEFAULT '-1', `type` int(11) NOT NULL DEFAULT '-1', `pointa_x` float NOT NULL DEFAULT '-1', `pointa_y` float NOT NULL DEFAULT '-1', `pointa_z` float NOT NULL DEFAULT '-1', `pointb_x` float NOT NULL DEFAULT '-1', `pointb_y` float NOT NULL DEFAULT '-1', `pointb_z` float NOT NULL DEFAULT '-1', `angle_x` float NOT NULL DEFAULT '0', `angle_y` float NOT NULL DEFAULT '0', `angle_z` float NOT NULL DEFAULT '0', `origin_x` float NOT NULL DEFAULT '0', `origin_y` float NOT NULL DEFAULT '0', `origin_z` float NOT NULL DEFAULT '0', PRIMARY KEY (`mapname`,`id`)) DEFAULT CHARSET=utf8mb4;"
#define SQL_SELECT_OUTLINES "SELECT id, type, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, angle_x, angle_y, angle_z, origin_x, origin_y, origin_z FROM ck_outlines WHERE mapname = '%s' ORDER BY id ASC"
#define SQL_DELETE_OUTLINES "DELETE FROM `ck_outlines` WHERE `mapname` = '%s'"
#define SQL_DELETE_OUTLINE "DELETE FROM `ck_outlines` WHERE `mapname` = '%s' AND `id` = '%i'"

/*===================================
=            SQL Outlines           =
===================================*/

// @todo: optimize
public void DB_SetupDatabase()
{
	char szError[255];
	g_hDb = IG_GetDatabase(); // use the surftimer db

	if (g_hDb == null)
	{
		SetFailState("[IG Outlines] Unable to get database (%s)", szError);
		return;
	}

	SQL_LockDatabase(g_hDb);

    // outlines table
	if (!SQL_FastQuery(g_hDb, "SELECT mapname FROM ck_outlines LIMIT 1"))
	{
		SQL_FastQuery(g_hDb, SQL_CREATE_OUTLINE_TABLE);
	}

	SQL_UnlockDatabase(g_hDb);
}

#define SQL_INSERT_OUTLINE "INSERT INTO `ck_outlines` \
							(mapname, id, type, pointa_x, pointa_y, pointa_z, pointb_x, pointb_y, pointb_z, angle_x, angle_y, angle_z, origin_x, origin_y, origin_z) \
							VALUES ('%s', '%i', '%i', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f', '%f')"

public void DB_InsertOutline(MapOutline ol)
{
	char szQuery[1024];

	Format(szQuery, 1024, SQL_INSERT_OUTLINE, g_szMapName, ol.id, ol.type,
			ol.startPos[0], ol.startPos[1], ol.startPos[2],
			ol.endPos[0], ol.endPos[1], ol.endPos[2],
			ol.angles[0], ol.angles[1], ol.angles[2],
			ol.origin[0], ol.origin[1], ol.origin[2]);
	g_hDb.Query(SQL_InsertOutlineCallback, szQuery);
}

public void SQL_InsertOutlineCallback(Handle owner, Handle hndl, const char[] error, DataPack data)
{
	if (hndl == null)
	{
		LogError("[IG Outlines] SQL Error (SQL_InsertOutlineCallback): %s", error);
		delete data;
		return;
	}

	DB_SelectMapOutlines();
}


void DB_SelectMapOutlines(any cb = 0)
{
	char szQuery[512];
	Format(szQuery, sizeof(szQuery), SQL_SELECT_OUTLINES, g_szMapName);
	g_hDb.Query(SQL_SelectOutlinesCallback, szQuery, cb, DBPrio_High);
}

public void SQL_SelectOutlinesCallback(Handle owner, DBResultSet results, const char[] error, any cb)
{
	if (results == null)
	{
		LogError("[IG Outlines] SQL Error (SQL_SelectOutlinesCallback): %s", error);
		RunCallback(cb, true);
		return;
	}

	if (results.HasResults)
	{
		// set defaults
		g_iOutlineLineCount = 0;
		g_iOutlineBoxCount = 0;
		g_iTotalOutlines = 0;

		for (int i = 0; i < MAX_OUTLINE_LINES; i++)
			g_outlineLines[i].Defaults();

		for (int i = 0; i < MAX_OUTLINE_BOXES; i++)
			g_outlineBoxes[i].Defaults();

		// read table
		while (results.FetchRow())
		{
			MapOutline outline;
			outline.id = results.FetchInt(0);
			outline.type = results.FetchInt(1);
			outline.startPos[0] = results.FetchFloat(2);
			outline.startPos[1] = results.FetchFloat(3);
			outline.startPos[2] = results.FetchFloat(4);
			outline.endPos[0] = results.FetchFloat(5);
			outline.endPos[1] = results.FetchFloat(6);
			outline.endPos[2] = results.FetchFloat(7);

			outline.angles[0] = results.FetchFloat(8);
			outline.angles[1] = results.FetchFloat(9);
			outline.angles[2] = results.FetchFloat(10);

			if (outline.type == OUTLINE_STYLE_HOOK || outline.type == OUTLINE_STYLE_BOX)
			{
				// hook outlines do not use default origin, need to add the vectors to remove origin from db
				if (outline.type == OUTLINE_STYLE_HOOK)
				{
					outline.origin[0] = results.FetchFloat(11);
					outline.origin[1] = results.FetchFloat(12);
					outline.origin[2] = results.FetchFloat(13);
				}

				g_outlineBoxes[g_iOutlineBoxCount] = outline;
				g_iOutlineBoxCount++;
				g_iTotalOutlines++;
			}
			else if (outline.type == OUTLINE_STYLE_LINE)
			{
				g_outlineLines[g_iOutlineLineCount] = outline;
				g_iOutlineLineCount++;
				g_iTotalOutlines++;
			}
		}

#if defined OUTLINE_LOGGING
		LogToFileEx(g_szLogFile, "Successfully loaded %i outlines", g_iTotalOutlines);
#endif
	}

	RunCallback(cb);
}

stock void SendOutlineBeamBox(int client, float mins[3], float maxs[3])
{
	IG_SendBeamBoxToClient(client, mins, maxs, OUTLINE_REFRESH_TIME, OUTLINE_BEAM_COLOR, true);
}

stock void SendOutlineBeamBoxRotatable(int client, float origin[3], float mins[3], float maxs[3], float angles[3])
{
	IG_SendBeamBoxRotatableToClient(client, origin, mins, maxs, angles, OUTLINE_REFRESH_TIME, OUTLINE_BEAM_COLOR);
}

stock void SendOutlineBeam(int client, float start[3], float end[3])
{
	IG_SendBeamToClient(client, start, end, OUTLINE_REFRESH_TIME, OUTLINE_BEAM_COLOR);
}