#if defined _ig_beams_included_
	#endinput
#endif
#define _ig_beams_included_

#define IG_BEAMS "ig_beams"
#define DEF_BEAM_FRAMERATE 30


native int IG_SendBeamBoxToClient(int client, const float mins[3], const float maxs[3], float life, int color[4]);
native int IG_SendBeamBoxRotatableToClient(int client, const float origin[3], const float mins[3], const float maxs[3], const float angles[3], float life, int color[4]);
native int IG_SendBeamToClient(int client, const float start[3], const float end[3], float life, int color[4]);

public SharedPlugin __pl_ig_beams =
{
	name = IG_BEAMS,
	file = IG_BEAMS...".smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_ig_beams_SetNTVOptional()
{
	MarkNativeAsOptional("IG_SendBeamBoxToClient");
	MarkNativeAsOptional("IG_SendBeamBoxRotatableToClient");
	MarkNativeAsOptional("IG_SendBeamToClient");
}
#endif