from console import Console
from file import File
from runtime import Runtime
from reflection import Reflection
from .runner import RunnerAPI
from .function import FunctionAPI
from .function_catalog import FunctionCatalogAPI

type RunRequest {
  id: string
  name: string
  data?: undefined
}

type RunResponse {
  error: bool
  data?: undefined
}

interface RunnerAPI {
  RequestResponse:
    run( RunRequest )( RunResponse )
}

constants {
  RUNNER_FUNCTIONS_PATH = "/tmp/jfn",
  RUNNER_FUNCTION_PROTOCOL = "sodep",
  RUNNER_FUNCTION_OPERATION = "fn"
}

define derive_filename {
  filename = RUNNER_FUNCTIONS_PATH + sep + request.id + ".ol"
}

service Runner {
  execution: concurrent
  embed Console as Console
  embed File as File
  embed Runtime as Runtime
  embed Reflection as Reflection

  outputPort FunctionCatalog {
    location: "socket://localhost:8082"
    protocol: http { format = "json" }
    interfaces: FunctionCatalogAPI
  }

  inputPort RunnerInput {
    location: "socket://localhost:8081"
    protocol: "sodep"
    interfaces: RunnerAPI
  }

  init {
    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)

    exists@File(RUNNER_FUNCTIONS_PATH)(exists)
    if(!exists) {
      mkdir@File(RUNNER_FUNCTIONS_PATH)()
    }
  }

  main {
    run( request )( response ) {
      println@Console("Calling " + request.name + " #" + request.id)()
      get@FunctionCatalog({
        name = request.name
      })(response)
      if(!response.error) {
        derive_filename
        content << response.data
        undef(response.data)
        writeFile@File({
          filename = filename
          format = "text"
          content = content
        })()
        println@Console("Wrote function to " + filename)()
        loadEmbeddedService@Runtime({
          filepath = filename
          type = "jolie"
        })(loc)
        port_name = "op-" + request.id
        setOutputPort@Runtime({
          protocol = RUNNER_FUNCTION_PROTOCOL
          name = port_name
          location = loc
        })()
        invoke_data << request
        undef(invoke_data.id)
        undef(invoke_data.name)
        invokeRRUnsafe@Reflection({
          outputPort = port_name
          data << invoke_data
          operation = RUNNER_FUNCTION_OPERATION
        })(output)
        removeOutputPort@Runtime(port_name)()
        println@Console("Run successful")()
        response.data << output.data
        response.error = false
      }
    }
  }
}
