package io.github.jqssun.displayextend.shizuku;

interface IUserService {

    void destroy() = 16777114; // destroy method defined by Shizuku server

    void exit() = 1; // exit method defined by user

    String fetchLogs() = 2;

    String dumpInput() = 3;

    void setScreenPower(int powerMode) = 4;

    void startListenVolumeKey() = 5;

    void stopListenVolumeKey() = 6;
}
