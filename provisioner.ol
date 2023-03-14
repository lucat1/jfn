from console import Console
from string_utils import StringUtils
from scheduler import Scheduler
from .jocker import InterfaceAPI
from .scheduler import SchedulerCallBackInterface
from .runner import RunnerAPI

type ProvisionerParams {
  location: string

  verbose: bool
}

type ExecutorRequest { function: string }
type ExecutorResponse {
  type: string
  location: string
}

type RegisterRequest {
  location: string
}

interface ProvisionerAPI {
  RequestResponse:
    register( RegisterRequest )( void ),
    executor( ExecutorRequest )( ExecutorResponse )
}

service Provisioner(p : ProvisionerParams ) {
  execution: concurrent
  embed Console as Console
  embed Scheduler as Scheduler
  embed StringUtils as StringUtils

  outputPort Jocker {
    Location: "socket://localhost:8008"
    protocol: sodep
    Interfaces: InterfaceAPI
  }

  outputPort Runner {
    protocol: sodep
    Interfaces: RunnerAPI
  }

  inputPort ProvisionerInput {
    location: p.location
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  define unregister {
    println@Console("Ping failed, removing runner: #" + i + " (" + global.runners[i] + ")")()
    undef(global.runners[i])
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
    [schedulerCallback(request)] {
      if(request.groupName == "ping") {
        spawn(i over #global.runners) in pongs {
          location = global.runners[i]
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

            Runner.location = location
            ping@Runner(0)(pongs)
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
    }

    [register( request )( ) {
      println@Console("Registered runner #" + #global.runners + " at " + request.location)()
      global.runners[#global.runners] = request.location
    }]

    [executor( request )( response ) {
      found = false
      for(i = 0, i < #global.services, i++) {
        service = global.services[i]
        if(service.function == request.function) {
          response.type = "service"
          response.location = service.location
          found = true
          i = #global.services // break
        }
      }

      if(!found) {
        if(++global.nextRunner >= #global.runners) {
          global.nextRunner = 0
        }
        response.type = "runner"
        response.location = global.runners[global.nextRunner]
        found = true
      }

      if(!found) {
        println@Console("TODO: always keep a runner spinning")()
        response.type = "error"
        response.location = "error"
      } 

      if(p.verbose) {
        valueToPrettyString@StringUtils( response )( t )
        println@Console( "Load balancer target: " + t )()
      }
    }]
  }
}
