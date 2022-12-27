from runner import RunnerAPI
from console import Console
include "runner.iol"

type GatewayRequest {
  name: string
  data: undefined
}
type GatewayResponse { data: undefined }

interface GreeterAPI {
  RequestResponse: op( GatewayRequest )( GatewayResponse )
}

service Greeter {
  execution: concurrent
  embed Console as Console

  outputPort Runner {
    location: "socket://localhost:8081"
    protocol: "sodep"
    interfaces: RunnerAPI
  }

  inputPort GreeterInput {
      location: "socket://localhost:8080"
      protocol: http { format = "json" }
      interfaces: GreeterAPI
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
