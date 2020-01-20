static float g_mapLoadStart;
static float g_mapLoadTick;
static int g_mapLoadStep = 0;
static int g_mapLoadUid = 0;
static MapLoadState g_mapLoadState;

void LoadMapStart() {
    LogToFileEx(g_szLogFile, "[surftimer] Starting to load server settings");
    g_mapLoadStart = GetGameTime();
    g_mapLoadUid++;
    g_mapLoadStep = 0;
    g_mapLoadState = MLS_LOADING;
    LoadMapStep();
}
void LoadMapContinue(DataPack cb, bool error) {
    int completedMapUid = cb.ReadCell();
    int completedStep = cb.ReadCell();
    CloseHandle(cb);

    if (completedStep != g_mapLoadStep || completedMapUid != g_mapLoadUid) {
        // Outdated step -- just stop here
        return;
    }
    if (error) {
        g_mapLoadState = MLS_ERROR;
        return;
    }

    float time = GetGameTime() - g_mapLoadTick;
    LogToFileEx(g_szLogFile, "[Surftimer] Finished map load step %i in %fs", g_mapLoadStep, time);
    g_mapLoadStep++;
    LoadMapStep();
}
void LoadMapStep() {
    Function step = INVALID_FUNCTION;
    switch(g_mapLoadStep) {
        case 0: { step = db_viewMapSettings; }
        case 1: { step = db_selectMapZones; }
        case 2: { step = DB_SelectMapOutlines; } // @IG outlines
        case 3: { step = db_GetMapRecord_Pro; }
        case 4: { step = db_viewMapProRankCount; }
        case 5: { step = db_viewFastestBonus; }
        case 6: { step = db_viewBonusTotalCount; }
        case 7: { step = db_selectMapTier; }
        case 8: { step = db_viewRecordCheckpointInMap; }
        case 9: { step = db_CalcAvgRunTime; }
        case 10: { step = db_CalcAvgRunTimeBonus; }
        case 11: { step = db_CalculatePlayerCount; }
        case 12: { step = db_CalculatePlayersCountGreater0; }
        case 13: { step = db_selectSpawnLocations; }
        case 14: { step = db_ClearLatestRecords; }
        case 15: { step = db_GetDynamicTimelimit; }
        case 16: { step = db_GetTotalStages; }
        case 17: { step = db_viewStageRecords; }
        case 18: { step = db_viewTotalStageRecords; }
        case 19: { step = db_selectCurrentMapImprovement; }
        case 20: { step = db_selectAnnouncements; }
    }
    if (step != INVALID_FUNCTION) {
        g_mapLoadTick = GetGameTime();
        DataPack cb = CreateDataPack();
        cb.WriteFunction(LoadMapContinue);
        cb.WriteCell(g_mapLoadUid);
        cb.WriteCell(g_mapLoadStep);
        Call_StartFunction(null, step);
        Call_PushCell(cb);
        Call_Finish();
    } else if (g_mapLoadState == MLS_LOADING) {
        LoadMapFinished();
    }
}
void LoadMapFinished() {
    g_mapLoadState = MLS_LOADED;
    float time = GetGameTime() - g_mapLoadStart;
    LogToFileEx(g_szLogFile, "[Surftimer] Finished map load in %fs", time);
    LoadPlayerNext();
}
MapLoadState GetMapLoadState() {
    return g_mapLoadState;
}
int GetMapLoadStep() {
    return g_mapLoadStep;
}

bool IsMapLoaded() {
    return g_mapLoadState == MLS_LOADED;
}
