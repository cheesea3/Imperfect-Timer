#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma semicolon 1

public Plugin myinfo =
{
	name = "IG Entity Manager",
	description = "Manage and delete map entities",
	author = "derwangler",
	version = "1.0",
	url = "http://www.imperfectgamers.org/"
};

#include <ig_entitymanager>

#define ENTITY_LOGGING
#define ENTITY_LOGGING_PATH "logs/ig_entities"
#define ENTITY_CONFIG_PATH  "configs/ig_entities"

char g_szMapName[128];
char g_szConfigPath[PLATFORM_MAX_PATH];
char g_szConfigFilePath[PLATFORM_MAX_PATH];
ArrayList g_hDeletedEnts = null;

#if defined ENTITY_LOGGING
char g_szLogFile[PLATFORM_MAX_PATH];
char g_szLogFilePath[PLATFORM_MAX_PATH];
#endif

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	return APLRes_Success;
}

public void OnPluginStart()
{
	// setup paths
	BuildPath(Path_SM, g_szConfigPath, sizeof(g_szConfigPath), ENTITY_CONFIG_PATH);
	if (!DirExists(g_szConfigPath))
		CreateDirectory(g_szConfigPath, 511);

	BuildPath(Path_SM, g_szLogFilePath, sizeof(g_szLogFilePath), ENTITY_LOGGING_PATH);
	if (!DirExists(g_szLogFilePath))
		CreateDirectory(g_szLogFilePath, 511);


	// list all entities in console, optional arg to use class name
	RegAdminCmd("sm_listentities", Command_ListEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_listents", Command_ListEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_lents", Command_ListEntities, ADMFLAG_ROOT);

	// list all deleted entities in console
	RegAdminCmd("sm_listdeletedentities", Command_ListDeletedEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_listdeletedents", Command_ListDeletedEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_lde", Command_ListDeletedEntities, ADMFLAG_ROOT);

	// delete an entity by INDEX (should do by name instead)
	RegAdminCmd("sm_deleteentity", Command_DeleteEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_deleteent", Command_DeleteEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_delent", Command_DeleteEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_dent", Command_DeleteEntity, ADMFLAG_ROOT);

	// remove a deleted entity from the config (restore it)
	RegAdminCmd("sm_restoreentity", Command_RestoreEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_restoreent", Command_RestoreEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_rent", Command_RestoreEntity, ADMFLAG_ROOT);

	// teleport to an entity
	RegAdminCmd("sm_gotoentity", Command_GoToEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_gotoent", Command_GoToEntity, ADMFLAG_ROOT);

	// highlight an entity with a beam box
	RegAdminCmd("sm_highlightentity", Command_HighlightEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_highlightent", Command_HighlightEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_hle", Command_HighlightEntity, ADMFLAG_ROOT);

	if (g_hDeletedEnts == null)
		g_hDeletedEnts = new ArrayList(128);
}

public void OnPluginStop()
{
	if (g_hDeletedEnts != null)
		delete g_hDeletedEnts;
}

public void OnMapStart()
{
	GetCurrentMap(g_szMapName, 128);
	FormatEx(g_szConfigFilePath, sizeof(g_szConfigFilePath), "%s/%s.cfg", g_szConfigPath, g_szMapName);
#if defined ENTITY_LOGGING
	FormatEx(g_szLogFile, sizeof(g_szLogFile), "%s/%s.log", g_szLogFilePath, g_szMapName);
#endif

	if (g_hDeletedEnts == null)
		g_hDeletedEnts = new ArrayList(128);

	if (FileExists(g_szConfigFilePath))
		DeleteEntities(g_szConfigFilePath);
}

public void OnMapEnd()
{
	if (g_hDeletedEnts != null)
		delete g_hDeletedEnts;
}

// list all valid entities in the map
public Action Command_ListEntities(int client, int args)
{
	char arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));


	// check for class name argument
	if (!arg1[0])
	{
		int entities = GetMaxEntities();
		for (int i = MaxClients; i < entities; i++)
		{
			char sClassName[128];
			if (IsValidEntity(i) && GetEdictClassname(i, sClassName, 128))
			{
				char propName[128];
				if (GetEntPropString(i, Prop_Data, "m_iName", propName, 128))
					PrintToConsole(client, "[%i] %s: %s", i, sClassName, propName);
				else
					PrintToConsole(client, "[%i] %s", i, sClassName);
			}
		}
	}
	else
	{
		PrintToConsole(client, "Checking for '%s' entities...", arg1);
		int iEnt = -1;
		while ((iEnt = FindEntityByClassname(iEnt, arg1)) != -1)
		{
			char propName[128];
			if (GetEntPropString(iEnt, Prop_Data, "m_iName", propName, 128))
				PrintToConsole(client, "[%i] %s: %s", iEnt, arg1, propName);
			else
				PrintToConsole(client, "[%i] %s", iEnt, arg1);
		}
	}

	return Plugin_Handled;
}

