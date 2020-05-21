#if defined _ig_core_included_
	#endinput
#endif
#define _ig_core_included_

#include <sourcemod>

#define CHAT_PREFIX "{lime}IG {default}|"

stock bool IsValidClient(int client)
{
	if (client >= 1 && client <= MaxClients && IsValidEntity(client) && IsClientConnected(client) && IsClientInGame(client))
		return true;
	return false;
}

stock bool IsPlayerZoner(int client)
{
	if (IsValidClient(client) && !IsFakeClient(client))
	{
		if (GetUserFlagBits(client) & ADMFLAG_ROOT)
			return true;
	}
	return false;
}

stock bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}

stock void RunCallback(DataPack cb, bool error = false) {
    if (cb != INVALID_HANDLE) {
        cb.Reset();
        Function fn = cb.ReadFunction();
        Call_StartFunction(null, fn);
        Call_PushCell(cb);
        Call_PushCell(error);
        Call_Finish();
    }
}
