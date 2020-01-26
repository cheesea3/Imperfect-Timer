#if defined _surftimer_included
 #endinput
#endif
#define _surftimer_included

// style text
#define STYLE_NORMAL_TEXT 			"Normal"
#define STYLE_SW_TEXT 				"Sideways"
#define STYLE_HSW_TEXT 				"Half-Sideways"
#define STYLE_BW_TEXT 				"Backwards"
#define STYLE_LOWGRAV_TEXT 			"Low Gravity"
#define STYLE_SLOMO_TEXT 			"Slow Motion"
#define STYLE_FASTFORWARD_TEXT 		"Fast Forward"
#define STYLE_WONLY_TEXT 			"W Only"
#define STYLE_TEXT_LENGTH 			128
#define STYLE_TEXT_SMALL_LENGTH 	32

// always update with new styles
#define MAX_STYLES                  8

enum
{
    STYLE_NORMAL = 0,
    STYLE_SW,
    STYLE_HSW,
    STYLE_BW,
    STYLE_LOWGRAV,
    STYLE_SLOMO,
    STYLE_FASTFORWARD,
	STYLE_WONLY
};


#define MAX_ZONETYPES     12
#define MAX_ZONEGROUPS 12
#define MAX_ZONES      128

enum
{
	ZONETYPE_STOP = 0,
	ZONETYPE_START,
	ZONETYPE_END,
	ZONETYPE_STAGE,
	ZONETYPE_CHECKPOINT,
	ZONETYPE_SPEEDSTART,
	ZONETYPE_TELETOSTART,
	ZONETYPE_VALIDATOR,
	ZONETYPE_CHECKER,
	ZONETYPE_ANTIJUMP,
	ZONETYPE_ANTIDUCK,
	ZONETYPE_MAXSPEED
};


// new type for player variables
enum struct SurfPlayer
{
	int id; // client id

	int currentStyle;
	bool isRankedStyle;
	bool isFunStyle;
	bool thirdPerson;
	bool repeatMode; // new g_bRepeat
	bool speedDisplay; // new g_bCenterSpeedDisplay
	char styleText[STYLE_TEXT_LENGTH];
	char styleTextSmall[STYLE_TEXT_SMALL_LENGTH];

	// options that save to db
	int initialStyle; // @todo: set up saving
	bool outlines; // outline toggle
	bool hideWeapons; // weapon visibility/pickup toggle

	float cooldown; // global command cooldown
}

/* Natives */

/**
 * Checks clients timer status
 *
 * @param client    Client's id
 * @return          True / False
 */
native bool:surftimer_GetTimerStatus(client);

/**
 * Stops client's timer.
 *
 * @param client    Client's id
 * @return          No return
 */
native surftimer_StopTimer(client);

/**
 * Starts client's timer
 *
 * @param client    Client's id
 * @return          No return
 */
native surftimer_EmulateStartButtonPress(client);

/**
 * Finishes a client's run.
 *
 * @param client    Client's id
 * @return          No return
 */
native surftimer_EmulateStopButtonPress(client);

/**
 * Get client's current runtime.
 *
 * @param client     Client's id
 * @return           Client's curren runtime as a float.
 */
native Float:surftimer_GetCurrentTime(client);

/**
 * Checks if the client has VIP status
 *
 * @param client     Clients id
 * @return           True / False
 */
native bool:surftimer_IsClientVip(client);

/**
 * Gets the rank of a client
 *
 * @param client     Client's id
 * @return           Rank as an int / -1 on failure
 */
native surftimer_GetPlayerRank(client);

/**
 * Gets the clients points
 *
 * @param client     Client's id
 * @return           points as an int / -1 on failure
 */
native surftimer_GetPlayerPoints(client);

/**
 * Gets the skillgroup of a client
 *
 * @param client     Client's id
 * @param str		 String to convert
 * @return           Skillgroup as a string / Unranked on failure
 */
native surftimer_GetPlayerSkillgroup(client, String:str[]);

/**
 * Gets current map tier
 * @return          Current map tier
 */
native surftimer_GetMapTier();

/**
 * Gets amount of stages on current map
 * @return          amount of stages on current map / 0 if linear
 */
native surftimer_GetMapStages();

/**
 * Gets a clients name with colour in string
 *
 * @param client     Client's id
 * @param str		 String to convert
 * @return           Players name with color as a string / invalid on failure
 */
native surftimer_GetPlayerNameColored(client, String:str[]);

/**
 * Gets current map wr holder and time
 *
 * @param name		 String to convert for wr holder name
 * @param time		 String to convert for wr holder time
 * @return           total players finished on current map
 */
native surftimer_GetMapData(String:name[], String:time[]);

/**
 * Gets client data
 *
 * @param client	 Client's id
 * @param time		 String to convert for players map time
 * @param rank		 int to convert to players map rank
 * @param country	 String to convert for players country
 * @return           Two strings with wr holder name and time
 */
native surftimer_GetPlayerData(client, String:time[], rank, String:country[]);

/**
 * Safely teleports the client. Does not trigger end touches
 * and sets client location correctly.
 *
 * @param client    		Client's id
 * @param fDestination 		Teleport location
 * @param fAngle 			Teleport angle
 * @param fVelocity 		Teleport velocity
 * @param bStopTimer 		Stop the client's timer, default false
 * @return           true on success / false on failure
 */
native bool:surftimer_SafeTeleport(client, Float:fDestination[3], Float:fAngle[3], Float:fVelocity[3], bool:bStopTimer = false);


native Database IG_GetDatabase();


/*
		FORWARDS
						*/

/**
 * Called when a player finishes a map
 *
 * @param client     Player index.
 * @return           Plugin_Handled; to stop the player from searching.
 */
forward Action:surftimer_OnMapFinished(client, Float:fRunTime, String:sRunTime[54], rank, total);

/**
 * Called when a player recieves a checkpoint either via a stage or checkpoint zone
 *
 * @param client     Player index.
 * @return           Plugin_Handled; to stop the player from searching.
 */
forward Action:surftimer_OnCheckpoint(client, Float:fRunTime, String:sRunTime[54], Float:fPbCp, String:sPbDiff[16], Float:fSrCp, String:sSrDiff[16]);


/**
 * Called when a player finishes a bonus
 *
 * @param client     Player index.
 * @return           Plugin_Handled; to stop the player from searching.
 */
forward Action:surftimer_OnBonusFinished(client, Float:fRunTime, String:sRunTime[54], rank, total, bonusid);

/**
 * Called when a player finishes a map in practice mode
 *
 * @param client     Player index.
 * @return           Plugin_Handled; to stop the player from searching.
 */
 forward Action:surftimer_OnPracticeFinished(client, Float:fRunTime, String:sRunTime[54]);


public SharedPlugin:__pl_surftimer =
{
	name = "surftimer",
	file = "surftimer.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public __pl_surftimer_SetNTVOptional()
{
	MarkNativeAsOptional("surftimer_GetTimerStatus");
	MarkNativeAsOptional("surftimer_StopTimer");
	MarkNativeAsOptional("surftimer_EmulateStartButtonPress");
	MarkNativeAsOptional("surftimer_EmulateStopButtonPress");
	MarkNativeAsOptional("surftimer_GetCurrentTime");
	MarkNativeAsOptional("surftimer_ClientIsVIP");
	MarkNativeAsOptional("surftimer_GetServerRank");
	MarkNativeAsOptional("surftimer_SafeTeleport");
	MarkNativeAsOptional("IG_GetDatabase");
}
