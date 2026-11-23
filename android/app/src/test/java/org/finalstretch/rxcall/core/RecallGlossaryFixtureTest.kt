package org.finalstretch.rxcall.core

import com.google.gson.Gson
import com.google.gson.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/**
 * Asserts the Kotlin glossary against expectations recorded from the running
 * iOS app. These values were not written by hand: `tools/record_fixtures.sh`
 * ran the real Swift `RecallGlossary` over the same inputs and wrote down
 * what it produced. A failure here means the two apps would tell the same
 * person two different things about the same recall.
 */
class RecallGlossaryFixtureTest {

    private val sharedDir = File("../shared")

    private val glossary = RecallGlossary.fromJson(
        File(sharedDir, "data/glossary.json").readText()
    )

    @Test
    fun `matches every explanation iOS produced`() {
        val fixture = load("fixtures/glossary/reasons-and-guidance.json")
        val expected = fixture.getAsJsonObject("expected").getAsJsonObject("explanations")

        assertTrue("fixture has no expectations — was it recorded?", expected.size() > 0)

        for ((reason, value) in expected.entrySet()) {
            val want = if (value.isJsonNull) null else value.asString
            assertEquals("explanation for \"$reason\"", want, glossary.explanation(reason))
        }
    }

    @Test
    fun `matches every guidance branch iOS produced`() {
        val fixture = load("fixtures/glossary/reasons-and-guidance.json")
        val expected = fixture.getAsJsonObject("expected").getAsJsonObject("whatToDo")

        assertTrue("fixture has no guidance — was it recorded?", expected.size() > 0)

        for ((classification, value) in expected.entrySet()) {
            assertEquals(
                "guidance for \"$classification\"",
                value.asString,
                glossary.whatToDo(classification),
            )
        }
    }

    @Test
    fun `an unknown classification falls back rather than throwing`() {
        // openFDA leaves classification blank on recalls it hasn't graded yet.
        assertEquals(glossary.whatToDo("Unclassified"), glossary.whatToDo(""))
    }

    private fun load(path: String): JsonObject =
        Gson().fromJson(File(sharedDir, path).readText(), JsonObject::class.java)
}
