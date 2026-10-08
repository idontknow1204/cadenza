package com.cadenza.android.ui.profile.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.FilledTonalIconButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun SectionCard(
    title: String? = null,
    onAdd: (() -> Unit)? = null,
    onEdit: (() -> Unit)? = null,
    viewAllAction: (() -> Unit)? = null,
    viewAllLabel: String = "",
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    ElevatedCard(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp),
        shape = RoundedCornerShape(16.dp),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            val hasHeader = title != null || onAdd != null || onEdit != null || viewAllAction != null
            if (hasHeader) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(bottom = 12.dp),
                ) {
                    if (title != null) {
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleMedium,
                            modifier = Modifier.weight(1f),
                        )
                    } else {
                        Spacer(Modifier.weight(1f))
                    }
                    if (viewAllAction != null) {
                        TextButton(
                            onClick = viewAllAction,
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                        ) {
                            Text(viewAllLabel, style = MaterialTheme.typography.labelMedium)
                        }
                    }
                    if (onAdd != null) {
                        Spacer(Modifier.width(4.dp))
                        FilledTonalIconButton(onClick = onAdd, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Outlined.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                        }
                    }
                    if (onEdit != null) {
                        Spacer(Modifier.width(4.dp))
                        FilledTonalIconButton(onClick = onEdit, modifier = Modifier.size(32.dp)) {
                            Icon(Icons.Outlined.Edit, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                content()
            }
        }
    }
}
