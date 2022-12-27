from timeService import TimePrinter
include "runner.iol"
include "../function.iol"

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