// list all deleted entities as per the config file
// @todo: support map argument
// should this read from config? refreshing the plugin will result in an empty list
public Action Command_ListDeletedEntities(int client, int args)
{
	// check if the entity list for the map exists
	PrintToConsole(client, "# IGEntityManager | %i Deleted entities:", g_hDeletedEnts.Length);
	for (int i = 0; i < g_hDeletedEnts.Length; i++)
	{
		char szName[128];
		g_hDeletedEnts.GetString(i, szName, sizeof(szName));
		PrintToConsole(client, "  %i  %s", i, szName);
	}

	PrintToConsole(client, "#end");

	return Plugin_Handled;
}

// delete an entity by name
public Action Command_DeleteEntity(int client, int args)
{
	char szEnt[128];
	GetCmdArg(1, szEnt, sizeof(szEnt));
	StringMap hEntities = GetEntityMap();

	int iEnt;
	if (!hEntities.GetValue(szEnt, iEnt))
	{
		PrintToConsole(client, "[IGEntityManager] Unable to find entity '%s'", szEnt);
		delete hEntities;
		return Plugin_Handled;
	}

	if (IsValidEntity(iEnt) && IsValidEdict(iEnt))
	{
		AcceptEntityInput(iEnt, "Kill");
		PrintToConsole(client, "[IGEntityManager] Entity deleted: %s", szEnt);

#if defined ENTITY_LOGGING
		LogToFileEx(g_szLogFile, "Entity '%s' deleted", szEnt);
#endif

		g_hDeletedEnts.PushString(szEnt);

		// rewrite the config
		WriteConfigFile();
	}
	else
	{
		PrintToConsole(client, "[IGEntityManager] Entity '%s' was found but was not valid!", szEnt);
	}

	delete hEntities;
	return Plugin_Handled;
}

// restore a deleted entity (only supports current map)
public Action Command_RestoreEntity(int client, int args)
{
	char szEnt[128];
	GetCmdArg(1, szEnt, sizeof(szEnt));

	// require an argument
	if (!szEnt[0])
		return Plugin_Handled;

	// check removed entities arraylist for entity name
	int index = g_hDeletedEnts.FindString(szEnt);
	if (index == -1)
	{
		PrintToConsole(client, "[IGEntityManager] Entity '%s' has not been deleted or is not an entity.", szEnt);
		return Plugin_Handled;
	}

	// delete the entity, we don't want it anymore
	g_hDeletedEnts.Erase(index);

#if defined ENTITY_LOGGING
	LogToFileEx(g_szLogFile, "Entity '%s' restored", szEnt);
#endif
	PrintToConsole(client, "[IGEntityManager] Entity '%s' restored (requires map reload)", szEnt);

	// write the new entity list
	WriteConfigFile();
	return Plugin_Handled;
}


public Action Command_GoToEntity(int client, int args)
{
	char arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));
	int iEnt = StringToInt(arg1);

	GoToEntity(client, iEnt);

	return Plugin_Handled;
}

public Action Command_HighlightEntity(int client, int args)
{
	char arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));
	int iEnt = StringToInt(arg1);

	if (IsValidEntity(iEnt))
		HighlightEntity(client, iEnt);
	else
		PrintToChat(client, "Invalid entity index: %i", iEnt);

	return Plugin_Handled;
}

// delete entities on map load
void DeleteEntities(const char[] path)
{
	File file = OpenFile(path, "r");
	StringMap hEntities = GetEntityMap();

#if defined ENTITY_LOGGING
			LogToFileEx(g_szLogFile, "Attempting to delete entities...");
#endif

	// read the associated config file, delete the entities as they are found
	char szEnt[128];
	while (file.ReadLine(szEnt, sizeof(szEnt)))
	{
		SplitString(szEnt, "\n", szEnt, sizeof(szEnt));

		int iEnt; // variable to store the entity index in
		if (hEntities.GetValue(szEnt, iEnt))
		{
			AcceptEntityInput(iEnt, "Kill");
			g_hDeletedEnts.PushString(szEnt);

#if defined ENTITY_LOGGING
			LogToFileEx(g_szLogFile, "%s deleted", szEnt);
#endif
		}
	}

	delete hEntities;
	delete file;
}

// get a stringmap of the named entities in the current map
StringMap GetEntityMap()
{
	StringMap entities = new StringMap();

	// populate the stringmap with the entity names and their ids
	int iEnts = GetMaxEntities();
	for (int i = MaxClients; i < iEnts; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i))
		{
			char szName[128];
			GetEntPropString(i, Prop_Data, "m_iName", szName, sizeof(szName));
			entities.SetValue(szName, i);
		}
	}

	return entities;
}

// write config file
stock void WriteConfigFile()
{
	File file = OpenFile(g_szConfigFilePath, "w");
	for (int i = 0; i < g_hDeletedEnts.Length; i++)
	{
		char szName[128];
		g_hDeletedEnts.GetString(i, szName, sizeof(szName));
		file.WriteLine(szName);
	}

	delete file;
}
