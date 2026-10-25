package com.nevutech.trama

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

/**
 * Translation completeness (plain JVM, reads the XML sources): every string and plural in the
 * default Spanish resources exists in English and Portuguese (Brazil) with the same format
 * arguments, and translations carry no stale keys.
 */
class StringResourcesTest {
    private val res = listOf(File("src/main/res"), File("app/src/main/res")).first { it.isDirectory }
    private val translations = listOf("values-en", "values-pt-rBR")
    private val argPattern = Regex("""%(\d+\$)?[-#+ 0,(]*\d*(\.\d+)?([sdfxXoceEgGb%])""")

    /** key → set of format arguments ("1$s", "2$d"), for strings and plurals of one values dir. */
    private fun entries(dir: String): Map<String, Set<String>> {
        val out = LinkedHashMap<String, Set<String>>()
        val files = File(res, dir).listFiles { f -> f.name.startsWith("strings") && f.extension == "xml" }.orEmpty()
        for (file in files) {
            val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
            val root = doc.documentElement
            val nodes = root.childNodes
            for (i in 0 until nodes.length) {
                val el = nodes.item(i) as? Element ?: continue
                if (el.getAttribute("translatable") == "false") continue
                val name = el.getAttribute("name")
                val formatted = el.getAttribute("formatted") != "false"
                val texts = when (el.tagName) {
                    "string" -> listOf(el.textContent)
                    "plurals" -> {
                        val items = el.getElementsByTagName("item")
                        (0 until items.length).map { items.item(it).textContent }
                    }
                    else -> continue
                }
                val key = "${el.tagName}/$name"
                assertTrue("$dir/${file.name}: duplicate $key", key !in out)
                out[key] = if (formatted) texts.flatMap { args(it) }.toSet() else emptySet()
            }
        }
        return out
    }

    private fun args(text: String): List<String> =
        argPattern.findAll(text).map { it.value }.filter { it != "%%" }.map { m ->
            val position = Regex("""%(\d+)\$""").find(m)?.groupValues?.get(1) ?: "?"
            "$position\$${m.last()}"
        }.toList()

    @Test fun defaultStringsExist() {
        assertTrue("no strings found in $res", entries("values").size > 100)
    }

    @Test fun everyKeyIsTranslatedWithTheSameArguments() {
        val base = entries("values")
        for (dir in translations) {
            val other = entries(dir)
            val missing = base.keys - other.keys
            assertTrue("$dir is missing ${missing.size} keys: ${missing.take(30)}", missing.isEmpty())
            val extra = other.keys - base.keys
            assertTrue("$dir has keys not in values/: $extra", extra.isEmpty())
            val mismatched = base.filter { (key, args) -> other[key] != args }.map { (key, args) -> "$key es=$args $dir=${other[key]}" }
            assertTrue("format arguments differ:\n" + mismatched.joinToString("\n"), mismatched.isEmpty())
        }
    }

    @Test fun formatArgumentsArePositional() {
        val loose = entries("values").filter { (_, args) -> args.any { it.startsWith("?") } && args.size > 1 }
        assertEquals("use %1\$s style arguments when a string has several: ${loose.keys}", emptyMap<String, Set<String>>(), loose)
    }

    @Test fun pluralsHaveOneAndOther() {
        for (dir in listOf("values") + translations) {
            File(res, dir).listFiles { f -> f.name.startsWith("strings") }.orEmpty().forEach { file ->
                val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(file)
                val plurals = doc.getElementsByTagName("plurals")
                for (i in 0 until plurals.length) {
                    val el = plurals.item(i) as Element
                    val items = el.getElementsByTagName("item")
                    val quantities = (0 until items.length).map { (items.item(it) as Element).getAttribute("quantity") }.toSet()
                    assertTrue("$dir ${el.getAttribute("name")}: $quantities", "one" in quantities && "other" in quantities)
                }
            }
        }
    }
}
