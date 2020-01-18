enum PlayerLoadState {
	PLS_UNLOADED,
	PLS_PENDING,
	PLS_LOADING,
	PLS_ERROR,
	PLS_LOADED
}

enum MapLoadState {
	MLS_LOADING,
	MLS_ERROR,
	MLS_LOADED
}

char g_szLogFile[PLATFORM_MAX_PATH];

// PR Commands
int g_iPrTarget[MAXPLAYERS + 1];
int g_totalStagesPr[MAXPLAYERS + 1];
int g_totalBonusesPr[MAXPLAYERS + 1];

bool g_resetButtons[MAXPLAYERS];

// Speed Gradient
char g_szSpeedColour[MAXPLAYERS + 1];

// Show Zones
bool g_bShowZones[MAXPLAYERS + 1];

/*----------  Stages  ----------*/

// Which stage is the client in
int g_Stage[MAXZONEGROUPS][MAXPLAYERS + 1];
int g_WrcpStage[MAXPLAYERS + 1];

bool g_bhasStages;

/*----------  Spawn Locations  ----------*/
float g_fSpawnLocation[MAXZONEGROUPS][CPLIMIT][2][3];
float g_fSpawnAngle[MAXZONEGROUPS][CPLIMIT][2][3];
float g_fSpawnVelocity[MAXZONEGROUPS][CPLIMIT][2][3];
bool g_bGotSpawnLocation[MAXZONEGROUPS][CPLIMIT][2];

/*----------  Bonus Variables  ----------*/

// Name of the #1 in the current maps bonus
char g_szBonusFastest[MAXZONEGROUPS][MAX_NAME_LENGTH];

// Fastest bonus time in 00:00:00:00 format
char g_szBonusFastestTime[MAXZONEGROUPS][64];

// Clients personal bonus record in the current map
float g_fPersonalRecordBonus[MAXZONEGROUPS][MAXPLAYERS + 1];

// Personal bonus record in 00:00:00 format
char g_szPersonalRecordBonus[MAXZONEGROUPS][MAXPLAYERS + 1][64];

// Fastest bonus time in the current map
float g_fBonusFastest[MAXZONEGROUPS];

// Old record time, for prints + counting
float g_fOldBonusRecordTime[MAXZONEGROUPS];

// Clients personal bonus rank in the current map
int g_MapRankBonus[MAXZONEGROUPS][MAXPLAYERS + 1];

// Old rank in bonus
int g_OldMapRankBonus[MAXZONEGROUPS][MAXPLAYERS + 1];

// Has the client missed his best bonus time
int g_bMissedBonusBest[MAXPLAYERS + 1];

// Used to make sure bonus finished prints are correct
int g_tmpBonusCount[MAXZONEGROUPS];

// Amount of players that have passed the bonus in current map
int g_iBonusCount[MAXZONEGROUPS];

// Does map have a bonus?
bool g_bhasBonus;

// IG: Record bonus start speeds by style
int g_iRecordBonusStartSpeed[MAX_STYLES][MAXZONEGROUPS];

// IG: Personal best bonus start speeds by style
int g_iPBBonusStartSpeed[MAX_STYLES][MAXZONEGROUPS][MAXPLAYERS + 1];

/*----------  Checkpoint Variables  ----------*/

// Clients best run's times
float g_fCheckpointTimesRecord[MAXZONEGROUPS][MAXPLAYERS + 1][CPLIMIT];

// Clients current run's times
float g_fCheckpointTimesNew[MAXZONEGROUPS][MAXPLAYERS + 1][CPLIMIT];

// Server record checkpoint times
float g_fCheckpointServerRecord[MAXZONEGROUPS][CPLIMIT];

// Last difference to the server record checkpoint
char g_szLastSRDifference[MAXPLAYERS + 1][64];

// Last difference to clients own record checkpoint
char g_szLastPBDifference[MAXPLAYERS + 1][64];

// The time difference was shown, used to show for a few seconds in timer panel
float g_fLastDifferenceTime[MAXPLAYERS + 1];

// Used to calculate time gain / lost
float tmpDiff[MAXPLAYERS + 1];

// Used to track which checkpoint was last reached
int lastCheckpoint[MAXZONEGROUPS][MAXPLAYERS + 1];

// Clients checkpoints have been found?
bool g_bCheckpointsFound[MAXZONEGROUPS][MAXPLAYERS + 1];

// Map record checkpoints found?
bool g_bCheckpointRecordFound[MAXZONEGROUPS];

// The biggest % amount the player has reached in current map
float g_fMaxPercCompleted[MAXPLAYERS + 1];

int g_iCurrentCheckpoint[MAXPLAYERS + 1];

/*----------  Advert Variables  ----------*/

// Defines which advert to play
int g_Advert;

/*----------  Maptier Variables  ----------*/

// The string for each zonegroup
char g_sTierString[512];

// Tier data found in ZGrp
bool g_bTierFound;

// Tier announce timer
Handle AnnounceTimer[MAXPLAYERS + 1];

/*----------  Zone Variables  ----------*/

// Ignore end zone end touch if teleporting from inside a zone
bool g_bIgnoreZone[MAXPLAYERS + 1];

// Which zone the client is in 0 = ZoneType, 1 = ZoneTypeId, 2 = ZoneGroup, 3 = ZoneID
int g_iClientInZone[MAXPLAYERS + 1][4];

// Zone type count in each zoneGroup
int g_mapZonesTypeCount[MAXZONEGROUPS][ZONEAMOUNT];

