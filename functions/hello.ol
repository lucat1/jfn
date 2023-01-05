from console import Console

type HelloRequest { data: void }
type HelloResponse { data: string }

interface HelloAPI {
  RequestResponse:
    fn( HelloRequest )( HelloResponse )
}

service HelloPrinter {
  embed Console as Console
  execution: concurrent

  inputPort HelloInput {
    location: "local"
    protocol: "sodep"
    interfaces: HelloAPI
  }

  main {
    fn( request )( response ) {
      println@Console("Wrote Hello World!")()
      response.data = "Hello World!"
    }
  }
}
