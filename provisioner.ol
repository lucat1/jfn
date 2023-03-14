from console import Console
from scheduler import Scheduler
from .jocker import InterfaceAPI
from .scheduler import SchedulerCallBackInterface

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
    register( RegisterRequest )( void )
    executor( ExecutorRequest )( ExecutorResponse )
}

service Provisioner(p : ProvisionerParams ) {
  execution: concurrent
  embed Console as Console
  embed Scheduler as Scheduler

  outputPort Jocker {
    Location: "socket://localhost:8008"
    protocol: sodep
    Interfaces: InterfaceAPI
  }

  inputPort ProvisionerInput {
    location: p.location
    protocol: http { format = "json" }
    interfaces: ProvisionerAPI
  }

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  define unregister {
    println@Console("Ping failed, removing runner: #" + i + " (" + global.runners[i] ")")()
    undef(global.runners[i])
  }

  init {
    global.runners = []
    global.services = []

    setCronJob@Scheduler({
      jobName = "load"
      groupName = "load"
      cronSpecs << {
        year = "*"
        dayOfWeek = "*"
        month = "*"
        dayOfMonth = "?"
        hour = "*"
        minute = "*"
        second = "0/10"
      }
    })()

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
        second = "0/10"
      }
    })()
  }

  main {
    [schedulerCallback(request)] {
      if(request.groupName == "ping") {
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
    }

    [register( request )( ) {
      name = "port_" +  #global.runners
      setOutputPort@Runtime({
        protocol = sodep
        name = name
        location = request.location
      })()
      println@Console("Registered runner #" + #global.runners)()
      global.runners[#global.runners] = name
    }]

    [executor( request )( response ) {
      for(i = 0, i < #global.services, i++) {
        service = global.services[i]
        if(service.function == request.function) {
          response.type = "service"
          response.location = service.location
          i = #global.services // break
        }
      }

      for(i = 0, i < #global.runners, i++) {
        runner = global.services[i]
        if(runner.function == request.function) {
          response.type = "runner"
          response.location = runner.location
          i = #global.runners // break
        }
      }
    }]
  }
}
