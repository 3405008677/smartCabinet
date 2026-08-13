package com.example.smart_cabinet.upgrade

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 验证 STUM VE 与 Android versionName 的跨层一致性规则。 */
class TerminalUpgradeVersionPolicyTest {
    @Test
    fun normalizeExpectedOnlyTrimsOuterWhitespace() {
        assertEquals(
            "V1.2.3_build",
            TerminalUpgradeVersionPolicy.normalizeExpected("  V1.2.3_build  "),
        )
    }

    @Test
    fun exactVersionAndSingleUppercaseVPrefixAreCompatible() {
        assertTrue(TerminalUpgradeVersionPolicy.matchesApkVersionName("1.2.3", "1.2.3"))
        assertTrue(TerminalUpgradeVersionPolicy.matchesApkVersionName("V1.2.3", "1.2.3"))
        assertTrue(TerminalUpgradeVersionPolicy.matchesApkVersionName("1.2.3", "V1.2.3"))
        assertTrue(
            TerminalUpgradeVersionPolicy.matchesApkVersionName(
                "SL_V1.2.3_20260812",
                "1.2.3",
            ),
        )
        assertTrue(
            TerminalUpgradeVersionPolicy.matchesApkVersionName(
                "SL_APP_V1.2.3",
                "1.2.3",
            ),
        )
    }

    @Test
    fun doesNotNormalizeCaseSuffixOrNonNumericVPrefix() {
        assertFalse(TerminalUpgradeVersionPolicy.matchesApkVersionName("v1.2.3", "1.2.3"))
        assertFalse(TerminalUpgradeVersionPolicy.matchesApkVersionName("VV1.2.3", "V1.2.3"))
        assertFalse(TerminalUpgradeVersionPolicy.matchesApkVersionName("VNext", "Next"))
        assertFalse(TerminalUpgradeVersionPolicy.matchesApkVersionName("1.2.3-a", "1.2.3-b"))
        assertFalse(
            TerminalUpgradeVersionPolicy.matchesApkVersionName(
                "SL_V1.2.3_2026081",
                "1.2.3",
            ),
        )
        assertFalse(
            TerminalUpgradeVersionPolicy.matchesApkVersionName(
                "sl_app_v1.2.3",
                "1.2.3",
            ),
        )
    }

    @Test
    fun installedTargetRequiresExactVersionCodeAndCompatibleVersionName() {
        assertTrue(
            TerminalUpgradeVersionPolicy.matchesInstalledTarget(
                expectedVersionName = "V1.2.3",
                expectedVersionCode = 23L,
                actualVersionName = "1.2.3",
                actualVersionCode = 23L,
            ),
        )
        assertFalse(
            TerminalUpgradeVersionPolicy.matchesInstalledTarget(
                expectedVersionName = "1.2.3",
                expectedVersionCode = 23L,
                actualVersionName = "1.2.4",
                actualVersionCode = 24L,
            ),
        )
        assertFalse(
            TerminalUpgradeVersionPolicy.matchesInstalledTarget(
                expectedVersionName = "1.2.3",
                expectedVersionCode = 0L,
                actualVersionName = "1.2.3",
                actualVersionCode = 0L,
            ),
        )
    }
}
