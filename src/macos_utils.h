#pragma once

#if defined(Q_OS_MAC) || defined(Q_OS_MACOS)
void hideMacOSMenuBar();
void configureMacSleepPrevention(bool enabled, int lowBatteryThresholdPercent);
void stopMacSleepPrevention();
void forceWindowFullScreenOnScreen(void *nsViewHandle, int screenIndex);
#endif
