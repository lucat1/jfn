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
  type: string
  location: string
  ping: string
  function?: string
}

interface ProvisionerAPI {
  RequestResponse:
    register( RegisterRequest )( void ),
    executor( ExecutorRequest )( ExecutorResponse )
}

interface ExecutorAPI {
  RequestResponse:
    ping( int )( int ),
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

  outputPort Executor {
    protocol: sodep
    Interfaces: ExecutorAPI
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
    println@Console("Ping failed, removing executor: #" + i + " (type: " + global.executors[i].type + ", location: " + global.executors[i].location + ")")()
    undef(global.executors[i])
  }

  init {
    enableTimestamp@Console(true)()
    global.nextExecutor = 0
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
    println@Console("Listening on " + p.location)()
  }

  main {
    [schedulerCallback(request)] {
      if(request.groupName == "ping") {
        spawn(i over #global.executors) in pongs {
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

            Executor.location = global.executors[i].ping
            ping@Executor(0)(pongs)
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
      valueToPrettyString@StringUtils( request )( t )
      println@Console("Registered " + request.type + " #" + #global.executors + ": " + t)()
      global.executors[#global.executors] << request
    }]

    [executor( request )( response ) {
      found = false
      for(i = 0, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "singleton" && executor.function == request.function) {
          response << executor
          undef(response.ping)
          undef(response.function)
          found = true
        }
      }

    for(i = global.nextExecutor, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "runner") {
          response << executor
          undef(response.ping)
          global.nextExecutor = i + 1
          found = true
        }
      }

      if(!found) {
        println@Console("No singleton or runner to execute the job onto!")()
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
