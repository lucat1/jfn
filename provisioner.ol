from console import Console
from runtime import Runtime
from string_utils import StringUtils
from scheduler import Scheduler
from .scheduler import SchedulerCallBackInterface
from .executor import ExecutorAPI
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
  commsLocation: string
  function?: string
}

interface ProvisionerAPI {
  RequestResponse:
    register( RegisterRequest )( void ),
    executor( ExecutorRequest )( ExecutorResponse )
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

  // create a expected tuple if not available or increase the count for an already
  // existing tuple
  define count_call {
    global.calls++
    if(!is_defined(global.callsByFunction.(request.function))) {
      global.callsByFunction.(request.function) = 0
    }
    global.callsByFunction.(request.function)++
  }

  define handle_ping_error {
    valueToPrettyString@StringUtils( exe )( t )
    valueToPrettyString@StringUtils( call_runner )( err )
    println@Console("Ping error on " + t + "Removing executor: #" + i + " (type: " + collection[i].type + ", location: " + collection[i].invokeLocation + ")\n" + err)()
    // TODO: check that the link works with undef later too
    exe -> collection[i]
    undef(exe)
  }

  define ping_all {
    valueToPrettyString@StringUtils( collection )( t )
    println@Console("collection: " + t + ", len: " + #collection)()
    spawn(i over #collection) in pongs {
      if(is_defined(collection[i])) {
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

          Executor.location = collection[i].commsLocation
          if(p.debug) {
            println@Console("Pinging singleton " + Executor.location)()
          }
          pongs[i] = -1
          ping@Executor(0)(pongs)
        }
      }
    }
    if(p.debug) {
      valueToPrettyString@StringUtils( pongs )( t )
      println@Console( "Pongs: " + t )()
    }
    for( i = 0, i < #pongs, i++ ) {
      if(pongs[i] != 0) {
        println@Console("Ping didn't return 0, removing executor: #" + i + " (type: " + collection[i].type + ", location: " + collection[i].invokeLocation + ")")()
        exe -> collection[i]
        undef(exe)
      }
    }
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
      println@Console("Starting expected executor: " + t)()
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
    spwn@Spawner(spwnInfo)(spwn_res)
    if(spwn_res.error) {
      println@Console("Error while spawning a expected service:\n" + spwn_res.data)()
    } else {
      global.executorIdByName[name] = spwn_res.id
    }
  }

  define kill_executor {
    if(p.verbose) {
      valueToPrettyString@StringUtils( exe )( t )
      println@Console("Killing executor: " + t)()
    }
    // send the stop message to the executor
    Executor.location = exe.commsLocation
    stop@Executor()()

    // kill and remove the container
    kill@Spawner(exe.id)(res)
    if(spwn_res.error) {
      println@Console("Error while killing a service:\n" + spwn_res.data)()
    }
    undef(exe)
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

    // load balancing state
    global.nextRunner = 0
    global.nextSingleton = 0

    // provisioning state
    global.calls = 0

    println@Console("Listening on " + p.provisionerLocation)()
  }

  main {
    [schedulerCallback(request)] {
      if(request.groupName == "ping") {
        collection -> global.runners
        if(#collection > 0) {
          ping_all
        }

        foreach(fn : global.singletons) {
          collection -> global.singletons.(fn)
          if(#collection > 0) {
            ping_all
          }
        }
      } else if(request.groupName == "provision") {
        if(p.verbose) {
          valueToPrettyString@StringUtils( global.callsByFunction )( t )
          println@Console("PROVISIONING\nTotal calls: " + global.calls + "\nCalls by function name: " + t)()
        }

        // compute how many (if any) singletons we should have per function
        foreach(fn : global.callsByFunction) {
          if(global.callsByFunction.(fn) > p.callsForPromotion) {
            singletons.(fn) = global.callsByFunction.(fn) / p.callsPerSingleton
            // decrement the number of calls by the amout that are going to be
            // served by singletons from now on.
            global.calls = global.calls - singletons.(fn) * p.callsPerSingleton
          } else {
            singletons.(fn) = 0
          }
        }

        // diff between the currently running singletons (global.singletons)
        // and the expected scheduling plan (local singletons)
        // first, create an hash map of all the function's names that have an
        // active singleton or have been called in the current time frame
        foreach(fn : singletons) {
          fns.(fn) = 0
        }
        foreach(fn : global.singletons) {
          fns.(fn) = 0
        }
        // compute the number of expected runners
        runners = global.calls / p.callsPerRunner
        // don't go below the minimum number of runners
        if(runners < p.minRunners) {
          runners = p.minRunners
        }

        if(p.verbose) {
          valueToPrettyString@StringUtils( singletons )( t )
          println@Console("PROVISION PLAN\nRunners: " + runners + "\nSingletons: " + t)()
        }
        
        // compare and start/stop singletons where needed
        foreach(fn : fns) {
          expected = 0
          if(is_defined(singletons.(fn))) {
            expected = singletons.(fn)
          }
          old = #global.singletons.(fn)

          if(expected > old) {
            n = expected - old

            // start n expected singletons
            for(i = 0, i < n, i++) {
              image = JFN_SINGLETON_IMAGE
              function = fn
              spawn_executor
            }
          } else if(expected < old) {
            // stop n old singletons
            for(i = old, i > expected, i--) {
              exe -> global.singletons.(fn)[i]
              kill_executor
            }
          }
        }

        // compare and start/stop runners where needed
        expected = runners
        old = #global.runners
        if(expected > old) {
          n = expected - old

          // start n expected runners
          for(i = 0, i < n, i++) {
            image = JFN_RUNNER_IMAGE
            spawn_executor
          }
        } else if(expected < old) {
          // stop n old runners
          for(i = old - 1, i >= expected, i--) {
            exe -> global.runners[i]
            kill_executor
          }
        }

        // clear data for the next provision step
        global.calls = 0
        foreach(fn : global.callsByFunction) {
          undef(global.callsByFunction.(fn))
        }
      }
    }

    [register( request )( ) {
      request.id = global.executorIdByName[request.name]
      undef(global.executorIdByName[request.name])

      valueToPrettyString@StringUtils( request )( t )
      println@Console("Registered executor #" + i + ": " + t)()

      // register the executor in its appropriate tracking structure
      if(request.type == "runner") {
        i = #global.runners
        println@Console("new pos: " + i)()
        global.runners[i] << request
      } else if(request.type == "singleton") {
        coll -> global.singletons.(request.function)
        coll[#coll] << request
      }
    }]

    [executor( request )( response ) {
      found = false
      singletons -> global.singletons.(request.function)
      nextSingleton -> global.nextSingleton.(request.function)
      if(is_defined(singletons) && #singletons > 0) {
        if(!is_defined(nextSingleton) || nextSingleton >= #singletons) {
          nextSingleton = 0
        }

        i = nextSingleton++
        if(is_defined(singletons[i])) {
          found = true
          response << singletons[i]
        }
      }

      if(is_defined(global.runners) && #global.runners > 0) {
        if(global.nextRunner >= #global.runners) {
          global.nextRunner = 0
        }
        i = global.nextRunner++
        if(is_defined(global.runners[i])) {
          found = true
          response << global.runners[i]
        }
      }

      // TODO: does this try all the available options?

      if(!found) {
        println@Console("No singleton or runner to execute the job onto!")()
        response.type = "error"
        response.location = "error"
      } else {
        count_call

        response.location = response.invokeLocation
        undef(response.invokeLocation)
        undef(response.commsLocation)
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
