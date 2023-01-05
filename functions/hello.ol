type HelloResponse { data: string }

interface HelloAPI {
  RequestResponse:
    fn( void )( HelloResponse )
}

service TimePrinter {
  execution: concurrent

  inputPort TimeInput {
    location: "local"
    protocol: "sodep"
    interfaces: HelloAPI
  }

  main {
    fn( request )( response ) {
      response.data = "Hello World!"
    }
  }
}
