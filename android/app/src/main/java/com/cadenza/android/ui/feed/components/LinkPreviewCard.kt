package com.cadenza.android.ui.feed.components

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import coil3.compose.AsyncImagePainter

@Composable
fun LinkPreviewCard(
    urlString: String,
    title: String?,
    siteName: String?,
    imageUrl: String?,
) {
    val context = LocalContext.current
    val shape = RoundedCornerShape(10.dp)
    val siteLabel = siteName
        ?: runCatching { Uri.parse(urlString).host?.removePrefix("www.") }.getOrNull()
        ?: urlString

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(shape)
            .border(0.5.dp, MaterialTheme.colorScheme.outlineVariant, shape)
            .clickable {
                runCatching {
                    context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(urlString)))
                }
            },
    ) {
        if (!imageUrl.isNullOrBlank()) {
            AsyncImage(
                model = imageUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxWidth().height(200.dp),
                onState = {},
            )
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                .padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            Text(
                text = title ?: urlString,
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 2,
            )
            Text(
                text = siteLabel,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
            )
        }
    }
}
