from console import Console
from math import Math
from string_utils import StringUtils
from runtime import Runtime
from reflection import Reflection
from .runner import RunnerAPI

type GatewayParams {
  location: string
  internal: string
  
  verbose: bool
}

type GatewayRequest {
  name: string
  data?: undefined
}

type GatewayResponse {
  error: bool
  data?: undefined
}

interface GatewayAPI {
  RequestResponse:
    op( GatewayRequest )( GatewayResponse )
}

service Gateway( p : GatewayParams ) {
  execution: concurrent
  embed Console as Console
  embed Math as Math
  embed StringUtils as StringUtils
  embed Runtime as Runtime
  embed Reflection as Reflection

  inputPort GatewayInput {
    location: p.location
    protocol: http { format = "json" }
    interfaces: GatewayAPI
  }

  outputPort Provisioner {
    location: p.provisioner
    protocol: sodep
    interfaces: RunnerAPI
  }

  outputPort Runner {
    protocol: sodep
    interfaces: RunnerAPI
  }

  init {
    enableTimestamp@Console(true)()
  }

  main {
    [op( request )( response ) {
      executor@Provisioner({
        function = request.function
      })(executor)
      if(executor.type == "runner") {
        getRandomUUID@StringUtils()(id)
        scope(call_runner) {
          install(
            TypeMismatch => {
              response.error = true
              response.data = "Error while calling the function: " + call_runner.TypeMismatch
            },
            InvocationFault => {
              response.error = true
              response.data = "Could not invoke runner: " + call_runner.InvocationFault
            }
          )

          invoke_data << {
            name = request.name
            id = id
            data = request.data
          }
          if(p.verbose) {
            valueToPrettyString@StringUtils( request )( t )
            println@Console( "Sending to runner at " + executor.location)()
          }
          Runner.location = executor.location
          run@Runner(invoke_data)(response)
        }
      } else if(executor.type == "service") {
        response.error = true
        response.data = "Service executor is not handled yet"
      } else {
        response.error = true
        response.data = "Invalid executor type: " + executor.type
      }
    }]
  }
}
