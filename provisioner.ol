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
  callsPerSingleton: int
}

type ExecutorRequest { function: string }
type ExecutorResponse {
  type: string
  location: string
}

type RegisterRequest {
  type: string
  name: string
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

  // create a new tuple if not available or increase the count for an already
  // existing tuple
  define count_call {
    if(response.type == "runner") {
      global.runnerCalls++
    }
    if(!is_defined(global.callsByFunction.(request.function))) {
      global.callsByFunction.(request.function) = 0
    }
    global.callsByFunction.(request.function)++
  }

  define unregister {
    println@Console("Ping failed, removing executor: #" + i + " (type: " + global.executors[i].type + ", location: " + global.executors[i].invokeLocation + ")")()
    if(global.executors[i].type == "runner") {
      global.runners--
    }
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

  define spawn_executor {
    getRandomUUID@StringUtils()(id)
    name = "executor-" + id
    spwnInfo << {
      name = name
      image = image
    }
    if(p.verbose) {
      valueToPrettyString@StringUtils( spwnInfo )( t )
      println@Console("Starting new executor: " + t)()
    }

    spwnInfo << {
      provisionerLocation = p.advertiseLocation
      functionCatalogLocation = p.functionCatalogLocation
      verbose = p.verbose
      debug = p.debug
    }
    if(is_defined(function)) {
      spwnInfo.function = function
    }
    spwn@Spawner(spwnInfo)(id)
    global.executorIdByName[name] = id
  }

  define kill_executor {
    kill@Spawner({
      id = id
    })()
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
      image = JFN_RUNNER_IMAGE
      spawn_executor
    }

    // provisioning state
    global.nextExecutor = 0
    global.runners = 0
    global.runnerCalls = 0

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
        if(p.verbose) {
          valueToPrettyString@StringUtils( global.callsByFunction )( t )
          println@Console("PROVISIONING\nCalls handled by runners: " + global.runnerCalls + "\nCalls by function name: " + t)()
        }

        // compute how many (if any) singletons we should have per function
        foreach(fn : global.callsByFunction) {
          if(global.callsByFunction.(fn) > p.callsForPromotion) {
            singletons.(fn) = global.callsByFunction.(fn) / p.callsPerSingleton
            // decrement the number of calls by the amout that are going to be
            // served by singletons from now on.
            global.runnerCalls = global.runnerCalls * 
          } else {
            singletons.(fn) = 0
          }
        }

        // diff between the currently running singletons (global.singletons)
        // and the new scheduling plan (local singletons)
        // first, create an hash map of all the function's names that have an
        // active singleton or have been called in the current time frame
        foreach(fn : singletons) {
          fns.(fn) = 0
        }
        foreach(fn : global.singletons) {
          fns.(fn) = 0
        }
        
        // now compare and start/stop singletons where needed
        foreach(fn : fns) {
          new = 0
          if(is_defined(singletons.(fn))) {
            new = singletons.(fn)
          }
          old = #global.singletons.(fn)

          if(new > old) {
            n = new - old

            // start n new singletons
            for(i = 0, i < n, i++) {
              image = JFN_SINGLETON_IMAGE
              function = fn
              spawn_executor
            }
          } else if(new < old) {
            n = old - new

            // stop n old singletons
            for(i = 0, i < n, i++) {
              // TODO: kill global.singletons.(fn)[i]
              undef(global.singletons.(fn)[i])
            }
          }
        }

        for(i = #global.callsByFunction - 1, i >= 0, i--) {
          tuple << global.callsByFunction[i]
          if(tuple.count > p.callsForPromotion) {
            image = JFN_SINGLETON_IMAGE
            function = tuple.function
            spawn_executor
            global.runnerCalls = global.runnerCalls - tuple.count
          }
          undef(global.callsByFunction[i])
        }

        expectedRunners = global.runnerCalls / p.callsPerRunner
        // don't go below the minimum number of runners
        if(expectedRunners < p.minRunners) {
          expectedRunners = p.minRunners
        }
        if(p.verbose) {
          println@Console("Expected runners: " + expectedRunners + " (min: " + p.minRunners + "), actualRunners: " + global.runners)()
        }

        start = #global.executors
        if(expectedRunners > global.runners) {
          diff = expectedRunners - global.runners
          for(i = 0, i < diff, i++) {
            image = JFN_RUNNER_IMAGE
            spawn_executor
          }
        } else if(expectedRunners < global.runners) {
          start = start
          // TODO: quit runners, just remove them from the list of executors
          // and they should die automatically in 10s
        }
        global.runnerCalls = 0
      }
    }

    [register( request )( ) {
      i = #global.executors
      valueToPrettyString@StringUtils( global.executorIdByName )( t )
      println@Console( "executorByName: " + t )()
      request.id = global.executorIdByName[request.name]
      undef(global.executorIdByName[request.name])

      valueToPrettyString@StringUtils( request )( t )
      println@Console("Registered executor #" + i + ": " + t)()
      global.executors[i] << request
      if(request.type == "runner") {
        global.runners++
      } else if(request.type == "singleton") {
        global.executors.(request.function)[#global.executors.(request.function)] = 
      }
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
        count_call

        response.location = response.invokeLocation
        undef(response.invokeLocation)
        undef(response.pingLocation)
        undef(response.function)
        undef(response.name)
        undef(response.id)
      }
      

      if(p.verbose) {
        valueToPrettyString@StringUtils( response )( t )
        println@Console( "Load balancer target: " + t )()
      }
    }]
  }
}
