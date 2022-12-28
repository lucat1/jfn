from time import Time
from .function import FunctionAPI

service TimePrinter {
  execution: concurrent
  embed Time as Time

  inputPort TimeInput {
    location: "local"
    protocol: "sodep"
    interfaces: FunctionAPI
  }

  main {
    fn( request )( response ) {
      fmt = (request.data)
      getCurrentDateTime@Time({
        .format = fmt
      })(response.data)
    }
  }
}
