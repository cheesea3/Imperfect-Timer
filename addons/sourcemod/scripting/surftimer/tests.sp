#if defined DEBUG

public void CreateTestCommands()
{
	RegAdminCmd("sm_test", Command_Test, ADMFLAG_CUSTOM6);
	RegAdminCmd("sm_vel", Command_GetVelocity, ADMFLAG_ROOT);
	RegAdminCmd("sm_targetname", Command_TargetName, ADMFLAG_ROOT);
}

public Action Command_Test(int client, int args)
{
	// CPrintToChatAll("stage: %d : wrcp: %d", g_Stage[0][client], g_WrcpStage[client]);
	// CPrintToChatAll("zoneid: %d", g_iClientInZone[client][3]);
	char arg[128];
	char found[128];
	GetCmdArg(1, arg, 128);
	FindMap(arg, found, 128);
	CPrintToChat(client, "arg: %s | found: %s", arg, found);
	return Plugin_Handled;
}

public Action Command_GetVelocity(int client, int args)
{
	float CurVelVec[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", CurVelVec);
	CPrintToChat(client, "%t", "Commands1", g_szChatPrefix, CurVelVec[0], CurVelVec[1], CurVelVec[2]);

	return Plugin_Handled;
}

public Action Command_TargetName(int client, int args)
{
	char szTargetName[128];
	char szClassName[128];
	GetEntPropString(client, Prop_Data, "m_iName", szTargetName, sizeof(szTargetName));
	GetEntityClassname(client, szClassName, 128);
	CPrintToChat(client, "%t", "Commands2", g_szChatPrefix, szTargetName);
	CPrintToChat(client, "%t", "Commands3", g_szChatPrefix, szClassName);

	return Plugin_Handled;
}

#endif