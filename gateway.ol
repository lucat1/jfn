from console import Console
from math import Math
from string_utils import StringUtils
from runtime import Runtime
from reflection import Reflection
from .runner import RunnerAPI
from .function import FunctionAPI
from .provisioner import ProvisionerAPI

type GatewayParams {
  gatewayLocation: string
  provisionerLocation: string
  verbose: bool
}

type GatewayRequest {
  fn: string
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

service Gateway(p : GatewayParams) {
  execution: concurrent
  embed Console as Console
  embed Math as Math
  embed StringUtils as StringUtils
  embed Runtime as Runtime
  embed Reflection as Reflection

  inputPort GatewayInput {
    location: p.gatewayLocation
    protocol: http { format = "json" }
    interfaces: GatewayAPI
  }

  outputPort Provisioner {
    location: p.provisionerLocation
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  outputPort Runner {
    protocol: sodep
    interfaces: RunnerAPI
  }

  outputPort Singleton {
    protocol: sodep
    interfaces: FunctionAPI
  }

  init {
    enableTimestamp@Console(true)()
    println@Console("Listening on " + p.gatewayLocation)()
  }

  main {
    [op( request )( response ) {
      scope(call_runner) {
        install(
          IOException => {
            response.error = true
            response.data = "Could not comunicate with the provisioner"
          }
        )
        executor@Provisioner({
          function = request.fn
        })(executor)
      }
      if(executor.type == "runner") {
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
            name = request.fn
            data << request.data
          }
          if(p.verbose) {
            valueToPrettyString@StringUtils( request )( t )
            println@Console( "Sending to runner at " + executor.location)()
          }
          Runner.location = executor.location
          run@Runner(invoke_data)(response)
        }
      } else if(executor.type == "singleton") {
        scope(call_singleton) {
          install(
            TypeMismatch => {
              response.error = true
              response.data = "Error while calling the function: " + call_singleton.TypeMismatch
            },
            InvocationFault => {
              response.error = true
              response.data = "Could not invoke singleton: " + call_singleton.InvocationFault
            }
          )

          invoke_data << {
            data << request.data
          }
          if(p.verbose) {
            valueToPrettyString@StringUtils( request )( t )
            println@Console( "Sending to singleton at " + executor.location)()
          }
          Singleton.location = executor.location
          fn@Singleton(invoke_data)(response)
          response.error = false
        }
      } else if(executor.type == "error") {
        response.error = true
        response.data = "Provisioner-level error. Possibly, no executor was found."
      } else {
        valueToPrettyString@StringUtils( executor )( t )
        println@Console( "executor: " + t )()
        response.error = true
        response.data = "Invalid executor type: " + executor.type
      }
    }]
  }
}
