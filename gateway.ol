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
      spawn(i over #global.runners) in pongs {
        port = global.runners[i]
        scope(call_runner) {
          install(
            TypeMismatch => {
              if(p.verbose) {
                valueToPrettyString@StringUtils( call_runner.TypeMismatch )( t )
                println@Console( "Ping error: " + t )()
              }
              unregister
            },
            InvocationFault => {
              if(p.verbose) {
                valueToPrettyString@StringUtils( call_runner.InvocationFault )( t )
                println@Console( "Ping error: " + t )()
              }
              unregister
            }
          )
          invokeRRUnsafe@Reflection({
            outputPort = port
            data = 0
            operation = "ping"
          })(pongs)
        }
      }

      for( i = 0, i < #pongs, i++ ){
        if(pongs[i] != 0) {
          if(p.verbose) {
            println@Console( "Ping didn't return 0: " + pongs[i] )()
          }
          unregister
        }
      }
    }

    [op( request )( response ) {
      if(#global.runners <= 0) {
        response.data = "There are no runners to execute the function"
        response.error = true
      } else {
        i = global.nextRunner
        if(global.nextRunner + 1 >= #global.runners) {
          global.nextRunner = 0
        } else {
          global.nextRunner++
        }

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
