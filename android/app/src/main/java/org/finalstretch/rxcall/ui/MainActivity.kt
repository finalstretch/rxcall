package org.finalstretch.rxcall.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import org.finalstretch.rxcall.core.RecallGlossary

/// Placeholder. The real screens come once Core is ported; this exists so the
/// app builds and runs, and so the glossary can be seen working on a device.
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val glossary = RecallGlossary.fromJson(
            assets.open("glossary.json").bufferedReader().use { it.readText() }
        )
        setContent {
            MaterialTheme {
                Surface {
                    Column(Modifier.padding(24.dp)) {
                        Text("Rxcall", style = MaterialTheme.typography.headlineMedium)
                        Text(
                            glossary.explanation("CGMP Deviations")
                                ?: "no explanation",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(top = 12.dp)
                        )
                    }
                }
            }
        }
    }
}
