package com.example.untitled2.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
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
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

@Composable
fun AudioBookIllustration(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .size(300.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize().aspectRatio(1f)) {
            val canvasWidth = size.width
            val canvasHeight = size.height
            val centerX = canvasWidth / 2
            val centerY = canvasHeight / 2

            // Colors based on the screenshot
            val navyColor = Color(0xFF344966)
            val tealColor = Color(0xFF2D9CDB)
            val yellowColor = Color(0xFFF2C94C)
            val lightBlueColor = Color(0xFF56CCF2)
            val whiteColor = Color(0xFFFFFFFF)
            val lightGrayColor = Color(0xFFE0E0E0)

            // 1. Draw Audio Waves
            val waveCenterY = centerY - canvasHeight * 0.18f
            val waveHeights = listOf(0.05f, 0.08f, 0.12f, 0.22f, 0.15f, 0.09f, 0.06f)
            val waveColors = listOf(lightBlueColor, yellowColor, lightBlueColor, yellowColor, lightBlueColor, yellowColor, lightBlueColor)
            val waveSpacing = canvasWidth * 0.045f
            val startWaveX = centerX - (waveHeights.size - 1) * waveSpacing / 2

            waveHeights.forEachIndexed { index, hFactor ->
                val x = startWaveX + index * waveSpacing
                val height = canvasHeight * hFactor
                drawLine(
                    color = waveColors[index],
                    start = Offset(x, waveCenterY - height / 2),
                    end = Offset(x, waveCenterY + height / 2),
                    strokeWidth = 3.dp.toPx(),
                    cap = StrokeCap.Round
                )
            }

            // 2. Draw Headphones Arch
            val archRadius = canvasWidth * 0.38f
            val archCenterY = centerY + canvasHeight * 0.08f
            drawArc(
                color = navyColor,
                startAngle = 180f,
                sweepAngle = 180f,
                useCenter = false,
                topLeft = Offset(centerX - archRadius, archCenterY - archRadius),
                size = Size(archRadius * 2, archRadius * 2),
                style = Stroke(width = 22.dp.toPx(), cap = StrokeCap.Butt)
            )

            // 3. Draw Book Background (Teal)
            val bookWidth = canvasWidth * 0.48f
            val bookHeight = canvasHeight * 0.38f
            val bookTop = centerY - canvasHeight * 0.04f
            drawRoundRect(
                color = tealColor,
                topLeft = Offset(centerX - bookWidth / 2, bookTop),
                size = Size(bookWidth, bookHeight),
                cornerRadius = CornerRadius(4.dp.toPx())
            )

            // 4. Draw Book Pages
            val pagePadding = 6.dp.toPx()
            val pageWidth = (bookWidth - pagePadding * 3) / 2
            val pageHeight = bookHeight - pagePadding * 2
            
            // Left Page
            val leftPagePath = Path().apply {
                moveTo(centerX - pagePadding / 2, bookTop + pagePadding)
                lineTo(centerX - pagePadding / 2 - pageWidth, bookTop + pagePadding)
                lineTo(centerX - pagePadding / 2 - pageWidth, bookTop + pagePadding + pageHeight)
                lineTo(centerX - pagePadding / 2, bookTop + pagePadding + pageHeight)
                close()
            }
            drawPath(leftPagePath, color = whiteColor)

            // Right Page
            val rightPagePath = Path().apply {
                moveTo(centerX + pagePadding / 2, bookTop + pagePadding)
                lineTo(centerX + pagePadding / 2 + pageWidth, bookTop + pagePadding)
                lineTo(centerX + pagePadding / 2 + pageWidth, bookTop + pagePadding + pageHeight)
                lineTo(centerX + pagePadding / 2, bookTop + pagePadding + pageHeight)
                close()
            }
            drawPath(rightPagePath, color = whiteColor)

            // Page Lines
            val lineSpacing = pageHeight / 9
            for (i in 2..7) {
                val y = bookTop + pagePadding + i * lineSpacing
                // Left lines
                drawLine(
                    color = lightGrayColor,
                    start = Offset(centerX - pagePadding / 2 - pageWidth * 0.85f, y),
                    end = Offset(centerX - pagePadding / 2 - pageWidth * 0.15f, y),
                    strokeWidth = 1.dp.toPx()
                )
                // Right lines
                drawLine(
                    color = lightGrayColor,
                    start = Offset(centerX + pagePadding / 2 + pageWidth * 0.15f, y),
                    end = Offset(centerX + pagePadding / 2 + pageWidth * 0.85f, y),
                    strokeWidth = 1.dp.toPx()
                )
            }

            // 5. Draw Earcups
            val earcupWidth = 26.dp.toPx()
            val earcupHeight = 75.dp.toPx()
            val earcupY = archCenterY - earcupHeight / 2
            
            // Left Earcup and Cushion
            drawRoundRect(
                color = navyColor,
                topLeft = Offset(centerX - archRadius - earcupWidth / 2, earcupY),
                size = Size(earcupWidth, earcupHeight),
                cornerRadius = CornerRadius(12.dp.toPx())
            )
            val cushionWidth = 18.dp.toPx()
            drawArc(
                color = lightBlueColor,
                startAngle = 90f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(centerX - archRadius - earcupWidth / 2 - cushionWidth, earcupY + 10.dp.toPx()),
                size = Size(cushionWidth * 2, earcupHeight - 20.dp.toPx())
            )

            // Right Earcup and Cushion
            drawRoundRect(
                color = navyColor,
                topLeft = Offset(centerX + archRadius - earcupWidth / 2, earcupY),
                size = Size(earcupWidth, earcupHeight),
                cornerRadius = CornerRadius(12.dp.toPx())
            )
            drawArc(
                color = lightBlueColor,
                startAngle = 270f,
                sweepAngle = 180f,
                useCenter = true,
                topLeft = Offset(centerX + archRadius - earcupWidth / 2, earcupY + 10.dp.toPx()),
                size = Size(cushionWidth * 2, earcupHeight - 20.dp.toPx())
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
fun AudioBookIllustrationPreview() {
    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background
    ) {
        Box(contentAlignment = Alignment.Center) {
            AudioBookIllustration()
        }
    }
}
