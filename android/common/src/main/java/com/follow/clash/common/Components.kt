package com.follow.clash.common

import android.content.ComponentName

object Components {
    // Kotlin-пакет классов и префикс MethodChannel-ов, а не applicationId
    // (ru.victorycloud.fix берётся из GlobalState.packageName).
    const val PACKAGE_NAME = "com.follow.clash"

    val mainActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.MainActivity")

    val quickActionActivity =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.QuickActionActivity")

    val serviceBroadcastReceiver =
        ComponentName(GlobalState.packageName, "${PACKAGE_NAME}.ServiceBroadcastReceiver")
}
