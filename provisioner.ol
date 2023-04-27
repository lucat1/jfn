from console import Console
from runtime import Runtime
from string_utils import StringUtils
from scheduler import Scheduler
from .scheduler import SchedulerCallBackInterface
from .spawner import Spawner

type ProvisionerParams {
  provisionerLocation: string
  advertiseLocation: string
  jockerLocation: string
  functionCatalogLocation: string

  verbose: bool
  debug: bool

  // provisioning parameters
  dockerNetwork: string
  minRunners: int
  callsPerRunner: int
  callsForPromotion: int
}

type ExecutorRequest { function: string }
type ExecutorResponse {
  type: string
  location: string
}

type RegisterRequest {
  type: string
  invokeLocation: string
  pingLocation: string
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

constants {
  JFN_RUNNER_IMAGE = "jfn/runner",
  JFN_SINGLETON_IMAGE = "jfn/singleton"
}

service Provisioner( p : ProvisionerParams ) {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed Scheduler as Scheduler
  embed StringUtils as StringUtils
  embed Spawner({
    jockerLocation = p.jockerLocation
  }) as Spawner

  outputPort Executor {
    protocol: sodep
    Interfaces: ExecutorAPI
  }

  outputPort Jocker {
    location: p.jockerLocation
    protocol: sodep
    Interfaces: ExecutorAPI
  }

  inputPort ProvisionerInput {
    location: p.provisionerLocation
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
    println@Console("Ping failed, removing executor: #" + i + " (type: " + global.executors[i].type + ", location: " + global.executors[i].invokeLocation + ")")()
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
    setCronJob@Scheduler({
      jobName = "provision"
      groupName = "provision"
      cronSpecs << {
        year = "*"
        dayOfWeek = "*"
        month = "*"
        dayOfMonth = "?"
        hour = "*"
        minute = "*"
        second = "0"
      }
    })()
    for(i = 0, i < p.minRunners, i++) {
      name = "runner-" + i
      println@Console("Launching runner: " + name)()
      spwn@Spawner({
        name = name
        type = "runner"
        image = JFN_RUNNER_IMAGE

        provisionerLocation = p.advertiseLocation
        functionCatalogLocation = p.functionCatalogLocation
        verbose = p.verbose
        debug = p.debug
      })()
    }

    // provisioning state
    global.nextExecutor = 0
    global.runnerCalls = 0
    global.callsByFunction = void

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

            Executor.location = global.executors[i].pingLocation
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
      } else if(request.groupName == "provision") {
        // TODO
        if(p.debug) {
          valueToPrettyString@StringUtils( global.callsByFunction )( t )
          println@Console("Provisioning: \nrunnerCalls: " + global.runnerCalls + "\ncallsByFunction: " + t)()
        }
      }
    }

    [register( request )( ) {
      valueToPrettyString@StringUtils( request )( t )
      println@Console("Registered executor #" + #global.executors + ": " + t)()
      i = #global.executors
      global.executors[i] << request
      global.callsByRunner[i] = 0
    }]

    [executor( request )( response ) {
      found = false
      found_i = -1
      for(i = 0, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "singleton" && executor.function == request.function) {
          response << executor
          found_i = i
          found = true
        }
      }

      for(i = global.nextExecutor, i < #global.executors && !found, i++) {
        executor << global.executors[i]
        if(executor.type == "runner") {
          response << executor
          global.nextExecutor = i + 1
          found_i = i
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
            found_i = i
            found = true
          }
        }
      }

      if(!found) {
        println@Console("No singleton or runner to execute the job onto!")()
        response.type = "error"
        response.location = "error"
      } else {
        response.location = response.invokeLocation
        undef(response.invokeLocation)
        undef(response.pingLocation)
        undef(response.function)

        if(response.type == "runner") {
          global.callsByRunner[found_i]++
        } else if(response.type == "singleton") {
          global.callsByFunction[request.function]++
        }
      }

      if(p.verbose) {
        valueToPrettyString@StringUtils( response )( t )
        println@Console( "Load balancer target: " + t )()
      }
    }]
  }
}
