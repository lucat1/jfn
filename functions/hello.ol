type HelloRequest { data?: string }
type HelloResponse { data: string }

interface HelloAPI {
  RequestResponse:
    fn( HelloRequest )( HelloResponse )
}

service HelloPrinter {
  execution: single

  inputPort HelloInput {
    location: "local"
    protocol: sodep
    interfaces: HelloAPI
  }

  main {
    fn( request )( response ) {
      if(!is_defined(request.data))
        request.data = "anonymous"
      response.data = "Hello " +  request.data +"!"
    }
  }
}
