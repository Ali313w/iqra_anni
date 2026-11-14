package com.example.untitled2.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.untitled2.R

@Composable
fun BookAudioIllustration(
    modifier: Modifier = Modifier
) {
    val description = stringResource(id = R.string.audio_book_illustration_desc)
    Box(
        modifier = modifier
            .size(240.dp)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center
    ) {
        Canvas(
            modifier = Modifier
                .fillMaxSize()
                .aspectRatio(1f)
        ) {
            val w = size.width
            val h = size.height
            val centerX = w / 2f
            
            val navy = Color(0xFF344966)
            val teal = Color(0xFF2D9CDB)
            val yellow = Color(0xFFF2C94C)
            val lightBlue = Color(0xFF56CCF2)
            val white = Color(0xFFFFFFFF)
            val grayLine = Color(0xFFE0E0E0)

            val waveY = h * 0.32f
            val waveHeights = listOf(0.04f, 0.08f, 0.15f, 0.22f, 0.15f, 0.08f, 0.04f)
            val waveColors = listOf(lightBlue, yellow, lightBlue, yellow, lightBlue, yellow, lightBlue)
            val waveGap = w * 0.045f
            val waveStart = centerX - (waveHeights.size - 1) * waveGap / 2f

            waveHeights.forEachIndexed { i, factor ->
                val x = waveStart + i * waveGap
                val height = h * factor
                drawLine(
                    color = waveColors[i],
                    start = Offset(x, waveY - height / 2f),
                    end = Offset(x, waveY + height / 2f),
                    strokeWidth = 3.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }

            val archRadius = w * 0.36f
            val archCenterY = h * 0.52f
            drawArc(
                color = navy,
                startAngle = 180f,
                sweepAngle = 180f,
                useCenter = false,
                topLeft = Offset(centerX - archRadius, archCenterY - archRadius),
                size = Size(archRadius * 2, archRadius * 2),
                style = Stroke(width = 14.dp.toPx(), cap = StrokeCap.Butt)
            )

            val connectorWidth = 14.dp.toPx()
            val connectorHeight = 52.dp.toPx()
            val earcupWidth = 24.dp.toPx()
            val earcupHeight = 64.dp.toPx()
            
            drawRoundRect(
                color = navy,
                topLeft = Offset(centerX - archRadius - connectorWidth / 2f, archCenterY - connectorHeight / 2f),
                size = Size(connectorWidth, connectorHeight),
                cornerRadius = CornerRadius(4.dp.toPx())
            )
            drawRoundRect(
                color = teal,
                topLeft = Offset(centerX - archRadius - connectorWidth / 2f - earcupWidth, archCenterY - earcupHeight / 2f),
                size = Size(earcupWidth, earcupHeight),
                cornerRadius = CornerRadius(20.dp.toPx())
            )

            drawRoundRect(
                color = navy,
                topLeft = Offset(centerX + archRadius - connectorWidth / 2f, archCenterY - connectorHeight / 2f),
                size = Size(connectorWidth, connectorHeight),
                cornerRadius = CornerRadius(4.dp.toPx())
            )
            drawRoundRect(
                color = teal,
                topLeft = Offset(centerX + archRadius + connectorWidth / 2f, archCenterY - earcupHeight / 2f),
                size = Size(earcupWidth, earcupHeight),
                cornerRadius = CornerRadius(20.dp.toPx())
            )

            val bookW = w * 0.52f
            val bookH = h * 0.38f
            val bookTop = h * 0.48f
            
            val bookPath = Path().apply {
                val r = 8.dp.toPx()
                moveTo(centerX - bookW / 2f, bookTop + r)
                quadraticBezierTo(centerX - bookW / 2f, bookTop, centerX - bookW / 2f + r, bookTop)
                lineTo(centerX + bookW / 2f - r, bookTop)
                quadraticBezierTo(centerX + bookW / 2f, bookTop, centerX + bookW / 2f, bookTop + r)
                lineTo(centerX + bookW / 2f, bookTop + bookH - r)
                quadraticBezierTo(centerX + bookW / 2f, bookTop + bookH, centerX + bookW / 2f - r, bookTop + bookH)
                lineTo(centerX + r, bookTop + bookH)
                quadraticBezierTo(centerX, bookTop + bookH - r, centerX - r, bookTop + bookH)
                lineTo(centerX - bookW / 2f + r, bookTop + bookH)
                quadraticBezierTo(centerX - bookW / 2f, bookTop + bookH, centerX - bookW / 2f, bookTop + bookH - r)
                close()
            }
            drawPath(bookPath, color = teal)

            val pagePadding = 6.dp.toPx()
            val pageWidth = (bookW - pagePadding * 3) / 2f
            val pageHeight = bookH - pagePadding * 2f
            
            drawRoundRect(
                color = white,
                topLeft = Offset(centerX - pagePadding / 2f - pageWidth, bookTop + pagePadding),
                size = Size(pageWidth, pageHeight),
                cornerRadius = CornerRadius(2.dp.toPx())
            )
            drawRoundRect(
                color = white,
                topLeft = Offset(centerX + pagePadding / 2f, bookTop + pagePadding),
                size = Size(pageWidth, pageHeight),
                cornerRadius = CornerRadius(2.dp.toPx())
            )

            val lines = 6
            val spacing = pageHeight / (lines + 1)
            for (i in 1..lines) {
                val lineY = bookTop + pagePadding + i * spacing
                drawLine(
                    color = grayLine,
                    start = Offset(centerX - pagePadding / 2f - pageWidth * 0.85f, lineY),
                    end = Offset(centerX - pagePadding / 2f - pageWidth * 0.15f, lineY),
                    strokeWidth = 1.dp.toPx()
                )
                drawLine(
                    color = grayLine,
                    start = Offset(centerX + pagePadding / 2f + pageWidth * 0.15f, lineY),
                    end = Offset(centerX + pagePadding / 2f + pageWidth * 0.85f, lineY),
                    strokeWidth = 1.dp.toPx()
                )
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
fun BookAudioIllustrationPreview() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        BookAudioIllustration()
    }
}
