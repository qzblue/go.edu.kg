package com.follow.clash.service.models

import android.os.Parcelable
import kotlinx.parcelize.Parcelize

@Parcelize
data class NotificationParams(
    val title: String = "美国华人华侨贸易中心",
    val stopText: String = "STOP",
    val onlyStatisticsProxy: Boolean = false,
) : Parcelable