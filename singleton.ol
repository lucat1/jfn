from console import Console
from scheduler import Scheduler
from file import File
from runtime import Runtime
from .function import FunctionAPI
from .provisioner import ProvisionerAPI
from .function_catalog import FunctionCatalogAPI
from .scheduler import SchedulerCallBackInterface

type SingletonParams {
  location: string
}

type RunRequest {
  data?: undefined
}

type RunResponse {
  error: bool
  data?: undefined
}

interface SingletonAPI {
  RequestResponse:
    ping( int )( int ),
}

constants {
  SINGLETON_FUNCTION_PATH = "/tmp/fn.ol",
}

service Singleton( p : SingletonParams) {
  execution: concurrent
  embed Console as Console
  embed Scheduler as Scheduler
  embed File as File
  embed Runtime as Runtime

  outputPort FunctionCatalog {
    location: global.functionCatalog
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

  inputPort SingletonInput {
    location: p.location
    protocol: sodep
    interfaces: SingletonAPI
    redirects:
      Fn => Embedded
  }

  inputPort SchedulerCallBack {
    location: local
    interfaces: SchedulerCallBackInterface
  }

  init {
    getenv@Runtime( "SINGLETON_LOCATION" )( p.location )
    getenv@Runtime( "PROVISIONER_LOCATION" )( Provisioner.location )
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( FunctionCatalog.location )
    getenv@Runtime( "FUNCTION" )( global.function )

    enableTimestamp@Console(true)()

    println@Console("Downloading function: " + global.function)()
    get@FunctionCatalog({
      name = global.function
    })(code)
    if(code.error) {
      println@Console("Could not find function \"" + global.function + "\" in the catalog. Error: " + code.error)()
      exit
    }
    writeFile@File({
      filename = SINGLETON_FUNCTION_PATH
      format = "text"
      content = code.data
    })()

    println@Console("Embedding " + SINGLETON_FUNCTION_PATH)()
    loadEmbeddedService@Runtime({
      filepath = SINGLETON_FUNCTION_PATH
      type = "jolie"
    })(loc)
    Embedded.location = loc

    println@Console("Attaching to provisioner at " + Provisioner.location)()
    register@Provisioner({
      type = "singleton"
      ping = p.location
      location = p.location + "/!/Fn"
      function = global.function
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
  }
}
