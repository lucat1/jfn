include "time.ol"

type RunRequest { input: string }
type RunResponse { output: string }

interface RunnerAPI {
  RequestResponse:
    run( RunRequest )( RunResponse )
}

service Runner {
  execution: concurrent

  outputPort TimePrinterPort {
    Interfaces: TimeAPI
  }
  embed TimePrinter in TimePrinter

  inputPort RunnerInput {
    location: "socket://localhost:8081"
    protocol: http { format = "json" }
    interfaces: RunnerAPI
  }

  main {
    run( request )( response ) {
      time@TimePrinter({
        .format = request.input
      })(response.output)
    }
  }
}

