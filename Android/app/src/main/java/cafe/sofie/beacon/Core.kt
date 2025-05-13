package cafe.sofie.beacon

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import cafe.sofie.beacon.crux.Effect
import cafe.sofie.beacon.crux.Event
import cafe.sofie.beacon.crux.Request
import cafe.sofie.beacon.crux.Requests
import cafe.sofie.beacon.crux.ViewModel
import cafe.sofie.beacon.shared.processEvent
import cafe.sofie.beacon.shared.view

class Core : androidx.lifecycle.ViewModel() {
    var view: ViewModel? by mutableStateOf(null)
        private set

    fun update(event: Event) {
        val effects = processEvent(event.bincodeSerialize())

        val requests = Requests.bincodeDeserialize(effects)
        for (request in requests) {
            processEffect(request)
        }
    }

    private fun processEffect(request: Request) {
        when (request.effect) {
            is Effect.Render -> {
                this.view = ViewModel.bincodeDeserialize(view())
            }
        }
    }
}
