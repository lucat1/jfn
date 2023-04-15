from console import Console
from runtime import Runtime
from string_utils import StringUtils

interface FunctionCatalogLoaderAPI {
  RequestResponse:
    noop( void )( void ),
}

service FunctionCatalogLoader {
  execution: sequential
  embed Runtime as Runtime
  embed Console as Console
  embed StringUtils as StringUtils

  inputPort Local {
    location: "local"
    interfaces: FunctionCatalogLoaderAPI
  }

  init {
    params = {}
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( params.functionCatalogLocation )
    getenv@Runtime( "VERBOSE" )( params.verbose )
    params.verbose = bool(params.verbose)

    valueToPrettyString@StringUtils( params )( t )
    println@Console( "Loading the function catalog with params: " + t )()

    loadEmbeddedService@Runtime({
      filepath = "function_catalog.ol"
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