// Zone group's name
char g_szZoneGroupName[MAXZONEGROUPS][128];

// Map Zone array
MapZone g_mapZones[MAXZONES];
// int g_mapZones[MAXZONES][MapZone];

// The total amount of zones in the map
int g_mapZonesCount;

// Map zone count in zonegroups
int g_mapZoneCountinGroup[MAXZONEGROUPS];

// Zone group cound
int g_mapZoneGroupCount;

// Additional zone corners, can't store multi dimensional arrays in enums..
float g_fZoneCorners[MAXZONES][8][3];

/*----------  AntiJump & AntiDuck Variables  ----------*/
bool g_bInDuck[MAXPLAYERS + 1] = false;
bool g_bInJump[MAXPLAYERS + 1] = false;
bool g_bInPushTrigger[MAXPLAYERS + 1] = false;
bool g_bJumpZoneTimer[MAXPLAYERS + 1] = false;
bool g_bInStartZone[MAXPLAYERS + 1] = false;
bool g_bInStageZone[MAXPLAYERS + 1];

/*----------  MaxSpeed Variables  ----------*/
float g_bInMaxSpeed[MAXPLAYERS + 1];

/*----------  Custom Titles  ----------*/
char g_szCustomTitleRaw[MAXPLAYERS + 1][MAX_RAWTITLE_LENGTH];
bool g_bDbCustomTitleInUse[MAXPLAYERS + 1] = false;
// 0 = name, 1 = text;
int g_iCustomColours[MAXPLAYERS + 1][2];
bool g_bUpdatingColours[MAXPLAYERS + 1];

/*----------  WRCP Variables  ----------*/

// Clients best WRCP times
float g_fWrcpRecord[MAXPLAYERS + 1][CPLIMIT][MAX_STYLES];

bool g_bWrcpTimeractivated[MAXPLAYERS + 1] = false;
bool g_bWrcpEndZone[MAXPLAYERS + 1] = false;
int g_CurrentStage[MAXPLAYERS + 1];
float g_fStartWrcpTime[MAXPLAYERS + 1];
float g_fFinalWrcpTime[MAXPLAYERS + 1];

// Total time the run took in 00:00:00 format
char g_szFinalWrcpTime[MAXPLAYERS + 1][32];
float g_fCurrentWrcpRunTime[MAXPLAYERS + 1];
int g_StageRank[MAXPLAYERS + 1][CPLIMIT];
float g_fStageRecord[CPLIMIT];
char g_szRecordStageTime[CPLIMIT];

// will be used, need to fix query
// char g_szRecordStagePlayer[CPLIMIT];
// char g_szRecordStageSteamID[CPLIMIT];

int g_TotalStageRecords[CPLIMIT];
int g_TotalStages;
float g_fWrcpMenuLastQuery[MAXPLAYERS + 1] = 1.0;
bool g_bSelectWrcp[MAXPLAYERS + 1];
int g_iWrcpMenuStyleSelect[MAXPLAYERS + 1];
char g_szWrcpMapSelect[MAXPLAYERS + 1][128];
bool g_bStageSRVRecord[MAXPLAYERS + 1][CPLIMIT];
char g_szStageRecordPlayer[CPLIMIT][MAX_NAME_LENGTH];
// bool g_bFirstStageRecord[CPLIMIT];

/*----------  Map Settings Variables ----------*/
float g_fMaxVelocity;
ConVar g_hMaxVelocity;
float g_fAnnounceRecord;
bool g_bGravityFix;
ConVar g_hGravityFix;

/*----------  Style Variables  ----------*/

// 0 = normal, 1 = SW, 2 = HSW, 3 = BW, 4 = Low-Gravity, 5 = Slow Motion, 6 = Fast Forward
int g_iCurrentStyle[MAXPLAYERS + 1];
int g_iInitalStyle[MAXPLAYERS + 1];
char g_szInitalStyle[MAXPLAYERS + 1][256];
char g_szStyleHud[MAXPLAYERS + 1][32];
bool g_bRankedStyle[MAXPLAYERS + 1];
bool g_bFunStyle[MAXPLAYERS + 1];
int g_KeyCount[MAXPLAYERS + 1] = 0;

// Map Styles
int g_StyleMapRank[MAX_STYLES][MAXPLAYERS + 1];
int g_OldStyleMapRank[MAX_STYLES][MAXPLAYERS + 1];
float g_fPersonalStyleRecord[MAX_STYLES][MAXPLAYERS + 1];
char g_szPersonalStyleRecord[MAX_STYLES][MAXPLAYERS + 1][256];
float g_fRecordStyleMapTime[MAX_STYLES];
char g_szRecordStyleMapTime[MAX_STYLES][64];
char g_szRecordStylePlayer[MAX_STYLES][MAX_NAME_LENGTH];
char g_szRecordStyleMapSteamID[MAX_STYLES][MAX_NAME_LENGTH];
int g_StyleMapTimesCount[MAX_STYLES];
bool g_bStyleMapFirstRecord[MAX_STYLES][MAXPLAYERS + 1];
bool g_bStyleMapPBRecord[MAX_STYLES][MAXPLAYERS + 1];
bool g_bStyleMapSRVRecord[MAX_STYLES][MAXPLAYERS + 1];

