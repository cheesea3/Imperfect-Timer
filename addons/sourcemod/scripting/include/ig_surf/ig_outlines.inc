#if defined _ig_outlines_included_
	#endinput
#endif
#define _ig_outlines_included_

#include <sourcemod>
#include <sdktools>

// max outlines per map
#define OUTLINE_REFRESH_TIME 2.0
#define MAX_OUTLINE_LINES 100
#define MAX_OUTLINE_BOXES 30

#define OUTLINE_BEAM_COLOR { 255, 255, 255, 200 }

enum
{
	OUTLINE_STYLE_LINE = 0,
	OUTLINE_STYLE_BOX,
	OUTLINE_STYLE_HOOK
};

enum struct MapOutline
{
	char mapName[128];
	int id;
	int type;
	float origin[3];
	float startPos[3];
	float endPos[3];
	float angles[3]; // used for boxes

	void Defaults()
	{
		this.id = -1;
		this.type = -1;
	}

	void Set(char name[128], int id, int type, float origin[3], float startPos[3], float endPos[3], float angles[3])
	{
		this.mapName = name;
		this.id = id;
		this.type = type;
		this.origin = origin;
		this.startPos = startPos;
		this.endPos = endPos;
		this.angles = angles;
	}
}

