from console import Console
from string_utils import StringUtils
from .runner import RunnerAPI

type GatewayRequest {
  name: string
  data: undefined
}

type GatewayResponse {
  error: bool
  data: undefined
}

interface GatewayAPI {
  RequestResponse:
    op( GatewayRequest )( GatewayResponse )
}

service Gateway {
  execution: concurrent
  embed Console as Console
  embed StringUtils as StringUtils

  outputPort Runner {
    location: "socket://localhost:8081"
    protocol: "sodep"
    interfaces: RunnerAPI
  }

  inputPort GatewayInput {
    location: "socket://localhost:8080"
    protocol: http { format = "json" }
    interfaces: GatewayAPI
  }

  init {
    enableTimestamp@Console(true)()
  }

  main {
    op( request )( response ) {
      getRandomUUID@StringUtils()(id)
      println@Console("Calling " + request.name + " #" + id)()
      run@Runner({
        .name = request.name
        .id = id
        .data = request.data
      })(response)
    }
  }
}
