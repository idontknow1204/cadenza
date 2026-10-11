package com.cadenza.android.core.session

import com.cadenza.android.core.data.model.ConnectedProfile
import com.cadenza.android.core.data.model.ConnectionRecord
import com.cadenza.android.core.data.model.ConnectionStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ConnectionSnapshotTest {
    private val me = "me"
    private val other = "other"
    private val person = ConnectedProfile(id = other, realName = "Test Musician")

    private fun row(status: String, incoming: Boolean) = ConnectionRecord(
        followerId = if (incoming) other else me,
        followeeId = if (incoming) me else other,
        status = status,
        follower = if (incoming) person else null,
    )

    @Test
    fun outgoingPendingRequestSurvivesAuthoritativeRefresh() {
        val snapshot = buildConnectionSnapshot(me, listOf(row("pending", incoming = false)))

        assertEquals(ConnectionStatus.RequestSent, snapshot.statuses[other])
        assertTrue(snapshot.pending.isEmpty())
    }

    @Test
    fun acceptedRelationshipWinsOverPendingInEitherRowOrder() {
        val rows = listOf(row("pending", incoming = true), row("accepted", incoming = false))

        listOf(rows, rows.reversed()).forEach {
            val snapshot = buildConnectionSnapshot(me, it)
            assertEquals(ConnectionStatus.Connected, snapshot.statuses[other])
            assertTrue(snapshot.pending.isEmpty())
        }
    }

    @Test
    fun incomingPendingRequestIncludesRequesterProfile() {
        val snapshot = buildConnectionSnapshot(me, listOf(row("pending", incoming = true)))

        assertEquals(ConnectionStatus.RequestReceived, snapshot.statuses[other])
        assertEquals(listOf(person), snapshot.pending)
    }
}
