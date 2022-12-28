from console import Console
from .runner import RunnerAPI

type GatewayRequest {
  name: string
  data: undefined
}
type GatewayResponse { data: undefined }

interface GatewayAPI {
  RequestResponse:
    op( GatewayRequest )( GatewayResponse )
}

service Gateway {
  execution: concurrent
  embed Console as Console

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
      println@Console("Calling " + request.name)()
      run@Runner(request)(response)
    }
  }
}
