from console import Console
from scheduler import Scheduler
from string_utils import StringUtils
from file import File
from runtime import Runtime
from .function import FunctionAPI
from .provisioner import ProvisionerAPI
from .function_catalog import FunctionCatalogAPI
from .scheduler import SchedulerCallBackInterface

type RunnerParams {
  location: string
  provisioner: string
  functionCatalog: string

  verbose: bool
}

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

service Runner( p : RunnerParams ) {
  execution: concurrent
  embed Console as Console
  embed Scheduler as Scheduler
  embed File as File
  embed Runtime as Runtime
  embed StringUtils as StringUtils

  outputPort FunctionCatalog {
    location: p.functionCatalog
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  outputPort Embedded {
    protocol: sodep
    interfaces: FunctionAPI
  }

  outputPort Provisioner {
    location: p.provisioner
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  inputPort RunnerInput {
    location: p.location
    protocol: sodep
    interfaces: RunnerAPI
  }

  inputPort SchedulerCallBack {
    location: "local"
    interfaces: SchedulerCallBackInterface
  }

  init {
    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)

    exists@File(RUNNER_FUNCTIONS_PATH)(exists)
    if(!exists) {
      mkdir@File(RUNNER_FUNCTIONS_PATH)()
    }

    println@Console("Attaching to provisioner at " + p.provisioner)()
    register@Provisioner({
      type = "runner"
      ping = p.location
      location = p.location
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
    println@Console("Listening on " + p.location)()
  }

  main {
    [ping( request )( response ) {
      response = request
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
      if(p.verbose) {
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
      // TODO: use the function name + the hash of the contents as a file name
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
            if(p.verbose) {
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
          println@Console("Run successful")()
        }
      }
    }]
  }
}
