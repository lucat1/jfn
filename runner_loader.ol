from console import Console
from time import Time
from runtime import Runtime
from string_utils import StringUtils
from .loader import LoaderAPI

service RunnerLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed Time as Time
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local://loader"
    interfaces: LoaderAPI
  }

  init {
    params = {}
    getenv@Runtime( "RUNNER_NAME" )( params.runnerName )
    getenv@Runtime( "RUNNER_LOCATION" )( params.runnerLocation )
    getenv@Runtime( "ADVERTISE_LOCATION" )( params.advertiseLocation )
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( params.functionCatalogLocation )
    getenv@Runtime( "PROVISIONER_LOCATION" )( params.provisionerLocation )
    getenv@Runtime( "VERBOSE" )( params.verbose )
    params.verbose = bool(params.verbose)
    getenv@Runtime( "DEBUG" )( params.debug )
    params.debug = bool(params.debug)

    sleep@Time(1000)()
    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the runner with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "runner.ol"
      type = "jolie"
      params << params
    })(_)
  }
  main {
    [stop(req)(res) {
      exit
    }]
  }
}
