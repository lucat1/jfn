from console import Console
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

type GatewayRegisterRequest {
  location: string
}

interface GatewayInternalAPI {
  RequestResponse:
    register( GatewayRegisterRequest )( void )
}

service Gateway( p : GatewayParams ) {
  execution: concurrent
  embed Console as Console
  embed StringUtils as StringUtils
  embed Runtime as Runtime
  embed Reflection as Reflection

  inputPort GatewayInput {
    location: p.location
    protocol: http { format = "json" }
    interfaces: GatewayAPI
  }

  inputPort GatewayInternalInput {
    location: p.internal
    protocol: "sodep"
    interfaces: GatewayInternalAPI
  }

  init {
    enableTimestamp@Console(true)()
    global.nextRunner = 0
  }

  main {
    [op( request )( response ) {
      if(#global.runner <= 0) {
        response.data = "There are no runners to execute the function"
        response.error = true
      } else {
        i = global.nextRunner
        if(global.nextRunner + 1 >= #global.runners) {
          global.nextRunner = 0
        } else {
          global.nextRunner = global.nextRunner + 1
        }

        getRandomUUID@StringUtils()(id)
        scope(call_runner) {
          install(
            TypeMismatch => {
              response.error = true
              response.data = "Error while calling the function: " + call_runner.TypeMismatch
            }
          )

          invoke_data << {
            name = request.name
            id = id
            data = request.data
          }
          if(p.verbose) {
            valueToPrettyString@StringUtils( request )( t )
            println@Console( "Sending to runner #" + i + ": " + t )()
          }
          invokeRRUnsafe@Reflection({
            outputPort = global.runner[i]
            data << invoke_data
            operation = "run"
          })(response)
        }
      }
    }]

    [register( request )( response ) {
          name = "port_" +  #global.runner
          println@Console("Registering runner #" + #global.runner)()
          setOutputPort@Runtime({
            protocol = "sodep"
            name = name
            location = request.location
          })()
          global.runner[#global.runner] = name
    }]
  }
}
