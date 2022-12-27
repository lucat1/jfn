from timeService import TimePrinter, TimeAPI
include "runner.iol"

service Runner {
  execution: concurrent

  outputPort TimePrinterPort {
    interfaces: TimeAPI
  }
  embed TimePrinter in TimePrinterPort

  inputPort RunnerInput {
    location: "socket://localhost:8081"
    protocol: "sodep"
    interfaces: RunnerAPI
  }

  main {
    run( request )( response ) {
      fmt = string(request.data)
      time@TimePrinterPort({
        .format = fmt
      })(response.data)
    }
  }
}
