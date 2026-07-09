#pragma once

#if defined(Q_OS_MAC) || defined(Q_OS_MACOS)
void hideMacOSMenuBar();
int  macMainScreenWidth();
int  macMainScreenHeight();
int  macExternalPlaybackScreenIndex();
void configureMacSleepPrevention(bool enabled, int lowBatteryThresholdPercent);
void stopMacSleepPrevention();
void forceWindowFullScreen(void *nsViewHandle);
#endif
