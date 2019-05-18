void RunCallback(DataPack cb, bool error = false) {
    if (cb != INVALID_HANDLE) {
        cb.Reset();
        Function fn = cb.ReadFunction();
        Call_StartFunction(null, fn);
        Call_PushCell(cb);
        Call_PushCell(error);
        Call_Finish();
    }
}
