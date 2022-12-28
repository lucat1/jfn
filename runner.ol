from console import Console
from file import File
from .runner import RunnerAPI
from .function import FunctionAPI
from .function_catalog import FunctionCatalogAPI

type RunRequest {
  name: string
  id: string
  data: undefined
}

type RunResponse {
  error: bool
  data: undefined
}

interface RunnerAPI {
  RequestResponse:
    run( RunRequest )( RunResponse )
}

constants {
  RUNNER_FUNCTIONS_PATH = "/tmp/jfn"
}

define derive_filename {
  filename = RUNNER_FUNCTIONS_PATH + sep + request.id + ".ol"
}

service Runner {
  execution: concurrent
  embed Console as Console
  embed File as File

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

  main {
    run( request )( response ) {
      println@Console("Calling " + request.name + " #" + id)()
      get@FunctionCatalog({
        .name = request.name
      })(content)
      derive_filename
      writeFile@File({
        .filename = filename
        .format = "text"
        .content = content
      })()
      // TODO
      response.data = "ok"
      response.error = false
    }
  }
}
