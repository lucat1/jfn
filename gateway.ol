from console import Console
from math import Math
from scheduler import Scheduler
from string_utils import StringUtils
from runtime import Runtime
from reflection import Reflection
from .runner import RunnerAPI
from .scheduler import SchedulerCallBackInterface

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
  embed Scheduler as Scheduler
  embed Math as Math
  embed StringUtils as StringUtils
  embed Runtime as Runtime
  embed Reflection as Reflection

  define unregister {
    println@Console("Ping failed, removing runner: #" + i)()
    undef(global.runners[i])
  }

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

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  init {
    enableTimestamp@Console(true)()
    setCallbackOperation@Scheduler({
      operationName = "schedulerCallback"
    })
    global.nextRunner = 0
    setCronJob@Scheduler({
      jobName = "ping"
      groupName = "ping"
      cronSpecs << {
        year = "*"
        dayOfWeek = "*"
        month = "*"
        dayOfMonth = "?"
        hour = "*"
        minute = "*"
        second = "*"
      }
    })()
  }

  main {
    [register( request )( ) {
      name = "port_" +  #global.runners
      setOutputPort@Runtime({
        protocol = "sodep"
        name = name
        location = request.location
      })()
      println@Console("Registered runner #" + #global.runners)()
      global.runners[#global.runners] = name
    }]


    [schedulerCallback(request)] {
      for( i = 0, i < #global.runners, i++ ) {
        port = global.runners[i]
        scope(call_runner) {
          install(
            TypeMismatch => {
              unregister
            }
          )
          if(p.verbose) {
            println@Console("Pinging runner on port: " + port)()
          }
          invokeRRUnsafe@Reflection({
            outputPort = port
            data = 0
            operation = "ping"
          })(o)

          if(o != 0) {
            unregister
          }
        }
      }
    }

    [op( request )( response ) {
      if(#global.runners <= 0) {
        response.data = "There are no runners to execute the function"
        response.error = true
      } else {
        i = global.nextRunner
        if(global.nextRunner + 1 >= #global.runnerss) {
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
            outputPort = global.runners[i]
            data << invoke_data
            operation = "run"
          })(response)
        }
      }
    }]
  }
}
