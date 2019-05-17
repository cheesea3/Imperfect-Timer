void RunCallback(DataPack cb) {
    if (cb != INVALID_HANDLE) {
        cb.Reset();
        Function fn = cb.ReadFunction();
        Call_StartFunction(null, fn);
        Call_PushCell(cb);
        Call_Finish();
    }
}

void LoadMapStart() {
    LogToFileEx(g_szLogFile, "[surftimer] Starting to load server settings");
    g_fServerLoading[0] = GetGameTime();
    g_mapLoadUid++;
    g_mapLoadStep = 0;
    LoadMapStep();
}
void LoadMapContinue(DataPack cb) {
    int completedMapUid = cb.ReadCell();
    int completedStep = cb.ReadCell();
    CloseHandle(cb);

    if (completedStep == g_mapLoadStep && completedMapUid == g_mapLoadUid) {
        g_mapLoadStep++;
        LoadMapStep();
    }
}
Action LoadMapStep() {
    Function step = INVALID_FUNCTION;
    switch(g_mapLoadStep) {
        case 0: { step = db_viewMapSettings; }
        case 1: { step = db_selectMapZones; }
        case 2: { step = db_GetMapRecord_Pro; }
        case 3: { step = db_viewMapProRankCount; }
        case 4: { step = db_viewFastestBonus; }
        case 5: { step = db_viewBonusTotalCount; }
        case 6: { step = db_selectMapTier; }
        case 7: { step = db_viewRecordCheckpointInMap; }
        case 8: { step = db_CalcAvgRunTime; }
        case 9: { step = db_CalcAvgRunTimeBonus; }
        case 10: { step = db_CalculatePlayerCount; }
        case 11: { step = db_CalculatePlayersCountGreater0; }
        case 12: { step = db_selectSpawnLocations; }
        case 13: { step = db_ClearLatestRecords; }
        case 14: { step = db_GetDynamicTimelimit; }
        case 15: { step = db_GetTotalStages; }
        case 16: { step = db_viewStageRecords; }
        case 17: { step = db_viewTotalStageRecords; }
        case 18: { step = db_selectCurrentMapImprovement; }
        case 19: { step = db_selectAnnouncements; }
    }
    if (step != INVALID_FUNCTION) {
        DataPack cb = CreateDataPack();
        cb.WriteFunction(LoadMapContinue);
        cb.WriteCell(g_mapLoadUid);
        cb.WriteCell(g_mapLoadStep);
        Call_StartFunction(null, step);
        Call_PushCell(cb);
        Call_Finish();
    } else if (!g_bServerDataLoaded) {
        LoadMapFinished();
    }
}
void LoadMapFinished() {
    g_bServerDataLoaded = true;
    g_fServerLoading[1] = GetGameTime();
    float time = g_fServerLoading[1] - g_fServerLoading[0];
    LogToFileEx(g_szLogFile, "[Surftimer] Finished loading server settings in %fs", time);
    loadAllClientSettings();
}
