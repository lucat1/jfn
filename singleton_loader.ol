from console import Console
from runtime import Runtime
from string_utils import StringUtils

interface SingletonLoaderAPI {
  RequestResponse:
    noop( void )( void ),
}

service SingletonLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local"
    interfaces: SingletonLoaderAPI
  }

  init {
    params = {}
    getenv@Runtime( "SINGLETON_NAME" )( params.singletonName )
    getenv@Runtime( "SINGLETON_LOCATION" )( params.singletonLocation )
    getenv@Runtime( "ADVERTISE_LOCATION" )( params.advertiseLocation )
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( params.functionCatalogLocation )
    getenv@Runtime( "PROVISIONER_LOCATION" )( params.provisionerLocation )
    getenv@Runtime( "FUNCTION" )( params.function )
    getenv@Runtime( "VERBOSE" )( params.verbose )
    params.verbose = bool(params.verbose)
    getenv@Runtime( "DEBUG" )( params.debug )
    params.debug = bool(params.debug)

    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the singleton with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "singleton.ol"
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
