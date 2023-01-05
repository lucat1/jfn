from console import Console

type HelloRequest { data: void }

interface HelloAPI {
  RequestResponse:
    fn( HelloRequest )( string )
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
      response = "Hello World!"
    }
  }
}