// Bonus Styles
char g_szStyleBonusFastest[MAX_STYLES][MAXZONEGROUPS][MAX_NAME_LENGTH];
char g_szStyleBonusFastestTime[MAX_STYLES][MAXZONEGROUPS][64];
float g_fStylePersonalRecordBonus[MAX_STYLES][MAXZONEGROUPS][MAXPLAYERS + 1];
char g_szStylePersonalRecordBonus[MAX_STYLES][MAXZONEGROUPS][MAXPLAYERS + 1][64];
float g_fStyleBonusFastest[MAX_STYLES][MAXZONEGROUPS];
float g_fStyleOldBonusRecordTime[MAX_STYLES][MAXZONEGROUPS];
int g_StyleMapRankBonus[MAX_STYLES][MAXZONEGROUPS][MAXPLAYERS + 1];
int g_StyleOldMapRankBonus[MAX_STYLES][MAXZONEGROUPS][MAXPLAYERS + 1];
int g_StyletmpBonusCount[MAX_STYLES][MAXZONEGROUPS];
int g_iStyleBonusCount[MAX_STYLES][MAXZONEGROUPS];

// WRCP Styles
float g_fStyleStageRecord[MAX_STYLES][CPLIMIT];
int g_StyleStageRank[MAX_STYLES][MAXPLAYERS + 1][CPLIMIT];
int g_TotalStageStyleRecords[MAX_STYLES][CPLIMIT];
char g_szStyleStageRecordPlayer[MAX_STYLES][MAX_NAME_LENGTH][CPLIMIT];
char g_szStyleRecordStageTime[MAX_STYLES][CPLIMIT];
int g_StyleStageSelect[MAXPLAYERS + 1];

// Style Profiles
int g_ProfileStyleSelect[MAXPLAYERS + 1];
//int g_totalStyleMapTimes[MAXPLAYERS + 1];

/*----------  Player Settings  ----------*/
bool g_bTimerEnabled[MAXPLAYERS + 1];
int g_SpeedGradient[MAXPLAYERS + 1];
int g_SpeedMode[MAXPLAYERS + 1];
bool g_bCenterSpeedDisplay[MAXPLAYERS + 1];
int g_iCenterSpeedEnt[MAXPLAYERS + 1];
// Handle g_hServerTier;
// gain/loss speed colour in centre hud
int g_iPreviousSpeed[MAXPLAYERS + 1];

/*----------  Sounds  ----------*/
bool g_bTop10Time[MAXPLAYERS + 1] = false;

// Rate Limiting Commands
float g_fCommandLastUsed[MAXPLAYERS + 1];
bool g_bRateLimit[MAXPLAYERS + 1];

// MRank Command
char g_szRuntimepro[MAXPLAYERS + 1][32];
int g_totalPlayerTimes[MAXPLAYERS + 1];

// Rank Command
int g_rankArg[MAXPLAYERS + 1];

/*----------  KSF Style Ranking Distribution  ----------*/
int g_GroupMaps[MAX_PR_PLAYERS + 1][MAX_STYLES];
int g_Top10Maps[MAX_PR_PLAYERS + 1][MAX_STYLES];

// 0 = wr, 1 = wrb, 2 = wrcp
int g_WRs[MAX_PR_PLAYERS + 1][MAX_STYLES][3];

// 0 = Map Points, 1 = Bonus Points, 2 = Group Points, 3 = Map WR Points, 4 = Bonus WR Points, 5 = Top 10 Points, 6 = WRCP Points
int g_Points[MAX_PR_PLAYERS + 1][MAX_STYLES][7];

/*----------  KSF Points System  ----------*/
float g_Group1Pc = 0.03125;
float g_Group2Pc = 0.0625;
float g_Group3Pc = 0.125;
float g_Group4Pc = 0.25;
float g_Group5Pc = 0.5;
char g_szMiMapName[MAXPLAYERS + 1][128];
int g_MiType[MAXPLAYERS + 1];
int g_G1Top;
int g_G2Bot;
int g_G2Top;
int g_G3Bot;
int g_G3Top;
int g_G4Bot;
int g_G4Top;
int g_G5Bot;
int g_G5Top;
bool g_bInsertNewTime = false;

/*----------  fluffys tmf & repeat  ----------*/
bool g_bToggleMapFinish[MAXPLAYERS + 1] = true;
bool g_bRepeat[MAXPLAYERS + 1] = false;
bool g_bNotTeleporting[MAXPLAYERS + 1] = true;

// Client Side Autobhop
Handle g_hAutoBhop = INVALID_HANDLE;
Handle g_hEnableBhop = INVALID_HANDLE;

/*----------  Flag Varibles  ----------*/
// ConVar g_hCustomTitlesFlag = null;
// int g_CustomTitlesFlag;
// bool g_bCustomTitlesFlag;

// UNIX Times
int g_iPlayTimeAlive[MAXPLAYERS + 1];
int g_iPlayTimeSpec[MAXPLAYERS + 1];
int g_iPlayTimeAliveSession[MAXPLAYERS + 1];
int g_iPlayTimeSpecSession[MAXPLAYERS + 1];
int g_iTotalConnections[MAXPLAYERS + 1];

Menu g_mTriggerMultipleMenu = null;

// Editing Zones

// If editing zone type
bool g_bEditZoneType[MAXPLAYERS + 1];

// Selected zone's name
char g_CurrentZoneName[MAXPLAYERS + 1][64];

// Selected zone's position
float g_Positions[MAXPLAYERS + 1][2][3];

// Bonus start zone position
float g_fBonusStartPos[MAXPLAYERS + 1][2][3];

// Bonus end zone positions
float g_fBonusEndPos[MAXPLAYERS + 1][2][3];

// Scaling options
float g_AvaliableScales[5] = { 1.0, 5.0, 10.0, 50.0, 100.0 };

