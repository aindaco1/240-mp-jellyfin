#include "display/DisplaySelection.h"

DisplaySelection resolveDisplaySelection(int screenCount,
                                         int primaryIndex,
                                         int controllerSetting,
                                         int mediaSetting)
{
    if (screenCount <= 0)
        return {};

    const int safePrimary = primaryIndex >= 0 && primaryIndex < screenCount
        ? primaryIndex : 0;
    const int controller = controllerSetting >= 0 && controllerSetting < screenCount
        ? controllerSetting : safePrimary;

    int media = controller;
    if (mediaSetting >= 0 && mediaSetting < screenCount) {
        media = mediaSetting;
    } else if (mediaSetting != -2 && screenCount > 1) {
        for (int index = 0; index < screenCount; ++index) {
            if (index != controller) {
                media = index;
                break;
            }
        }
    }

    return {controller, media};
}
