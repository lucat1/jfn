from console import Console
from runtime import Runtime
from string_utils import StringUtils
from scheduler import Scheduler
from .scheduler import SchedulerCallBackInterface
from .runner import RunnerAPI

type ProvisionerParams {
  provisionerLocation: string
  verbose: bool
  debug: bool
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

service Provisioner( p : ProvisionerParams ) {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed Scheduler as Scheduler
  embed StringUtils as StringUtils

  outputPort Executor {
    protocol: sodep
    Interfaces: ExecutorAPI
  }

  inputPort ProvisionerInput {
    location: "socket://0.0.0.0:6001"
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  // round-robin
  define rr {
    if(global.nextExecutor >= #global.executors) {
      global.nextExecutor = 0
    }
  }

  define unregister {
    println@Console("Ping failed, removing executor: #" + i + " (type: " + global.executors[i].type + ", location: " + global.executors[i].location + ")")()
    undef(global.executors[i])
    rr
  }

  define handle_ping_error {
    if(p.verbose) {
      valueToPrettyString@StringUtils( call_runner )( t )
      println@Console( "Ping error: " + t )()
    }
    unregister
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
    println@Console("Listening on " + p.provisionerLocation)()
  }

  main {
    [schedulerCallback(request)] {
      if(request.groupName == "ping") {
        spawn(i over #global.executors) in pongs {
          scope(call_runner) {
            install(
              TypeMismatch => {
                handle_ping_error 
              },
              InvocationFault => {
                handle_ping_error 
              },
              IOException => {
                handle_ping_error 
              },
              Timeout => {
                handle_ping_error 
              }
            )

            Executor.location = global.executors[i].ping
            if(p.debug) {
              println@Console("Pinging " + Executor.location)()
            }
            pongs[i] = -1
            ping@Executor(0)(pongs)
          }
        }
        if(p.debug) {
          valueToPrettyString@StringUtils( pongs )( t )
          println@Console( "Pongs: " + t )()
        }
        for( i = 0, i < #pongs, i++ ) {
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
      println@Console("Registered executor #" + #global.executors + ": " + t)()
      global.executors[#global.executors] << request
    }]

    [executor( request )( response ) {
      found = false
      for(i = 0, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "singleton" && executor.function == request.function) {
          response << executor
          found = true
        }
      }

      for(i = global.nextExecutor, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "runner") {
          response << executor
          global.nextExecutor = i + 1
          found = true
        }
      }
      rr
      // if not found with the round robin strategy, try all available options
      if(!found) {
        for(i = 0, i < #global.executors && !found, i++) {
          executor << global.executors[i]
          if(executor.type == "runner") {
            response << executor
            global.nextExecutor = i + 1
            found = true
          }
        }
      }

      if(!found) {
        println@Console("No singleton or runner to execute the job onto!")()
        response.type = "error"
        response.location = "error"
      } else {
        undef(response.ping)
        undef(response.function)
      }

      if(p.verbose) {
        valueToPrettyString@StringUtils( response )( t )
        println@Console( "Load balancer target: " + t )()
      }
    }]
  }
}