// Currently selected zonegroup
int g_CurrentSelectedZoneGroup[MAXPLAYERS + 1];

// Currenyly selected zone's type
int g_CurrentZoneType[MAXPLAYERS + 1];

// What state of editing is happening eg. editing, creating etc.
int g_Editing[MAXPLAYERS + 1];

// Currently selected zone id
int g_ClientSelectedZone[MAXPLAYERS + 1] = { -1, ... };

// Currently selected scale
int g_ClientSelectedScale[MAXPLAYERS + 1];

// Currently selected point
int g_ClientSelectedPoint[MAXPLAYERS + 1];

// Currently selected zone's type ID
int g_CurrentZoneTypeId[MAXPLAYERS + 1];

// Is client renaming zone?
bool g_ClientRenamingZone[MAXPLAYERS + 1];

// Zone team colors
int beamColorEdit[] = { 255, 255, 0, 255 };
int beamColorOther[] = { 255, 255, 255, 128 };

// Zone Default Names
char g_szZoneDefaultNames[ZONEAMOUNT][128] = { "Stop", "Start", "End", "Stage", "Checkpoint", "SpeedStart", "TeleToStart", "Validator", "Checker", "AntiJump", "AntiDuck", "MaxSpeed" };

// Zone sprites
int g_BeamSprite;
int g_HaloSprite;

/*----------  PushFix by Mev, George & Blacky  ----------*/
// https://forums.alliedmods.net/showthread.php?t=267131
ConVar g_hTriggerPushFixEnable;
bool g_bPushing[MAXPLAYERS + 1];

/*----------  Slope Boost Fix by Mev & Blacky  ----------*/
// https://forums.alliedmods.net/showthread.php?t=266888
float g_vCurrent[MAXPLAYERS + 1][3];
float g_vLast[MAXPLAYERS + 1][3];
bool g_bOnGround[MAXPLAYERS + 1];
bool g_bLastOnGround[MAXPLAYERS + 1];
bool g_bFixingRamp[MAXPLAYERS + 1];
ConVar g_hSlopeFixEnable;

/*----------  Forwards  ----------*/
Handle g_MapFinishForward;
Handle g_MapCheckpointForward;
Handle g_BonusFinishForward;
Handle g_PracticeFinishForward;

/*----------  SQL Variables  ----------*/

// SQL driver
Handle g_hDb = null;

// Database type
int g_DbType;

// SteamdID of #1 player in map, used to fetch checkpoint times
char g_szRecordMapSteamID[MAX_NAME_LENGTH];

/*----------  User Commands  ----------*/

// Throttle !usp command
float g_flastClientUsp[MAXPLAYERS + 1];

// Throttle !back to prevent desync on record bots
float g_fLastCommandBack[MAXPLAYERS + 1];

// Client is noclipping
bool g_bNoClip[MAXPLAYERS + 1];

/*----------  User Options  ----------*/

// org variables track the original setting status, on disconnect, check if changed, if so, update new settings to database

// bool to ensure the modules have loaded before resetting
bool g_bLoadedModules[MAXPLAYERS + 1];

// Hides chat
bool g_bHideChat[MAXPLAYERS + 1];

// Hides viewmodel
bool g_bViewModel[MAXPLAYERS + 1];

// Command to disable checkpoints
bool g_bCheckpointsEnabled[MAXPLAYERS + 1];

// Did client enable checkpoints? Then start using them again on the next run
bool g_bActivateCheckpointsOnStart[MAXPLAYERS + 1];

// Enable quake sounds?
bool g_bEnableQuakeSounds[MAXPLAYERS + 1];

// Hide other players?
bool g_bHide[MAXPLAYERS + 1];

// Show spectator list?
bool g_bShowSpecs[MAXPLAYERS + 1];

// Show spectator list?
bool g_bAutoBhopClient[MAXPLAYERS + 1];


// centre hud new
bool g_bCentreHud[MAXPLAYERS + 1];
int g_iCentreHudModule[MAXPLAYERS + 1][6];

// side hud new
bool g_bSpecListOnly[MAXPLAYERS + 1];
bool g_bSideHud[MAXPLAYERS + 1];
int g_iSideHudModule[MAXPLAYERS + 1][5];

// Custom tele side
int g_iTeleSide[MAXPLAYERS + 1];

/*----------  Run Variables  ----------*/

// Clients personal record in map
float g_fPersonalRecord[MAXPLAYERS + 1];

// Is clients timer running
bool g_bTimerRunning[MAXPLAYERS + 1];

// Used to check if a clients run is valid in validator and checker zones
bool g_bValidRun[MAXPLAYERS + 1];

// First bonus time in map?
bool g_bBonusFirstRecord[MAXPLAYERS + 1];

// Personal best time in bonus
bool g_bBonusPBRecord[MAXPLAYERS + 1];

// New server record in bonus
bool g_bBonusSRVRecord[MAXPLAYERS + 1];

// How many seconds were improved / lost in that run
char g_szBonusTimeDifference[MAXPLAYERS + 1];

// Time when run was started
float g_fStartTime[MAXPLAYERS + 1];

// Total time the run took
float g_fFinalTime[MAXPLAYERS + 1];

// Total time the run took in 00:00:00 format
char g_szFinalTime[MAXPLAYERS + 1][32];

// Time spent in !pause this run
float g_fPauseTime[MAXPLAYERS + 1];

// Time when !pause started
float g_fStartPauseTime[MAXPLAYERS + 1];

// Current runtime
float g_fCurrentRunTime[MAXPLAYERS + 1];

