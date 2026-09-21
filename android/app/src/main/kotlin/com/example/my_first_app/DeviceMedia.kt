package com.example.my_first_app

import android.app.AlarmManager
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Two small reads of the device: the next alarm the system has scheduled, and
 * the music sitting in the media store.
 *
 * MediaStore is queried directly rather than through a plugin — it is one
 * cursor, and it avoids pulling in a second audio dependency alongside the
 * player.
 */
class DeviceMedia(private val context: Context) {

    /**
     * When the system's next alarm goes off, in epoch millis, or null.
     *
     * This is the same alarm the lock screen shows, not one of ours, which is
     * what makes the clock read like the platform's own.
     */
    fun nextAlarm(): Map<String, Any?> {
        return try {
            val manager =
                context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            mapOf("triggerTime" to manager?.nextAlarmClock?.triggerTime)
        } catch (e: Exception) {
            mapOf("triggerTime" to null, "error" to e.message)
        }
    }

    /** Music on the device, newest first. */
    fun audioTracks(limit: Int): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()

        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
        )

        try {
            context.contentResolver.query(
                collection,
                projection,
                "${MediaStore.Audio.Media.IS_MUSIC} != 0",
                null,
                "${MediaStore.Audio.Media.DATE_ADDED} DESC",
            )?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val titleCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artistCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val albumCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val durationCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dataCol =
                    cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)

                while (cursor.moveToNext() && out.size < limit) {
                    val id = cursor.getLong(idCol)
                    out.add(
                        mapOf(
                            "id" to id.toString(),
                            "title" to (cursor.getString(titleCol) ?: "Unknown"),
                            "artist" to (cursor.getString(artistCol) ?: ""),
                            "album" to (cursor.getString(albumCol) ?: ""),
                            "durationMs" to cursor.getLong(durationCol),
                            // A file path where there is one, and a content uri
                            // either way: scoped storage means DATA can be
                            // empty, and the player needs something to open.
                            "path" to (cursor.getString(dataCol) ?: ""),
                            "uri" to ContentUris.withAppendedId(
                                collection,
                                id,
                            ).toString(),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            // A permission refusal lands here; an empty list is the answer.
        }

        return out
    }


    /**
     * Writes a downloaded track into the public Music library.
     *
     * Going through MediaStore rather than the app's own sandbox is the whole
     * point: the file lands in Music/ExitZero, survives an uninstall, and
     * every player on the phone — including this app's own Player widget —
     * finds it without a rescan.
     */
    fun saveAudio(
        fileName: String,
        bytes: ByteArray,
        title: String,
        artist: String,
        album: String,
    ): Map<String, Any?> {
        // MediaStore takes a display name, not a path: anything that reads as
        // a separator has to go, or the insert is rejected.
        val safe = fileName
            .replace(Regex("""[\\/:*?"<>|]"""), "_")
            .trim()
            .ifEmpty { "track.mp3" }

        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val resolver = context.contentResolver
        val legacy = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, safe)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mpeg")
            put(MediaStore.Audio.Media.IS_MUSIC, 1)
            if (title.isNotEmpty()) put(MediaStore.Audio.Media.TITLE, title)
            if (artist.isNotEmpty()) put(MediaStore.Audio.Media.ARTIST, artist)
            if (album.isNotEmpty()) put(MediaStore.Audio.Media.ALBUM, album)
        }

        var target: File? = null

        return try {
            if (legacy) {
                // Before scoped storage the row needs a real path, and the
                // directory has to exist before the write.
                val dir = File(
                    Environment.getExternalStoragePublicDirectory(
                        Environment.DIRECTORY_MUSIC,
                    ),
                    "ExitZero",
                )
                if (!dir.exists()) dir.mkdirs()
                target = File(dir, safe)
                values.put(MediaStore.Audio.Media.DATA, target.absolutePath)
            } else {
                values.put(MediaStore.Audio.Media.RELATIVE_PATH, "Music/ExitZero")
                // Hide the row from other apps until the bytes are all there,
                // so nothing indexes a half-written file.
                values.put(MediaStore.Audio.Media.IS_PENDING, 1)
            }

            val uri = resolver.insert(collection, values)
                ?: return mapOf(
                    "ok" to false,
                    "error" to "The media store refused to create the file.",
                )

            resolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: run {
                    resolver.delete(uri, null, null)
                    return mapOf(
                        "ok" to false,
                        "error" to "Could not open the file for writing.",
                    )
                }

            if (!legacy) {
                resolver.update(
                    uri,
                    ContentValues().apply {
                        put(MediaStore.Audio.Media.IS_PENDING, 0)
                    },
                    null,
                    null,
                )
            }

            mapOf(
                "ok" to true,
                "uri" to uri.toString(),
                "name" to safe,
                "path" to (target?.absolutePath ?: "Music/ExitZero/$safe"),
            )
        } catch (e: Exception) {
            mapOf("ok" to false, "error" to (e.message ?: "Save failed."))
        }
    }

    /** Artwork embedded in a track, or null when it carries none. */
    fun audioArt(path: String, uri: String): ByteArray? {
        val retriever = MediaMetadataRetriever()
        return try {
            if (path.isNotEmpty()) {
                retriever.setDataSource(path)
            } else {
                retriever.setDataSource(
                    context,
                    android.net.Uri.parse(uri),
                )
            }
            retriever.embeddedPicture
        } catch (e: Exception) {
            null
        } finally {
            try { retriever.release() } catch (_: Exception) {}
        }
    }
}
