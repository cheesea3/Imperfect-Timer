#include <sourcemod>
#include <sdktools>


public Plugin myinfo =
{
	name = "IG Entity Manager",
	description = "Manage and delete map entities",
	author = "derwangler",
	version = "1.0",
	url = "http://www.imperfectgamers.org/"
};


// @TODO: REWRITE TO MAKE ENTITY NAMES THE KEY VALUES WITH EMPTY KEYS, WHO CARES


#define DEBUG_LOGGING
#define ENTITY_CONFIG_PATH "configs/ig_entities"

char g_szMapName[128];
char g_szLogFile[PLATFORM_MAX_PATH];
char g_szConfigPath[PLATFORM_MAX_PATH];
char g_szConfigFilePath[PLATFORM_MAX_PATH];
ArrayList g_hDeletedEnts = null;


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


	// list all entities in console
	RegAdminCmd("sm_listentities", Command_ListEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_listents", Command_ListEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_lents", Command_ListEntities, ADMFLAG_ROOT);

	// list all deleted entities in console
	RegAdminCmd("sm_listdeletedentities", Command_ListDeletedEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_listdeletedents", Command_ListDeletedEntities, ADMFLAG_ROOT);
	RegAdminCmd("sm_lde", Command_ListDeletedEntities, ADMFLAG_ROOT);

	// delete an entity by INDEX
	RegAdminCmd("sm_deleteentity", Command_DeleteEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_deleteent", Command_DeleteEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_dent", Command_DeleteEntity, ADMFLAG_ROOT);

	// remove a deleted entity from the config (restore it)
	RegAdminCmd("sm_restoreentity", Command_RestoreEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_restoreent", Command_RestoreEntity, ADMFLAG_ROOT);
	RegAdminCmd("sm_rent", Command_RestoreEntity, ADMFLAG_ROOT);
}

public void OnMapStart()
{
	GetCurrentMap(g_szMapName, 128);
	FormatEx(g_szConfigFilePath, sizeof(g_szConfigFilePath), "%s/%s.cfg", g_szConfigPath, g_szMapName);
	BuildPath(Path_SM, g_szLogFile, sizeof(g_szLogFile), "logs/surftimer/%s.log", g_szMapName);
	g_hDeletedEnts = new ArrayList();

	if (FileExists(g_szConfigFilePath))
	{
		DeleteEntities(g_szConfigFilePath);
	}
}

// list all valid entities in the map
public Action Command_ListEntities(int client, int args)
{
	int entities = GetMaxEntities();
	char sClassName[128];
	char propName[128];
	for (int i = MaxClients; i < entities; i++)
	{
		if (IsValidEntity(i) && IsValidEdict(i)
			&& GetEdictClassname(i, sClassName, 128)
			&& GetEntPropString(i, Prop_Data, "m_iName", propName, 128))
		{
			PrintToConsole(client, "[%i] %s: %s", i, sClassName, propName);
		}
	}

	return Plugin_Handled;
}

// list all deleted entities as per the config file
public Action Command_ListDeletedEntities(int client, int args)
{
	char arg1[128];
	GetCmdArg(1, arg1, sizeof(arg1));

	char szMap[128];
	char szPath[PLATFORM_MAX_PATH];

	if (!arg1[0])
	{
		szPath = g_szConfigFilePath;
		szMap = g_szMapName;
	}
	else
	{
		FormatEx(szPath, sizeof(szPath), "%s/%s.cfg", g_szConfigPath, arg1);
		szMap = arg1;
	}

	// check if the entity list for the map exists
	if (FileExists(szPath))
	{
		File file = OpenFile(szPath, "r");

		PrintToConsole(client, "# IGEntityManager | Deleted entities:");
		char szName[128];
		int i;
		while (file.ReadLine(szName, sizeof(szName)))
		{
			if (strlen(szName) > 1)
				PrintToConsole(client, "  %i  %s", i++, szName);
		}
		PrintToConsole(client, "#end");
		delete file; // close file handle
	}
	else
	{
		PrintToConsole(client, "[IGEntityManager] %s has no deleted entities", szMap);
	}

	return Plugin_Handled;
}

// delete an entity by id
public Action Command_DeleteEntity(int client, int args)
{
	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));

	int iEnt = StringToInt(arg);
	char szEnt[128];

	if (IsValidEntity(iEnt) && IsValidEdict(iEnt))
	{
		GetEntPropString(iEnt, Prop_Data, "m_iName", szEnt, 128);
		AcceptEntityInput(iEnt, "Kill");
		PrintToConsole(client, "[IGEntityManager] Entity deleted: %s", szEnt);

#if defined DEBUG_LOGGING
		LogToFileEx(g_szLogFile, "[IGEntityManager] Entity '%s' deleted", szEnt);
#endif

		g_hDeletedEnts.PushString(szEnt);

		// append or write?
		File file;
		if (FileExists(g_szConfigFilePath))
			file = OpenFile(g_szConfigFilePath, "a+");
		else
			file = OpenFile(g_szConfigFilePath, "w+");

#if defined DEBUG_LOGGING
	LogToFileEx(g_szLogFile, "[IGEntityManager] WRITE %s", szEnt);
#endif
		file.WriteLine(szEnt);
#if defined DEBUG_LOGGING
	LogToFileEx(g_szLogFile, "[IGEntityManager] WROTE %s", szEnt);
#endif
		delete file;
	}

	return Plugin_Handled;
}

// restore a deleted entity (only supports current map)
public Action Command_RestoreEntity(int client, int args)
{
	char szEnt[64];
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

#if defined DEBUG_LOGGING
	LogToFileEx(g_szLogFile, "[IGEntityManager] Entity '%s' restored", szEnt);
#endif
	PrintToConsole(client, "[IGEntityManager] Entity '%s' restored (requires map reload)", szEnt);

	// write the new entity list
	File file = OpenFile(g_szConfigFilePath, "w");
	for (int i = 0; i < g_hDeletedEnts.Length; i++)
	{
		char szName[64];
		g_hDeletedEnts.GetString(i, szName, sizeof(szName));
		file.WriteLine(szName);
	}

	delete file; // close file handle
	return Plugin_Handled;
}


// delete entities on map load
void DeleteEntities(const char[] path)
{
	File file = OpenFile(path, "r");
	StringMap hEntities = GetEntityMap();

	// read the associated config file, delete the entities as they are found
	char szEnt[128]
	while (file.ReadLine(szEnt, sizeof(szEnt)))
	{
		int iEnt; // variable to store the entity index in
		if (hEntities.GetValue(szEnt, iEnt))
		{
			AcceptEntityInput(iEnt, "Kill");
			g_hDeletedEnts.PushString(szEnt);
#if defined DEBUG_LOGGING
			LogToFileEx(g_szLogFile, "[IGEntityManager] Entity %i deleted: %s", iEnt, szEnt);
#endif
		}
	}

	delete file;
}

// get a stringmap of the entity names in the current map
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
			GetEntPropString(i, Prop_Data, "m_iName", szName, 128);
			entities.SetValue(szName, i);
		}
	}

	return entities;
}
