package com.example.my_first_app

import android.app.AlarmManager
import android.content.ContentUris
import android.content.Context
import android.media.MediaMetadataRetriever
import android.provider.MediaStore

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
