package com.cadenza.android.ui.profile.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.data.model.Affiliation
import com.cadenza.android.core.data.onboarding.OnboardingData
import com.cadenza.android.core.util.AppLocale

@Composable
fun AffiliationRow(
    affiliation: Affiliation,
    showsDisclosure: Boolean = false,
    onSelect: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .then(if (onSelect != null) Modifier.clickable { onSelect() } else Modifier)
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.Top,
    ) {
        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                affiliation.institutionName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
            val courseLabel = affiliation.courseType?.let { ct ->
                OnboardingData.courseOptions.firstOrNull { it.id == ct }?.label
            }
            if (!courseLabel.isNullOrEmpty()) {
                Text(
                    courseLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            val yearRange = affiliationYearRange(affiliation)
            if (yearRange.isNotEmpty()) {
                Text(
                    yearRange,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.outline,
                )
            }
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
}

private fun affiliationYearRange(affiliation: Affiliation): String {
    val parts = mutableListOf<String>()
    affiliation.enrollmentYear?.let { parts.add(it.toString()) }
    if (affiliation.isCurrent) {
        val grad = affiliation.graduationYear
        if (grad != null) {
            parts.add("$grad (${AppLocale.localized("예정", "Expected", "Voraussichtlich")})")
        } else {
            parts.add(AppLocale.localized("재학중", "Present", "Aktuell"))
        }
    } else {
        (affiliation.graduationYear ?: affiliation.enrollmentYear?.plus(4))?.let { parts.add(it.toString()) }
    }
    return parts.joinToString(" – ")
}
