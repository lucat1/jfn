from console import Console
from string_utils import StringUtils

type SumRequest  { data: SumData }
type SumData {
  numbers[1,*]: int
}
type SumResponse { data: int }

interface SumAPI {
  RequestResponse:
    fn( SumRequest )( SumResponse )
}

service Sum {
  execution: single
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort SumInput {
    location: "local"
    protocol: sodep
    interfaces: SumAPI
  }

  main {
    fn( request )( response ) {
      response.data = 0
      for( i = 0, i < #request.data.numbers, i++ ) {
        response.data = response.data + request.data.numbers[i]
      }
    }
  }
}
