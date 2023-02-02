type SumRequest  { data[0,1]: int }
type SumResponse { data: int }

interface SumAPI {
  RequestResponse:
    fn( SumRequest )( SumResponse )
}

service Sum {
  execution: single

  inputPort SumInput {
    location: "local"
    protocol: "sodep"
    interfaces: SumAPI
  }

  main {
    fn( request )( response ) {
      response = request[0] + request[1]
    }
  }
}
