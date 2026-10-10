package com.cadenza.android.ui.common

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.LocalTextStyle
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import com.cadenza.android.core.util.AppLocale

@Composable
fun ExpandableText(
    text: String,
    collapsedLineLimit: Int = 3,
    style: TextStyle = LocalTextStyle.current,
    modifier: Modifier = Modifier,
    toggleTextStyle: TextStyle = TextStyle.Default,
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
            // TextButton은 최소 너비 58dp에 글자가 가운데 정렬돼 본문 왼쪽 끝과 어긋나므로 클릭 가능한 Text를 쓴다
            Text(
                text = if (isExpanded)
                    AppLocale.localized("접기", "Show less", "Weniger")
                else
                    AppLocale.localized("더 보기", "More", "Mehr"),
                style = MaterialTheme.typography.labelSmall.merge(toggleTextStyle),
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier
                    .align(Alignment.Start)
                    .clickable(role = Role.Button) { isExpanded = !isExpanded }
                    .padding(vertical = 8.dp),
            )
        }
    }
}
