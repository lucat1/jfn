type HelloRequest { data: void }
type HelloResponse { data: string }

interface HelloAPI {
  RequestResponse:
    fn( HelloRequest )( HelloResponse )
}

service HelloPrinter {
  execution: concurrent

  inputPort HelloInput {
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
