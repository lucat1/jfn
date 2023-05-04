from console import Console
from scheduler import Scheduler
from file import File
from runtime import Runtime
from .loader import LoaderAPI
from .function import FunctionAPI
from .provisioner import ProvisionerAPI
from .function_catalog import FunctionCatalogAPI
from .executor import ExecutorAPI
from .scheduler import SchedulerCallBackInterface

type SingletonParams {
  singletonName: string
  singletonLocation: string
  advertiseLocation: string
  functionCatalogLocation: string
  provisionerLocation: string
  function: string
  verbose: bool
  debug: bool
}

type RunRequest {
  data?: undefined
}

type RunResponse {
  error: bool
  data?: undefined
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
  
  outputPort Parent {
    location: "local://loader"
    protocol: sodep
    interfaces: LoaderAPI
  }

  outputPort FunctionCatalog {
    location: p.functionCatalogLocation
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  outputPort Embedded {
    protocol: sodep
    interfaces: FunctionAPI
  }

  outputPort Provisioner {
    location: p.provisionerLocation
    protocol: sodep
    interfaces: ProvisionerAPI
  }

  inputPort SingletonInput {
    location: p.singletonLocation
    protocol: sodep
    interfaces: ExecutorAPI
    redirects:
      Fn => Embedded
  }

  inputPort SchedulerCallBack {
    location: local
    interfaces: SchedulerCallBackInterface
  }

  init {
    enableTimestamp@Console(true)()

    println@Console("Downloading function: " + p.function)()
    get@FunctionCatalog({
      name = p.function
    })(code)
    if(code.error) {
      println@Console("Could not find function \"" + p.function + "\" in the catalog. Error: " + code.error)()
      stop@Parent()()
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
      name = p.singletonName
      commsLocation = p.advertiseLocation
      invokeLocation = p.advertiseLocation + "/!/Fn"
      function = p.function
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
    println@Console("Listening on " + p.singletonLocation + " (advertise: " + p.advertiseLocation + ")")()
  }

  main {
    [ping( request )( response ) {
      response = request
      global.lastPing = true
    }]

    [schedulerCallback(request)] {
      if(!global.lastPing) {
        println@Console("Didn't receive a ping for more than 10 seconds, assuming the provisioner is dead. Quitting")()
        stop@Parent()()
      }
      global.lastPing = false
    }

    [stop()() {
      println@Console("Stop signal has been received. Quitting...")()
      stop@Parent()()
    }]
  }
}
