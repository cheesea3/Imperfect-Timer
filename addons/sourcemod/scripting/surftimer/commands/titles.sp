public Action Command_GiveTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 2) {
		CReplyToCommand(client, "Usage: <name> <title> - title can be rapper, dj, beat, surfer, or something custom");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH], szBuffer[MAX_TITLE_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	GetCmdArg(2, szBuffer, sizeof(szBuffer));
	int target = FindTarget(client, targetStr, true, false);
	GiveTitle(client, target, szBuffer);
	return Plugin_Handled;
}
public void GiveTitle(int client, int target, const char[] title) {
	if (target < 0) {
		CReplyToCommand(client, "Target player not found");
		return;
	}
	if (!IsPlayerLoaded(target)) {
		CReplyToCommand(client, "Player not yet loaded");
		return;
	}
	char newTitle[MAX_RAWTITLE_LENGTH];
	if (StrEqual(g_szCustomTitleRaw[target], "")) {
		Format(newTitle, sizeof(newTitle), "0`%s", title);
	} else {
		Format(newTitle, sizeof(newTitle), "%s`%s", g_szCustomTitleRaw[target], title);
	}

	SaveRawTitle(target, newTitle);

	char targetNamed[MAX_NAME_LENGTH];
	GetClientName(target, targetNamed, sizeof(targetNamed));
	char pretty[MAX_TITLE_LENGTH];
	FormatTitleSlug(title, pretty, sizeof(pretty));
	CPrintToChatAll("%s was granted the title: %s", targetNamed, pretty);
}

public Action Command_RemoveTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 2) {
		CReplyToCommand(client, "Usage: <name> <title>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH], szBuffer[MAX_TITLE_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	GetCmdArg(2, szBuffer, sizeof(szBuffer));
	int target = FindTarget(client, targetStr, true, false);
	RemoveTitle(client, target, szBuffer);
	return Plugin_Handled;
}
public void RemoveTitle(int client, int target, const char[] title) {
	if (!IsPlayerLoaded(target)) {
		CReplyToCommand(client, "Player not yet loaded");
		return;
	}
	char newTitle[MAX_RAWTITLE_LENGTH] = "";
	if (!StrEqual(title, "all")) {
		char parts[MAX_TITLES][MAX_TITLE_LENGTH];
		int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
		for (int i = 0; i < numParts; i++) {
			if (i == 0 || !StrEqual(parts[i], title, false)) {
				if (i != 0) {
					StrCat(newTitle, sizeof(newTitle), "`");
				}
				StrCat(newTitle, sizeof(newTitle), parts[i]);
			}
		}
	}
	SaveRawTitle(target, newTitle);

	char targetNamed[MAX_NAME_LENGTH];
	GetClientName(target, targetNamed, sizeof(targetNamed));
	char pretty[MAX_TITLE_LENGTH];
	FormatTitleSlug(title, pretty, sizeof(pretty));
	CPrintToChatAll("%s was stripped of title: %s", targetNamed, pretty);
}

public Action Command_ListTitles(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 1) {
		CReplyToCommand(client, "Usage: <name>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	int target = FindTarget(client, targetStr, true, false);
	ListTitles(client, target);
	return Plugin_Handled;
}
public void ListTitles(int client, int target) {
	if (!IsPlayerLoaded(target)) {
		CReplyToCommand(client, "Player not yet loaded");
		return;
	}
	char parts[MAX_TITLES][MAX_TITLE_LENGTH];
	char out[MAX_RAWTITLE_LENGTH];
	if (client == target) {
		out = "You have these titles: ";
	} else {
		char targetNamed[MAX_NAME_LENGTH];
		GetClientName(target, targetNamed, sizeof(targetNamed));
		Format(out, sizeof(out), "%s has these titles: ", targetNamed);
	}
	int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
	for (int i = 1; i < numParts; i++) {
		StrCat(out, sizeof(out), parts[i]);
		if (i != numParts-1) {
			StrCat(out, sizeof(out), ", ");
		}
	}
	PrintToChat(client, out);
}

public Action Command_NextTitle(int client, int args) {
	if (!IsValidClient(client))
		return Plugin_Handled;
	if (args < 1) {
		CReplyToCommand(client, "Usage: <name>");
		return Plugin_Handled;
	}
	char targetStr[MAX_NAME_LENGTH];
	GetCmdArg(1, targetStr, sizeof(targetStr));
	int target = FindTarget(client, targetStr, true, false);
	NextTitle(client, target);
	return Plugin_Handled;
}
public void NextTitle(int client, int target) {
	if (!IsPlayerLoaded(target)) {
		CReplyToCommand(client, "Player not yet loaded");
		return;
	}

	char parts[MAX_TITLES][MAX_TITLE_LENGTH];
	char newStr[MAX_RAWTITLE_LENGTH];
	int numParts = ExplodeString(g_szCustomTitleRaw[target], "`", parts, sizeof(parts), sizeof(parts[]));
	if (numParts >= 1) {
		for (int attempt = 0; attempt < 10; attempt++) {
			if (StrEqual(parts[0], "vip")) parts[0] = "mod";
			else if (StrEqual(parts[0], "mod")) parts[0] = "admin";
			else if (StrEqual(parts[0], "admin")) parts[0] = "0";
			else {
				int num = StringToInt(parts[0]);
				num++;
				if (num >= numParts) {
					parts[0] = "vip";
				} else {
					Format(parts[0], sizeof(parts[]), "%d", num);
				}
			}
			ImplodeStrings(parts, numParts, "`", newStr, sizeof(newStr));
			char formatted[MAX_TITLE_LENGTH];
			FormatTitle(target, newStr, formatted, sizeof(formatted));
			if (StrEqual(parts[0], "0")) {
				formatted = "<default>";
			}
			if (!StrEqual(formatted, "")) {
				SaveRawTitle(target, newStr);
				char out[1024];
				if (client == target) {
					Format(out, sizeof(out), "You have changed your title to %s", formatted);
				} else {
					char targetNamed[MAX_NAME_LENGTH];
					GetClientName(target, targetNamed, sizeof(targetNamed));
					Format(out, sizeof(out), "You have changed the title of %s to %s", targetNamed, formatted);
				}
				CPrintToChat(client, out);
				return;
			}
		}
	}
}

public void SaveRawTitle(int client, char[] raw) {
	char rawEx[MAX_RAWTITLE_LENGTH*2+1];
	SQL_EscapeString(g_hDb, raw, rawEx, sizeof(rawEx));

	char szQuery[MAX_RAWTITLE_LENGTH*4+100];
	Format(szQuery, sizeof(szQuery), " \
	    INSERT INTO ck_vipadmins \
	    SET steamid='__steamid__', title='%s' \
	    ON DUPLICATE KEY UPDATE title='%s' \
    ", rawEx, rawEx);
	SQL_PlayerQuery(szQuery, SaveRawTitle2, client);
}
public void SaveRawTitle2(Handle hndl, const char[] error, int client, any data) {
	PrintToServer("Successfully updated custom title.");
	db_refreshCustomTitles(client);
}
