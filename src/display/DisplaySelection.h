#pragma once

struct DisplaySelection {
    int controllerIndex = 0;
    int mediaIndex = 0;

    bool hasSeparateMediaScreen() const { return controllerIndex != mediaIndex; }
};

// Setting values:
//   -1 = automatic (primary controller; first other display for media)
//   -2 = media only: use the controller display
//  >=0 = explicit QGuiApplication::screens() index
DisplaySelection resolveDisplaySelection(int screenCount,
                                         int primaryIndex,
                                         int controllerSetting,
                                         int mediaSetting);
