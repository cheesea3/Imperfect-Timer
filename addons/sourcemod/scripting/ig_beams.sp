#include <sourcemod>
#include <sdktools>
#include <smlib>

#pragma semicolon 1

public Plugin myinfo =
{
	name = "IG Beam Module",
	description = "Beam effects. Cool",
	author = "derwangler",
	version = "1.0",
	url = "http://www.imperfectgamers.org/"
};

#include <ig_surf/ig_core>
#include <ig_surf/ig_beams>

#define BEAM_LOGGING
#define BEAM_LOGGING_PATH "logs/ig_logs/beams"

#define BEAM_SPRITE_PATH "materials/sprites/laserbeam.vmt"
#define HALO_SPRITE_PATH "materials/sprites/halo.vmt"

#if defined BEAM_LOGGING
char g_szLogFile[PLATFORM_MAX_PATH];
char g_szLogFilePath[PLATFORM_MAX_PATH];
#endif

int g_BeamSprite;
int g_HaloSprite;
char g_szMapName[128];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary(IG_BEAMS);

	CreateNative("IG_SendBeamBoxToClient", Native_SendBeamBoxToClient);
	CreateNative("IG_SendBeamBoxRotatableToClient", Native_SendBeamBoxRotatableToClient);
	CreateNative("IG_SendBeamToClient", Native_SendBeamToClient);

	return APLRes_Success;
}

public void OnPluginStart()
{
#if defined BEAM_LOGGING
	BuildPath(Path_SM, g_szLogFilePath, sizeof(g_szLogFilePath), BEAM_LOGGING_PATH);
	if (!DirExists(g_szLogFilePath))
		CreateDirectory(g_szLogFilePath, 511);
#endif
}

/*public void OnPluginStop()
{

}*/

public void OnMapStart()
{
	InitPrecache();
	GetCurrentMap(g_szMapName, 128);
#if defined BEAM_LOGGING
	FormatEx(g_szLogFile, sizeof(g_szLogFile), "%s/%s.log", g_szLogFilePath, g_szMapName);
#endif
}

public void OnMapEnd()
{
	Format(g_szMapName, sizeof(g_szMapName), "");
}

stock void InitPrecache()
{
	g_BeamSprite = PrecacheModel(BEAM_SPRITE_PATH, true);
	g_HaloSprite = PrecacheModel(HALO_SPRITE_PATH, true);
}


public int Native_SendBeamBoxToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float mins[3], maxs[3], life;
	GetNativeArray(2, mins, sizeof(mins));
	GetNativeArray(3, maxs, sizeof(maxs));
	life = GetNativeCell(4);
	int color[4];
	GetNativeArray(5, color, sizeof(color));
	Effect_DrawBeamBoxToClient(client, mins, maxs, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 1, 1.0, color, 0);
}

public int Native_SendBeamBoxRotatableToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float origin[3], mins[3], maxs[3], angles[3], life;
	GetNativeArray(2, origin, sizeof(origin));
	GetNativeArray(3, mins, sizeof(mins));
	GetNativeArray(4, maxs, sizeof(maxs));
	GetNativeArray(5, angles, sizeof(angles));
	life = GetNativeCell(6);
	int color[4];
	GetNativeArray(7, color, sizeof(color));
	Effect_DrawBeamBoxRotatableToClient(client, origin, mins, maxs, angles, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 1, 1.0, color, 0);
}

public int Native_SendBeamToClient(Handle hPlugin, int numParams)
{
	int client = GetNativeCell(1);
	float start[3], end[3], life;
	GetNativeArray(2, start, sizeof(start));
	GetNativeArray(3, end, sizeof(end));
	life = GetNativeCell(4);
	int color[4];
	GetNativeArray(5, color, sizeof(color));
	TE_SetupBeamPoints(start, end, g_BeamSprite, g_HaloSprite, 0, DEF_BEAM_FRAMERATE, life, 1.0, 1.0, 1, 1.0, color, 0);
	TE_SendToClient(client);
}


/*#define WALL_BEAMBOX_OFFSET_UNITS 2.0

stock void TE_SendBeamBoxToClient(  int client,
									float uppercorner[3],
									float bottomcorner[3],
									int ModelIndex,
									int HaloIndex,
									int StartFrame,
									int FrameRate,
									float Life,
									float Width,
									float EndWidth,
									int FadeLength,
									float Amplitude,
									const int Color[4],
									int Speed,
									bool full)
{
	float corners[8][3];
	Array_Copy(uppercorner, corners[0], 3);
	Array_Copy(bottomcorner, corners[7], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++) {
		min[i] = corners[0][i];
		if (corners[7][i] < min[i]) min[i] = corners[7][i];
	}

	// Calculate all corners from two provided
	for(int i = 1; i < 7; i++) {
		for(int j = 0; j < 3; j++) {
			corners[i][j] = corners[((i >> (2-j)) & 1) * 7][j];
		}
	}

	// Pull corners in by 1 unit to prevent them being hidden inside the ground / walls / ceiling
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 8; i++) {
			if (corners[i][j] == min[j]) {
				corners[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			} else {
				corners[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
			}
		}
		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	// Send beams to client
	// https://forums.alliedmods.net/showpost.php?p=2006539&postcount=8
	for (int i = 0, i2 = 3; i2 >= 0; i+=i2--)
	{
		for(int j = 1; j <= 7; j += (j / 2) + 1)
		{
			if (j != 7-i)
			{
				if (!full && (corners[i][2] != min[2] || corners[j][2] != min[2]))
					continue;
				TE_SetupBeamPoints(corners[i], corners[j], ModelIndex, HaloIndex, StartFrame, FrameRate, Life, Width, EndWidth, FadeLength, Amplitude, Color, Speed);
				TE_SendToClient(client);
			}
		}
	}
}

stock void TE_SendBeamLineToClient( int client,
									const float start[3],
									const float end[3],
									int modelIndex = 0,
									int haloIndex = 0,
									int startFrame = 0,
									int frameRate = 30,
									float life = 0.0,
									float width = 1.0,
									float endWidth = 1.0,
									int fadeLength = 0,
									float amplitude = 0.0,
									const int color[4] = { 255, 255, 255, 200 },
									int speed = 0)
{

	float points[2][3];
	Array_Copy(start, points[0], 3);
	Array_Copy(end, points[1], 3);

	// Calculate mins
	float min[3];
	for (int i = 0; i < 3; i++) {
		min[i] = points[0][i];
		if (points[1][i] < min[i])
			min[i] = points[1][i];
	}

	// Pull points in by 1 unit to prevent them being hidden inside the ground / walls / ceiling
	for (int j = 0; j < 3; j++) {
		for (int i = 0; i < 2; i++) {
			if (points[i][j] == min[j])
				points[i][j] += WALL_BEAMBOX_OFFSET_UNITS;
			else
				points[i][j] -= WALL_BEAMBOX_OFFSET_UNITS;
		}

		min[j] += WALL_BEAMBOX_OFFSET_UNITS;
	}

	//TE_SetupBeamPoints(points[0], points[1], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
	TE_SetupBeamPoints(start, end, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
	TE_SendToClient(client);
}*/
