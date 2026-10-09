package com.cadenza.android.ui.profile.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.cadenza.android.ui.theme.CadenzaAccent

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
    Surface(
        modifier = modifier
            .fillMaxWidth()
            // iOS: .padding(.horizontal, 16) on card → horizontal margin 16dp
            .padding(horizontal = 16.dp)
            // iOS: .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            .shadow(
                elevation = 2.dp,
                shape = RoundedCornerShape(16.dp),
                clip = false,
                ambientColor = Color.Black.copy(alpha = 0.04f),
                spotColor = Color.Black.copy(alpha = 0.04f),
            ),
        // iOS: RoundedRectangle(cornerRadius: 16)
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surface,
    ) {
        // iOS: VStack(alignment: .leading, spacing: 12) + .padding(16)
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val hasHeader = title != null || onAdd != null || onEdit != null || viewAllAction != null
            if (hasHeader) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (title != null) {
                        // iOS: .font(.title3.weight(.semibold)) = 20sp semibold
                        Text(
                            text = title,
                            style = MaterialTheme.typography.titleLarge,
                            modifier = Modifier.weight(1f),
                        )
                    } else {
                        Spacer(Modifier.weight(1f))
                    }
                    if (viewAllAction != null) {
                        TextButton(
                            onClick = viewAllAction,
                            contentPadding = PaddingValues(horizontal = 4.dp, vertical = 2.dp),
                        ) {
                            // iOS: HStack(spacing:3) { Text.subheadline.medium + chevron.right.caption.semibold }
                            Text(
                                viewAllLabel,
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                                color = CadenzaAccent,
                            )
                            Icon(
                                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                tint = CadenzaAccent,
                                modifier = Modifier.size(14.dp),
                            )
                        }
                    }
                    if (onAdd != null) {
                        Spacer(Modifier.width(4.dp))
                        // iOS: .padding(7) circle button
                        CircleIconButton(onClick = onAdd) {
                            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(16.dp))
                        }
                    }
                    if (onEdit != null) {
                        Spacer(Modifier.width(4.dp))
                        // iOS: .padding(7) circle pencil button
                        CircleIconButton(onClick = onEdit) {
                            Icon(Icons.Outlined.Edit, contentDescription = null, modifier = Modifier.size(14.dp))
                        }
                    }
                }
            }
            Column {
                content()
            }
        }
    }
}

@Composable
private fun CircleIconButton(
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    // iOS: .padding(7) + icon (~14-16dp) → total ~28-30dp, using 30dp to match
    Surface(
        onClick = onClick,
        shape = CircleShape,
        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.1f),
        modifier = Modifier.size(30.dp),
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(30.dp)) {
            content()
        }
    }
}
