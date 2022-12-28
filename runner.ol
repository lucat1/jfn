from .timeService import TimePrinter
from .runner import RunnerAPI
from .function import FunctionAPI

type RunRequest {
  name: string
  data: undefined
}
type RunResponse { data: undefined }

interface RunnerAPI {
  RequestResponse:
    run( RunRequest )( RunResponse )
}

service Runner {
  execution: concurrent

  outputPort TimePrinterPort {
    interfaces: FunctionAPI
  }
  embed TimePrinter in TimePrinterPort

  inputPort RunnerInput {
    location: "socket://localhost:8081"
    protocol: "sodep"
    interfaces: RunnerAPI
  }

  main {
    run( request )( response ) {
      fn@TimePrinterPort({
        .data = request.data
      })(response)
    }
  }
}
