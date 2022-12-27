from time import Time

type TimeRequest { format: string }

interface TimeAPI {
  RequestResponse:
    time( TimeRequest )( string )
}

service TimePrinter {
  execution: concurrent
  embed Time as Time

  inputPort TimeInput {
    location: "local"
    protocol: http { format = "json" }
    interfaces: TimeAPI
  }

  main {
    time( request )( response ) {
      getCurrentDateTime@Time(request)(response)
    }
  }
}
