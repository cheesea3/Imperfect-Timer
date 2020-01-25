#if defined _igentitymanager_included_
	#endinput
#endif
#define _igentitymanager_included_

#include <sourcemod>
#include <sdktools>
#include <smlib>

#define BEAM_COLOR_HIGHLIGHT { 255, 255, 0, 255 }

int g_highlightBeamSprite;
int g_highlightHaloSprite;


stock void HighlightEntity(int client, int iEnt)
{
	if (!IsValidEntity(iEnt))
		return;

	if (g_highlightBeamSprite == 0)
	{
		g_highlightBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt", true);
		g_highlightHaloSprite = PrecacheModel("materials/sprites/halo.vmt", true);
	}

	if (HasEntProp(iEnt, Prop_Send, "m_vecOrigin"))
	{
		float origin[3], mins[3], maxs[3], angles[3];
		GetEntityVectors(iEnt, origin, mins, maxs, angles);
		Effect_DrawBeamBoxRotatableToClient(client, origin, mins, maxs, angles, g_highlightBeamSprite, g_highlightHaloSprite, 0, 30, 15.0, 1.0, 1.0, 1, 1.0, BEAM_COLOR_HIGHLIGHT, 0);
	}
	else
	{
		PrintToChat(client, "Entity does not have m_vecOrigin! Highlight failed.");
	}
}


stock void GoToEntity(int client, int iEnt)
{
	if (IsValidEntity(iEnt) && HasEntProp(iEnt, Prop_Send, "m_vecOrigin"))
	{
		char sClassName[128];
		GetEdictClassname(iEnt, sClassName, 128);

		float pos[3], ang[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", pos);
		GetClientEyeAngles(client, ang);
		TeleportEntity(client, pos, ang, view_as<float>( { 0.0, 0.0, -100.0 } ));
		HighlightEntity(client, iEnt); // highlight it as well, cause why not
		PrintToChat(client, "Teleported to entity %i: %s at { %.2f, %.2f. %.2f }", iEnt, sClassName, pos[0], pos[1], pos[2]);
	}
	else
	{
		PrintToChat(client, "Invalid entity index or missing property: %i", iEnt);
	}
}


stock void GetEntityVectors(int iEnt, float origin[3], float mins[3], float maxs[3], float angles[3])
{
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(iEnt, Prop_Send, "m_angRotation", angles);
}