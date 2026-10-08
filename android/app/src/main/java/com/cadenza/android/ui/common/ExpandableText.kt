package com.cadenza.android.ui.common

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.layout.Column
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import com.cadenza.android.core.util.AppLocale

@Composable
fun ExpandableText(
    text: String,
    collapsedLineLimit: Int = 3,
    style: TextStyle = LocalTextStyle.current,
    modifier: Modifier = Modifier,
) {
    var isExpanded by remember(text) { mutableStateOf(false) }
    var hasOverflow by remember(text) { mutableStateOf(false) }
    var layoutDone by remember(text) { mutableStateOf(false) }

    Column(modifier = modifier) {
        Text(
            text = text,
            style = style,
            maxLines = if (isExpanded) Int.MAX_VALUE else collapsedLineLimit,
            onTextLayout = { result: TextLayoutResult ->
                if (!isExpanded && !layoutDone) {
                    hasOverflow = result.hasVisualOverflow
                    layoutDone = true
                }
            },
            modifier = Modifier.animateContentSize(),
        )
        if (hasOverflow || isExpanded) {
            TextButton(
                onClick = { isExpanded = !isExpanded },
                modifier = Modifier.align(Alignment.Start),
            ) {
                Text(
                    text = if (isExpanded)
                        AppLocale.localized("접기", "Show less", "Weniger")
                    else
                        AppLocale.localized("더 보기", "More", "Mehr"),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}
