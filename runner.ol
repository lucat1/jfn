from console import Console
from scheduler import Scheduler
from string_utils import StringUtils
from file import File
from runtime import Runtime
from .function import FunctionAPI
from .provisioner import ProvisionerAPI
from .function_catalog import FunctionCatalogAPI
from .scheduler import SchedulerCallBackInterface

type RunRequest {
  name: string
  data?: undefined
}

type RunResponse {
  error: bool
  data?: undefined
}

interface RunnerAPI {
  RequestResponse:
    ping( int )( int ),
    run( RunRequest )( RunResponse )
}

constants {
  RUNNER_FUNCTIONS_PATH = "/tmp/jfn",
}

define derive_filename {
  filename = RUNNER_FUNCTIONS_PATH + sep + request.name + "-" + hash + ".ol"
}

service Runner {
  execution: concurrent
  embed Console as Console
  embed Scheduler as Scheduler
  embed File as File
  embed Runtime as Runtime
  embed StringUtils as StringUtils

  outputPort FunctionCatalog {
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  outputPort Embedded {
    protocol: sodep
    interfaces: FunctionAPI
  }

  outputPort Provisioner {
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  inputPort RunnerInput {
    location: "socket://0.0.0.0:6004"
    protocol: sodep
    interfaces: RunnerAPI
  }

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  init {
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( FunctionCatalog.location )
    getenv@Runtime( "PROVISIONER_LOCATION" )( Provisioner.location )
    getenv@Runtime( "RUNNER_LOCATION" )( RunnerInput.location )
    getenv@Runtime( "VERBOSE" )( global.verbose )
    getenv@Runtime( "DEBUG" )( global.debug )

    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)

    exists@File(RUNNER_FUNCTIONS_PATH)(exists)
    if(!exists) {
      mkdir@File(RUNNER_FUNCTIONS_PATH)()
    }

    println@Console("Attaching to provisioner at " + Provisioner.location)()
    register@Provisioner({
      type = "runner"
      ping = RunnerInput.location
      location = RunnerInput.location
    })()

    global.lastPing = true
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
    println@Console("Listening on " + RunnerInput.location)()
  }

  main {
    [ping( request )( response ) {
      response = request
      if(global.debug) {
        println@Console("Received a ping, sending pong")()
      }
      global.lastPing = true
    }]

    [schedulerCallback(request)] {
      if(!global.lastPing) {
        println@Console("Didn't receive a ping for more than 10 seconds, assuming the provisioner is dead. Quitting")()
        exit
      }
      global.lastPing = false
    }

    [run( request )( response ) {
      if(global.debug) {
        valueToPrettyString@StringUtils( request )( t )
        println@Console( "Calling: " + t )()
      }
      scope(load_service) {
        install(
          IOException => {
            response.error = true
            response.data = "Could not contact the function catalog (to check the hash)"
          }
        )
        hash@FunctionCatalog({
          name = request.name
        })(hash)
      }
      derive_filename
      exists@File(filename)(exists)
      if(!exists) {
        scope(load_service) {
          install(
            IOException => {
              response.error = true
              response.data = "Could not contact the function catalog"
            }
          )
          get@FunctionCatalog({
            name = request.name
          })(response)
        }
        if(!response.error) {
          content << response.data
          undef(response.data)
          scope(write_function) {
            install(
              FileNotFound => {
                response.error = true
                response.data = "Could not find function file or its parent directories"
              },
              IOException => {
                response.error = true
                response.data = "Could not write to the function file"
              }
            )
            writeFile@File({
              filename = filename
              format = "text"
              content = content
            })()
            if(global.verbose) {
              println@Console("Wrote function to " + filename)()
            }
          }
        }
      }
      if(!response.error) {
        scope(load_service) {
          install(
            RuntimeException => {
              response.error = true
              response.data = "Could not load function service: " + load_service.RuntimeException
            }
          )
          loadEmbeddedService@Runtime({
            filepath = filename
            type = "jolie"
          })(loc)
        }
        invoke_data << request
        undef(invoke_data.name)
        scope(call_service) {
          install(
            InvocationFault => {
              response.error = true
              response.data = "Error while calling the function: " + call_service.InvocationFault.name
            }
          )
          Embedded.location = loc
          fn@Embedded(invoke_data)(output)
          response.data << output.data
          response.error = false
          if(global.debug) {
            println@Console("Run successful")()
          }
        }
      }
    }]
  }
}
