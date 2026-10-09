package com.cadenza.android.ui.feed.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bookmark
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.Edit
import androidx.compose.material.icons.outlined.VisibilityOff
import androidx.compose.material.icons.outlined.PersonRemove
import androidx.compose.material.icons.outlined.Report
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostMeatballSheet(
    isSaved: Boolean,
    isOwnPost: Boolean,
    onDismiss: () -> Unit,
    onSave: () -> Unit,
    onUnfollow: () -> Unit,
    onHide: () -> Unit,
    onReport: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    ) {
        Column(modifier = Modifier.padding(bottom = 16.dp)) {
            MeatballRow(
                icon = if (isSaved) Icons.Outlined.Bookmark else Icons.Outlined.BookmarkBorder,
                label = if (isSaved) "저장 취소" else "저장",
                onClick = { onSave(); onDismiss() },
            )
            HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
            if (isOwnPost) {
                MeatballRow(
                    icon = Icons.Outlined.Edit,
                    label = "수정",
                    onClick = { onEdit(); onDismiss() },
                )
                HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                MeatballRow(
                    icon = Icons.Outlined.Delete,
                    label = "삭제",
                    tint = Color.Red,
                    onClick = { onDelete(); onDismiss() },
                )
            } else {
                MeatballRow(
                    icon = Icons.Outlined.PersonRemove,
                    label = "연결 끊기",
                    onClick = { onUnfollow(); onDismiss() },
                )
                HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                MeatballRow(
                    icon = Icons.Outlined.VisibilityOff,
                    label = "관심없음",
                    onClick = { onHide(); onDismiss() },
                )
                HorizontalDivider(modifier = Modifier.padding(start = 56.dp))
                MeatballRow(
                    icon = Icons.Outlined.Report,
                    label = "신고",
                    tint = Color.Red,
                    onClick = { onReport(); onDismiss() },
                )
            }
        }
    }
}

@Composable
private fun MeatballRow(
    icon: ImageVector,
    label: String,
    tint: Color? = null,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = tint ?: LocalContentColor.current,
        )
        Text(
            text = label,
            style = MaterialTheme.typography.bodyLarge,
            color = tint ?: Color.Unspecified,
            modifier = Modifier.padding(start = 14.dp),
        )
        Spacer(Modifier.weight(1f))
    }
}
