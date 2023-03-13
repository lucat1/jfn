from console import Console
from scheduler import Scheduler
from .jocker import InterfaceAPI
from .scheduler import SchedulerCallBackInterface

type ExecutorRequest { function: string }
type ExecutorResponse {
  type: string
  location: string
}

type ProvisionerParams {
  location: string

  verbose: bool
}

interface ProvisionerAPI {
  RequestResponse:
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
  }

  main {
    [schedulerCallback(_)] {
    }

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
