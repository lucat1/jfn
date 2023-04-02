from console import Console
from file import File
from runtime import Runtime
from .checksum import Checksum

type FunctionCatalogRequest { name: string }
type FunctionCatalogPutRequest {
  name: string
  content: string
}
type FunctionCatalogResult {
  error: bool
  data: string
}

interface FunctionCatalogAPI {
  RequestResponse:
    hash( FunctionCatalogRequest )( string ),
    get( FunctionCatalogRequest )( FunctionCatalogResult ),
    put( FunctionCatalogPutRequest )( FunctionCatalogResult )
}

constants {
  FUNCTIONS_PATH = "functions"
}

define derive_filename {
  filename = root + sep + FUNCTIONS_PATH + sep + request.name + ".ol"
}

service FunctionCatalog {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed File as File
  embed Checksum as Checksum

  inputPort FunctionCatalogInput {
    location: "socket://0.0.0.0:7000"
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  init {
    getenv@Runtime( "FUNCTION_CATALOG_LOCATION" )( FunctionCatalogInput.location )
    getenv@Runtime( "VERBOSE" )( global.verbose )

    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)
    getServiceDirectory@File()(root)
    println@Console("Listening on " + FunctionCatalogInput.location)()
  }

  main {
    [hash( request )( response ) {
      derive_filename
      exists@File(filename)(exists)
      if(global.verbose) {
        println@Console("Looking for \"" + request.name + "\" in " + filename)()
      }
      if(!exists) {
        response = ""
      } else {
        readFile@File({
          .filename = filename
        })(content)
        sha256@Checksum(content)(response)
      }
    }]
    [get( request )( response ) {
      derive_filename
      exists@File(filename)(exists)
      if(global.verbose) {
        println@Console("Looking for \"" + request.name + "\" in " + filename)()
      }
      if(!exists) {
        with(response) {
          .error = true
          .data = "Function does not exist"
        }
      } else {
        readFile@File({
          .filename = filename
        })(content)
        with(response) {
          .error = false
          .data = content
        }
      }
    }]

    [put( request )( response ) {
      derive_filename
      exists@File(filename)(exists)
      if(!exists) {
        response = {
          .error = true
          .data = "Function already exists"
        }
      } else {
        writeFile@File({
          filename = filename
          format = "text"
          content = request.content
        })()
        response.error = false
      }
    }]
  }
}
