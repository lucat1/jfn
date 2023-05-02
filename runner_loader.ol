from console import Console
from runtime import Runtime
from string_utils import StringUtils

interface RunnerLoaderAPI {
  RequestResponse:
    noop( void )( void ),
}

service RunnerLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local"
    interfaces: RunnerLoaderAPI
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

    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the runner with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "runner.ol"
      type = "jolie"
      params << params
    })(_)
  }
  main {
    [noop(req)(res) {
      req = res
    }]
  }
}
