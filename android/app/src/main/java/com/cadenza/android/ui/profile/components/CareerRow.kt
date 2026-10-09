package com.cadenza.android.ui.profile.components

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.outlined.Link
import androidx.compose.material.icons.outlined.OpenInNew
import androidx.compose.material.icons.outlined.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Career
import com.cadenza.android.core.util.AppLocale
import com.cadenza.android.ui.common.ExpandableText

@Composable
fun CareerRow(
    career: Career,
    showsDisclosure: Boolean = false,
    onSelect: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(if (onSelect != null) Modifier.clickable { onSelect() } else Modifier)
            .padding(vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    career.organization,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    career.role,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    careerYearRange(career),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.outline,
                )
            }
            if (showsDisclosure) {
                Icon(
                    Icons.AutoMirrored.Filled.KeyboardArrowRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outline,
                    modifier = Modifier.size(20.dp).padding(top = 4.dp),
                )
            }
        }
        if (!career.description.isNullOrEmpty()) {
            ExpandableText(
                text = career.description.orEmpty(),
                collapsedLineLimit = 3,
                style = MaterialTheme.typography.bodySmall,
            )
        }
        if (!career.contribution.isNullOrEmpty()) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "◆",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        AppLocale.localized("기여", "Contribution", "Beitrag"),
                        style = MaterialTheme.typography.labelSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    ExpandableText(
                        text = career.contribution.orEmpty(),
                        collapsedLineLimit = 3,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
            }
        }
        buildCareerAttachments(career).forEach { (title, icon, url) ->
            CareerAttachmentRow(title = title, iconType = icon, urlString = url, interactive = true)
        }
    }
}

private fun careerYearRange(career: Career): String {
    val start = career.startYear?.toString() ?: "?"
    val end = if (career.isCurrent)
        AppLocale.localized("현재", "Present", "Aktuell")
    else
        career.endYear?.toString() ?: "?"
    return "$start – $end"
}

private fun buildCareerAttachments(career: Career): List<Triple<String, String, String>> = buildList {
    career.linkUrl?.trim()?.takeIf { it.isNotEmpty() }?.let {
        add(Triple(AppLocale.localized("관련 링크", "Related link", "Relevanter Link"), "link", it))
    }
    career.mediaUrl?.trim()?.takeIf { it.isNotEmpty() }?.let {
        add(Triple(AppLocale.localized("영상", "Video", "Video"), "play", it))
    }
}

@Composable
fun CareerAttachmentRow(
    title: String,
    iconType: String,
    urlString: String,
    interactive: Boolean,
) {
    val context = LocalContext.current
    val hostText = runCatching {
        Uri.parse(urlString).host?.replace("www.", "") ?: urlString
    }.getOrDefault(urlString)

    Surface(
        onClick = {
            if (interactive) {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(urlString)))
            }
        },
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                if (iconType == "link") Icons.Outlined.Link else Icons.Outlined.PlayArrow,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(18.dp),
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    hostText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                )
            }
            if (interactive) {
                Icon(
                    Icons.Outlined.OpenInNew,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outline,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}
