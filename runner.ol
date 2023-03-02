from console import Console
from string_utils import StringUtils
from file import File
from runtime import Runtime
from reflection import Reflection
from .runner import RunnerAPI
from .gateway import GatewayInternalAPI
from .function import FunctionAPI
from .function_catalog import FunctionCatalogAPI

type RunnerParams {
  location: string
  gatewayInternal: string
  functionCatalog: string

  verbose: bool
}

type RunRequest {
  name: string
  id: string
  data?: undefined
}

type RunResponse {
  error: bool
  data?: undefined
}

interface RunnerAPI {
  RequestResponse:
    ping( int )( int ),
    run( RunRequest )( RunResponse )
}

constants {
  RUNNER_FUNCTIONS_PATH = "/tmp/jfn",
  RUNNER_FUNCTION_PROTOCOL = "sodep",
  RUNNER_FUNCTION_OPERATION = "fn"
}

define derive_filename {
  filename = RUNNER_FUNCTIONS_PATH + sep + request.name + ".ol"
}

service Runner( p : RunnerParams ) {
  execution: concurrent
  embed Console as Console
  embed File as File
  embed Runtime as Runtime
  embed Reflection as Reflection
  embed StringUtils as StringUtils

  outputPort FunctionCatalog {
    location: p.functionCatalog
    protocol: "sodep"
    interfaces: FunctionCatalogAPI
  }

  outputPort Gateway {
    location: p.gatewayInternal
    protocol: "sodep"
    interfaces: GatewayInternalAPI
  }

  inputPort RunnerInput {
    location: p.location
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

    if(p.verbose) {
      println@Console("Attaching to gateway at " + p.gatewayInternal)()
    }
    register@Gateway({
      location = p.location
    })()
  }

  main {
    run( request )( response ) {
      if(p.verbose) {
        valueToPrettyString@StringUtils( request )( t )
        println@Console( "Calling: " + t )()
      }
      derive_filename
      exists@File(filename)(exists)
      // TODO: use the function name + the hash of the contents as a file name
      if(!exists) {
        get@FunctionCatalog({
          name = request.name
        })(response)
        if(!response.error) {
          content << response.data
          undef(response.data)
          scope(write_function) {
            install(
              FileNotFound => {
                response.error = true
                response.data = "Could not find function file or its parent directories"
              },
              IOException => {
                response.error = true
                response.data = "Could not write to the function file"
              }
            )
            writeFile@File({
              filename = filename
              format = "text"
              content = content
            })()
            if(p.verbose) {
              println@Console("Wrote function to " + filename)()
            }
          }
        }
      }
      if(!response.error) {
        scope(load_service) {
          install(
            RuntimeException => {
              response.error = true
              response.data = "Could not load function service: " + load_service.RuntimeException
            }
          )
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
        }
        invoke_data << request
        undef(invoke_data.name)
        undef(invoke_data.id)
        scope(call_service) {
          install(
            InvocationFault => {
              response.error = true
              response.data = "Error while calling the function: " + call_service.InvocationFault.name
            }
          )
          invokeRRUnsafe@Reflection({
            outputPort = port_name
            data << invoke_data
            operation = RUNNER_FUNCTION_OPERATION
          })(output)
          removeOutputPort@Runtime(port_name)()
          /* println@Console("Run successful")() */
          response.data << output.data
          response.error = false
        }
      }
    }
  }
}