// Missed personal record time?
bool g_bMissedMapBest[MAXPLAYERS + 1];

// Was players run his first time finishing the map?
bool g_bMapFirstRecord[MAXPLAYERS + 1];

// Was players run his personal best?
bool g_bMapPBRecord[MAXPLAYERS + 1];

// Was players run the new server record?
bool g_bMapSRVRecord[MAXPLAYERS + 1];

// Used to print the client's new times difference to record
char g_szTimeDifference[MAXPLAYERS + 1][32];

// Record map time in seconds
float g_fRecordMapTime;

// IG: Record map start speeds by style
int g_iRecordMapStartSpeed[MAX_STYLES];

// IG: Personal best start speeds by style
int g_iPBMapStartSpeed[MAX_STYLES][MAXPLAYERS + 1];

// IG: Run start speed
int g_iStartSpeed[MAXPLAYERS + 1];

// Record map time in 00:00:00 format
char g_szRecordMapTime[64];

// Client's peronal record in 00:00:00 format
char g_szPersonalRecord[MAXPLAYERS + 1][64];

// Average map time
float g_favg_maptime;

// Average bonus times TODO: Combine with g_favg_maptime
float g_fAvg_BonusTime[MAXZONEGROUPS];

// If timer is started for the first time, print avg times
bool g_bFirstTimerStart[MAXPLAYERS + 1];

// Client has timer paused
bool g_bPause[MAXPLAYERS + 1];

// How many times the map has been beaten
int g_MapTimesCount;

// Clients rank in current map
int g_MapRank[MAXPLAYERS + 1];

// Clients old rank
int g_OldMapRank[MAXPLAYERS + 1];

// Current map's record player's name
char g_szRecordPlayer[MAX_NAME_LENGTH];

/*----------  Replay Variables  ----------*/

// Checks if the bot is new, if so, set weapon
bool g_bNewRecordBot;

// Checks if the bot is new, if so, set weapon
bool g_bNewBonusBot;

// Used to track teleportations
Handle g_hTeleport = null;

// Client is being recorded
Handle g_hRecording[MAXPLAYERS + 1];

// Fix for trigger_push affecting bots
Handle g_hLoadedRecordsAdditionalTeleport = null;
Handle g_hRecordingAdditionalTeleport[MAXPLAYERS + 1];

// Is mimicing a record
Handle g_hBotMimicsRecord[MAXPLAYERS + 1] = { null, ... };

// Timer to refresh bot trails
Handle g_hBotTrail[2] = { null, null };

// Replay start position
float g_fInitialPosition[MAXPLAYERS + 1][3];

// Replay start angle
float g_fInitialAngles[MAXPLAYERS + 1][3];

// Is teleport valid?
bool g_bValidTeleportCall[MAXPLAYERS + 1];

// Don't allow starting a new run if saving a record run
bool g_bNewReplay[MAXPLAYERS + 1];
bool g_bNewBonus[MAXPLAYERS + 1];

bool g_createAdditionalTeleport[MAXPLAYERS + 1];
int g_BotMimicRecordTickCount[MAXPLAYERS + 1] = { 0, ... };
int g_BotActiveWeapon[MAXPLAYERS + 1] = { -1, ... };
int g_CurrentAdditionalTeleportIndex[MAXPLAYERS + 1];
int g_RecordedTicks[MAXPLAYERS + 1];
int g_RecordPreviousWeapon[MAXPLAYERS + 1];
int g_OriginSnapshotInterval[MAXPLAYERS + 1];
int g_BotMimicTick[MAXPLAYERS + 1] = { 0, ... };

// Record bot client ID
int g_RecordBot = -1;

// Bonus bot client ID
int g_BonusBot = -1;

// Info bot client ID
int g_InfoBot = -1;

// WRCP bot client ID
int g_WrcpBot = -1;

// Replay is at the end
bool g_bReplayAtEnd[MAXPLAYERS + 1];

// Make replay stand still for long enough for trail to die
float g_fReplayRestarted[MAXPLAYERS + 1];

// Replay bot name
char g_szReplayName[128];

// Replay bot time
char g_szReplayTime[128];

// Replay bot name
char g_szBonusName[128];

// Replay bot time
char g_szBonusTime[128];

char g_szWrcpReplayName[CPLIMIT][128];
char g_szWrcpReplayTime[CPLIMIT][128];
int g_BonusBotCount;
int g_iCurrentBonusReplayIndex;
int g_iBonusToReplay[MAXZONEGROUPS + 1];
float g_fReplayTimes[MAXZONEGROUPS][MAX_STYLES];
int g_iManualBonusToReplay;
int g_iCurrentlyPlayingStage;

/*----------  Misc  ----------*/

// Used to check if a player just joined the server
float g_fMapStartTime;

// Array that holds SkillGroup objects in it
Handle g_hSkillGroups = null;

// Used to limit error message spam too often
float g_fErrorMessage[MAXPLAYERS + 1];

// Used to track the time the player took to write the second !r, if too long, reset the boolean
float g_fClientRestarting[MAXPLAYERS + 1];

// Client wanted to restart run
bool g_bClientRestarting[MAXPLAYERS + 1];

// Last time the client used noclip
float g_fLastTimeNoClipUsed[MAXPLAYERS + 1];

// Does client have a respawn location in memory?
bool g_bRespawnPosition[MAXPLAYERS + 1];

// Client's last speed, used in panels
float g_fLastSpeed[MAXPLAYERS + 1];

