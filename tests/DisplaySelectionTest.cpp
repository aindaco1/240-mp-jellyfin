#include "display/DisplaySelection.h"

#include <QtTest>

class DisplaySelectionTest final : public QObject {
    Q_OBJECT

private slots:
    void automaticPreservesSplitScreenBehavior();
    void explicitSelectionsAreIndependent();
    void mediaCanFollowController();
    void invalidSelectionsFallBackSafely();
    void singleDisplayUsesOneScreen();
};

void DisplaySelectionTest::automaticPreservesSplitScreenBehavior()
{
    const DisplaySelection selection = resolveDisplaySelection(3, 1, -1, -1);
    QCOMPARE(selection.controllerIndex, 1);
    QCOMPARE(selection.mediaIndex, 0);
    QVERIFY(selection.hasSeparateMediaScreen());
}

void DisplaySelectionTest::explicitSelectionsAreIndependent()
{
    const DisplaySelection selection = resolveDisplaySelection(3, 0, 2, 1);
    QCOMPARE(selection.controllerIndex, 2);
    QCOMPARE(selection.mediaIndex, 1);
    QVERIFY(selection.hasSeparateMediaScreen());
}

void DisplaySelectionTest::mediaCanFollowController()
{
    const DisplaySelection selection = resolveDisplaySelection(2, 0, 1, -2);
    QCOMPARE(selection.controllerIndex, 1);
    QCOMPARE(selection.mediaIndex, 1);
    QVERIFY(!selection.hasSeparateMediaScreen());
}

void DisplaySelectionTest::invalidSelectionsFallBackSafely()
{
    const DisplaySelection selection = resolveDisplaySelection(2, 9, 7, 8);
    QCOMPARE(selection.controllerIndex, 0);
    QCOMPARE(selection.mediaIndex, 1);
}

void DisplaySelectionTest::singleDisplayUsesOneScreen()
{
    const DisplaySelection selection = resolveDisplaySelection(1, 0, -1, -1);
    QCOMPARE(selection.controllerIndex, 0);
    QCOMPARE(selection.mediaIndex, 0);
    QVERIFY(!selection.hasSeparateMediaScreen());
}

QTEST_APPLESS_MAIN(DisplaySelectionTest)
#include "DisplaySelectionTest.moc"
