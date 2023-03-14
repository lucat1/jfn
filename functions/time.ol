from time import Time

type TimeServiceRequest  { data: string }
type TimeServiceResponse { data: string }

interface TimeServiceAPI {
  RequestResponse:
    fn( TimeServiceRequest )( TimeServiceResponse )
}

service TimePrinter {
  execution: single
  embed Time as Time

  inputPort TimeInput {
    location: "local"
    protocol: sodep
    interfaces: TimeServiceAPI
  }

  main {
    fn( request )( response ) {
      getCurrentDateTime@Time({
        format = request.data
      })(response.data)
    }
  }
}
