public int Handle_VoteMenuExtend(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End) {
		/* This is called after VoteEnd */
		CloseHandle(menu);
	} else if (action == MenuAction_VoteEnd) {
		char item[64], display[64];
		float percent, limit;
		int votes, totalVotes;

		menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));
		GetMenuVoteInfo(param2, votes, totalVotes);

		if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
		votes = totalVotes - votes;

		percent = FloatDiv(float(votes),float(totalVotes));

		/* 0=yes, 1=no */
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1)) {
			CPrintToChatAll("%t", "CVote8", g_szChatPrefix, RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
		} else {
			CPrintToChatAll("%t", "CVote9", g_szChatPrefix, RoundToNearest(100.0*percent), totalVotes);
			CPrintToChatAll("%t", "CVote10", g_szChatPrefix);
			extendMap(600);
		}
	}
}
