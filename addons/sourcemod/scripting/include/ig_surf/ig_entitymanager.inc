#if defined _ig_entitymanager_included_
	#endinput
#endif
#define _ig_entitymanager_included_

#include <sourcemod>
#include <sdktools>
//#include <smlib>
#include <ig_surf/ig_core>
#include <ig_surf/ig_beams>

#define BEAM_COLOR_HIGHLIGHT { 255, 255, 0, 255 }

//int g_highlightBeamSprite;
//int g_highlightHaloSprite;


stock void HighlightEntity(int client, int iEnt)
{
	if (!IsValidEntity(iEnt))
		return;

	if (HasEntProp(iEnt, Prop_Send, "m_vecOrigin"))
	{
		float origin[3], mins[3], maxs[3], angles[3];
		GetEntityVectors(iEnt, origin, mins, maxs, angles);
		IG_SendBeamBoxRotatableToClient(client, origin, mins, maxs, angles, 15.0, BEAM_COLOR_HIGHLIGHT);
		//Effect_DrawBeamBoxRotatableToClient(client, origin, mins, maxs, angles, g_highlightBeamSprite, g_highlightHaloSprite, 0, 30, 15.0, 1.0, 1.0, 2, 0.0, BEAM_COLOR_HIGHLIGHT, 0);
	}
	else
	{
		PrintToChat(client, "Entity does not have m_vecOrigin! Highlight failed.");
	}
}

stock void GetEntityVectors(int iEnt, float origin[3], float mins[3], float maxs[3], float angles[3])
{
	GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMins", mins);
	GetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", maxs);
	GetEntPropVector(iEnt, Prop_Send, "m_angRotation", angles);
}