// Was plugin loaded late?
bool g_bLateLoaded = false;

// Known mapchooser loaded? Used to update info bot
bool g_bMapChooser;

// If call admin, ignore chat message
bool g_bClientOwnReason[MAXPLAYERS + 1];

// Has client used noclip to gain current speed
bool g_bNoClipUsed[MAXPLAYERS + 1];

// Map finished overlay
bool g_bOverlay[MAXPLAYERS + 1];

// Is client spectating
bool g_bSpectate[MAXPLAYERS + 1];

// First time client joined game, show start messages & start timers
bool g_bFirstTeamJoin[MAXPLAYERS + 1];

// First time client spawned
bool g_bFirstSpawn[MAXPLAYERS + 1];
bool g_bSelectProfile[MAXPLAYERS + 1];

// Is client teleporting from spectate?
bool g_specToStage[MAXPLAYERS + 1];

// Location where client is spawned from spectate
float g_fTeleLocation[MAXPLAYERS + 1][3];

// Used to clear ragdolls from ground
int g_ragdolls = -1;

// Server tickrate
int g_Server_Tickrate;

// Who the client is spectating?
int g_SpecTarget[MAXPLAYERS + 1];

// Buttons the client is using, used to show them when specating
int g_LastButton[MAXPLAYERS + 1];

// The amount of MVP's a client has  TODO: make sure this is used everywhere
int g_MVPStars[MAXPLAYERS + 1];

// What color is client's name in chat (based on rank)
int g_PlayerChatRank[MAXPLAYERS + 1];

// Clients rank, colored, used in chat
char g_pr_chat_coloredrank[MAXPLAYERS + 1][256];

// Client's rank, non-colored, used in clantag
char g_pr_rankname[MAXPLAYERS + 1][32];
char g_pr_namecolour[MAXPLAYERS + 1][32];

// Map's prefix, used to execute prefix cfg's
char g_szMapPrefix[2][32];

// Current map's name
char g_szMapName[128];

// Info panel text when spectating
char g_szPlayerPanelText[MAXPLAYERS + 1][512];

// Country codes
char g_szCountry[MAXPLAYERS + 1][100];
char g_szCountryCode[MAXPLAYERS + 1][16];

// Client's steamID
char g_szSteamID[MAXPLAYERS + 1][32];

// Blocked chat commands
char g_BlockedChatText[256][256];

// Last time an overlay was displayed
float g_fLastOverlay[MAXPLAYERS + 1];

// Incorrect stage time fix by samatazz, need to find a cleaner alternative
// https://github.com/samatazz/Surftimer/commit/cee156ee35d905422d44154053614c7f3c9199a9
bool g_wrcpGlitchStopper[MAXPLAYERS + 1];

// Checks for vmutes on a player
bool g_bIsVmuted[MAXPLAYERS + 1];

// Zephyrus' third person plugin
bool g_bThirdPerson[MAXPLAYERS + 1];

// Hide weapons toggle
bool g_bHideWeapons[MAXPLAYERS + 1];

// Last hide weapon command time (includes sm_showweps)
float g_fLastHideWeapons[MAXPLAYERS + 1];

/*----------  Player location restoring  ----------*/

// Clients location was restored this run
bool g_bPositionRestored[MAXPLAYERS + 1];

// Show client restore message?
bool g_bRestorePositionMsg[MAXPLAYERS + 1];

// Clients position is being restored
bool g_bRestorePosition[MAXPLAYERS + 1];

// Client's last location, used on recovering run and coming back from spectate
float g_fPlayerCordsLastPosition[MAXPLAYERS + 1][3];

// Client's last time, used on recovering run and coming back from spec
float g_fPlayerLastTime[MAXPLAYERS + 1];

// Client's last angles, used on recovering run and coming back from spec
float g_fPlayerAnglesLastPosition[MAXPLAYERS + 1][3];

// Used in restoring players location
float g_fPlayerCordsRestore[MAXPLAYERS + 1][3];

// Used in restoring players angle
float g_fPlayerAnglesRestore[MAXPLAYERS + 1][3];

// Last time profile was queried by player, spam protection
float g_fProfileMenuLastQuery[MAXPLAYERS + 1];

// Tracking menu level
int g_MenuLevel[MAXPLAYERS + 1];

