package com.github.fluttercommunity.flutterdownloader

import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Test

class DownloadConfigTest {
    @Test
    fun `Simple JSON handling verification`() {
        val data = DownloadMetadata(
            url = "http://www.example.com",
            filename = null,
            etag = "foobar",
            target = DownloadTarget.internal,
            size = null,
            headers = mapOf("foo" to "bar"),
        )
        val expectedJson = """{"url":"http://www.example.com","filename":null,"etag":"foobar","target":"internal","size":null,"headers":{"foo":"bar"}}"""
        val json = Json.encodeToString(data)
        assertEquals(expectedJson, json)
        val obj = Json.decodeFromString<DownloadMetadata>(expectedJson)
        assertEquals(data, obj)
    }
}