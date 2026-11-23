package org.finalstretch.rxcall.core

import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import java.util.Locale

/**
 * Plain-language explanations for the phrases the FDA uses in
 * `reason_for_recall`. Matched by keyword; first hit wins, so more specific
 * entries come first. Nothing here is advice — it says what the words mean.
 *
 * Ported from `ios/Rxcall/Rxcall/Core/RecallGlossary.swift`, but the table
 * itself is read from `shared/data/glossary.json` rather than transcribed, so
 * there is no wording to keep in step by hand. Pinned by
 * `shared/fixtures/glossary/`.
 */
class RecallGlossary private constructor(
    private val entries: List<Entry>,
    private val guidance: Map<String, String>,
) {
    data class Entry(
        val keywords: List<String>,
        val explanation: String,
    )

    /** Null when nothing matches: the UI then shows the FDA's own wording. */
    fun explanation(reason: String): String? {
        val r = reason.lowercase(Locale.US)
        return entries.firstOrNull { entry ->
            entry.keywords.any { r.contains(it) }
        }?.explanation
    }

    /** What to do, by how serious the FDA says it is. */
    fun whatToDo(classification: String): String =
        guidance[classification] ?: guidance.getValue(UNCLASSIFIED)

    companion object {
        /**
         * The key the exported table uses for the fallback branch, matching
         * the `default:` arm of the Swift switch.
         */
        private const val UNCLASSIFIED = "Unclassified"

        fun fromJson(json: String): RecallGlossary {
            val table = Gson().fromJson(json, Table::class.java)
            require(table.entries.isNotEmpty()) { "glossary.json has no entries" }
            require(table.whatToDo.containsKey(UNCLASSIFIED)) {
                "glossary.json has no \"$UNCLASSIFIED\" guidance to fall back on"
            }
            return RecallGlossary(table.entries, table.whatToDo)
        }
    }

    private class Table(
        val entries: List<Entry> = emptyList(),
        @SerializedName("whatToDo") val whatToDo: Map<String, String> = emptyMap(),
    )
}