// !Profile name
char g_szProfileName[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_szProfileSteamId[MAXPLAYERS + 1][32];

// Admin flag required for !ckadmin
int g_AdminMenuFlag;
ConVar g_hAdminMenuFlag = null;

// Add !ckadmin to !admin
Handle g_hAdminMenu = null;

// Weird admin menu trickery TODO: wtf
int g_AdminMenuLastPage[MAXPLAYERS + 1];

/*----------  Player Points  ----------*/

// Is point recalculation in progress?
bool g_pr_RankingRecalc_InProgress;

// Clients points are being calculated
bool g_pr_Calculating[MAXPLAYERS + 1];

// Has this profile been recalculated?
bool g_bProfileRecalc[MAX_PR_PLAYERS + 1];

// Point recalculation type
bool g_bManualRecalc;

// Print the amount of gained points to chat?
bool g_pr_showmsg[MAXPLAYERS + 1];

// Is clients points being recalculated?
bool g_bRecalcRankInProgess[MAXPLAYERS + 1];

// Client ID being recalculated
int g_pr_Recalc_ClientID = 0;

// ClientID that started the recalculation
int g_pr_Recalc_AdminID = -1;

// Ranked player count on server
int g_pr_AllPlayers[MAX_STYLES];

// Player count with points
int g_pr_RankedPlayers[MAX_STYLES];

// The amount of clients that get recalculated in a full recalculation
int g_pr_TableRowCount;

// Clients points
int g_pr_points[MAX_PR_PLAYERS + 1][MAX_STYLES];

// Clients points before recalculation
int g_pr_oldpoints[MAX_PR_PLAYERS + 1][MAX_STYLES];

// How many maps a client has finished
int g_pr_finishedmaps[MAX_PR_PLAYERS + 1][MAX_STYLES];

// How many bonuses a client has finished
int g_pr_finishedbonuses[MAX_PR_PLAYERS + 1][MAX_STYLES];

// How many stages a client has finished
int g_pr_finishedstages[MAX_PR_PLAYERS + 1][MAX_STYLES];

// Players server rank
int g_PlayerRank[MAXPLAYERS + 1][MAX_STYLES];

// Used to update client's name in database
char g_pr_szName[MAX_PR_PLAYERS + 1][64];

// steamid of client being recalculated
char g_pr_szSteamID[MAX_PR_PLAYERS + 1][32];

/*----------  Practice Mode  ----------*/

// Client has created atleast one checkpoint
bool g_bCreatedTeleport[MAXPLAYERS + 1];

// Client is in the practice mode
bool g_bPracticeMode[MAXPLAYERS + 1];

/*----------  Reports  ----------*/
bool g_bReportSuccess[MAXPLAYERS + 1];

// Chat Colors in String Format
char szWHITE[12], szDARKRED[12], szPURPLE[12], szGREEN[12], szLIGHTGREEN[12], szLIMEGREEN[12], szRED[12], szGRAY[12], szYELLOW[12], szDARKGREY[12], szBLUE[12], szDARKBLUE[12], szLIGHTBLUE[12], szPINK[12], szLIGHTRED[12], szORANGE[12];

// hook zones
Handle g_hTriggerMultiple;
int g_iTeleportingZoneId[MAXPLAYERS + 1];
int g_iZonegroupHook[MAXPLAYERS + 1];
int g_iSelectedTrigger[MAXPLAYERS + 1];

// Store
int g_iMapTier;
bool g_bRankedMap;
// Handle g_hStore;

// Late Load Linux fix
Handle g_cvar_sv_hibernate_when_empty = INVALID_HANDLE;

// Fix prehopping in zones
bool g_bJumpedInZone[MAXPLAYERS + 1];
float g_fJumpedInZoneTime[MAXPLAYERS + 1];
bool g_bResetOneJump[MAXPLAYERS + 1];

// Stage replays

// Number of frames where the replay started being recorded
int g_StageRecStartFrame[MAXPLAYERS+1];

// Ammount of additional teleport when the replay started being recorded
int g_StageRecStartAT[MAXPLAYERS+1];

// Replay start position
float g_fStageInitialPosition[MAXPLAYERS + 1][3];

// Replay start angle
float g_fStageInitialAngles[MAXPLAYERS + 1][3];


bool g_bSavingWrcpReplay[MAXPLAYERS + 1];
int g_StageReplayCurrentStage;
int g_StageReplaysLoop;
bool g_bStageReplay[CPLIMIT];
bool g_bFirstStageReplay;
float g_fStageReplayTimes[CPLIMIT];

// Server Announcements
int g_iServerID;
int g_iLastID;
bool g_bHasLatestID;

// Show Triggers https://forums.alliedmods.net/showthread.php?t=290356
int g_iTriggerTransmitCount;
bool g_bShowTriggers[MAXPLAYERS + 1];
int g_Offset_m_fEffects = -1;

/*----------  !startpos Goose  ----------*/
float g_fStartposLocation[MAXPLAYERS + 1][MAXZONEGROUPS][3];
float g_fStartposAngle[MAXPLAYERS + 1][MAXZONEGROUPS][3];
bool g_bStartposUsed[MAXPLAYERS + 1][MAXZONEGROUPS];

// Strafe Sync (Taken from shavit's bhop timer)
int g_iGoodGains[MAXPLAYERS + 1];
int g_iTotalMeasures[MAXPLAYERS + 1];
float g_fAngleCache[MAXPLAYERS + 1];

// Save locs
int g_iSaveLocCount;
float g_fSaveLocCoords[MAX_LOCS][3]; // [loc id][coords]
float g_fSaveLocAngle[MAX_LOCS][3]; // [loc id][angle]
float g_fSaveLocVel[MAX_LOCS][3]; // [loc id][velocity]
char g_szSaveLocTargetname[MAX_LOCS][128]; // [loc id]
char g_szSaveLocClientName[MAX_LOCS][MAX_NAME_LENGTH];
int g_iLastSaveLocIdClient[MAXPLAYERS + 1];
float g_fLastCheckpointMade[MAXPLAYERS + 1];
int g_iSaveLocUnix[MAX_LOCS]; // [loc id]
int g_iMenuPosition[MAXPLAYERS + 1];

char g_sServerName[256];
ConVar g_hHostName = null;

// discord bugtracker
char g_sBugType[MAXPLAYERS + 1][32];
char g_sBugMsg[MAXPLAYERS + 1][256];

// Teleport Destinations
Handle g_hDestinations;

// CPR command
float g_fClientCPs[MAXPLAYERS + 1][36];
float g_fTargetTime[MAXPLAYERS + 1];
char g_szTargetCPR[MAXPLAYERS + 1][MAX_NAME_LENGTH];
char g_szCPRMapName[MAXPLAYERS + 1][128];
// float g_fTargetCPs[MAXPLAYERS + 1][35];

// surf_christmas2
bool g_bUsingStageTeleport[MAXPLAYERS + 1];

// Footsteps
ConVar g_hFootsteps = null;

// Prespeed in zones
int g_iWaitingForResponse[MAXPLAYERS + 1];

// Trigger List so we can store the names of the triggers before we rename them
Handle g_TriggerMultipleList;

// Chat Prefix
char g_szChatPrefix[64];
char g_szMenuPrefix[64];
ConVar g_hChatPrefix = null;

// Play Replay command
bool g_bManualReplayPlayback;
bool g_bManualBonusReplayPlayback;
bool g_bManualStageReplayPlayback;
int g_iManualReplayCount;
int g_iManualBonusReplayCount;
int g_iManualStageReplayCount;
int g_iSelectedReplayType;
int g_iSelectedReplayBonus;
int g_iSelectedReplayStage;
int g_iSelectedReplayStyle;
int g_iSelectedBonusReplayStyle;

/* Admin delete menu */

char g_EditingMap[MAXPLAYERS + 1][256];
int g_SelectedEditOption[MAXPLAYERS + 1];
int g_SelectedStyle[MAXPLAYERS + 1];
int g_SelectedType[MAXPLAYERS + 1];

char g_EditTypes[][] =  { "Main", "Stage", "Bonus" };
char g_EditStyles[][] =  { "Normal", "Sideways", "Half-Sideways", "Backwards", "Low-Gravity", "Slow Motion", "Fast Forward"};

// Checkpoint/Stage enforcer
int g_iTotalCheckpoints;
int g_iCheckpointsPassed[MAXPLAYERS + 1];
bool g_bIsValidRun[MAXPLAYERS + 1];

// Prestige
bool g_bPrestigeCheck[MAXPLAYERS + 1];

// Menus mapname
char g_szMapNameFromDatabase[MAXPLAYERS + 1][128];

// New speed limit variables
bool g_bInBhop[MAXPLAYERS + 1];
bool g_bFirstJump[MAXPLAYERS + 1];
int g_iLastJump[MAXPLAYERS + 1];
int g_iTicksOnGround[MAXPLAYERS + 1];
bool g_bNewStage[MAXPLAYERS + 1];
bool g_bLeftZone[MAXPLAYERS + 1];


/*===================================
=         Predefined Arrays         =
===================================*/

char g_sz10000mvGradient[][] =
{
	"#FFFFFF",
	"#F4FFF4",
	"#E9FFE9",
	"#DFFFDF",
	"#D4FFD4",
	"#C9FFC9",
	"#BFFFBF",
	"#B4FFB4",
	"#AAFFAA",
	"#9FFF9F",
	"#94FF94",
	"#8AFF8A",
	"#7FFF7F",
	"#74FF74",
	"#74FF74",
	"#5FFF5F",
	"#55FF55",
	"#4AFF4A",
	"#3FFF3F",
	"#35FF35",
	"#2AFF2A",
	"#1FFF1F",
	"#15FF15",
	"#0AFF0A",
	"#00FF00"
};

char g_sz3500mvGradient[][] =
{
	"#FFFFFF",
	"#F7FFF7",
	"#F0FFF0",
	"#E8FFE8",
	"#E1FFE1",
	"#D9FFD9",
	"#D2FFD2",
	"#CAFFCA",
	"#C3FFC3",
	"#BBFFBB",
	"#B4FFB4",
	"#ACFFAC",
	"#A5FFA5",
	"#9DFF9D",
	"#96FF96",
	"#8EFF8E",
	"#87FF87",
	"#7FFF7F",
	"#78FF78",
	"#70FF70",
	"#69FF69",
	"#61FF61",
	"#5AFF5A",
	"#52FF52",
	"#4BFF4B",
	"#43FF43",
	"#3CFF3C",
	"#34FF34",
	"#2DFF2D",
	"#25FF25",
	"#1EFF1E",
	"#16FF16",
	"#0FFF0F",
	"#07FF07",
	"#00FF00"
};

char g_szRainbowGradient[][] =
{
	"#FFFFFF",
	"#FFD4F0",
	"#e2aaff",
	"#e38be6",
	"#7f7fff",
	"#55c6ff",
	"#2affb8",
	"#00ff00"
};

char g_szStyleRecordPrint[][] =
{
	"",
	"* Sideways *",
	"* Half-Sideways *",
	"* Backwards *",
	"* Low-Gravity *",
	"* Slow Motion *",
	"* Fast Forward *"
};

char g_szStyleMenuPrint[][] =
{
	"",
	"Sideways",
	"Half-Sideways",
	"Backwards",
	"Low-Gravity",
	"Slow Motion",
	"Fast Forward"
};

char g_szStyleAcronyms[][] =
{
	"n",
	"sw",
	"hsw",
	"bw",
	"lg",
	"sm",
	"ff"
};

char EntityList[][] = 													// Disable entities that often break maps
{
	"logic_timer",
	"team_round_timer",
	"logic_relay",
	"player_weaponstrip",
	"trigger_weapon_strip",
	"game_player_equip"
};

char RadioCMDS[][] = 													// Disable radio commands
{
	"coverme", "takepoint", "holdpos", "regroup", "followme", "takingfire", "go", "fallback", "sticktog",
	"getinpos", "stormfront", "report", "roger", "enemyspot", "needbackup", "sectorclear", "inposition",
	"reportingin", "getout", "negative", "enemydown", "cheer", "thanks", "nice", "compliment"
};
