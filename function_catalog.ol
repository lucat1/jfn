from console import Console
from file import File
from runtime import Runtime
from .checksum import Checksum

type FunctionCatalogParams {
  functionCatalogLocation: string
  verbose: bool
}

type FunctionCatalogRequest { name: string }
type FunctionCatalogPutRequest {
  name: string
  code: string
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

service FunctionCatalog(p : FunctionCatalogParams) {
  execution: concurrent
  embed Console as Console
  embed Runtime as Runtime
  embed File as File
  embed Checksum as Checksum

  inputPort FunctionCatalogInput {
    location: p.functionCatalogLocation
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  init {
    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)
    getServiceDirectory@File()(root)
    println@Console("Listening on " + p.functionCatalogLocation)()
  }

  main {
    [hash( request )( response ) {
      derive_filename
      exists@File(filename)(exists)
      if(p.verbose) {
        println@Console("Looking for \"" + request.name + "\" in " + filename)()
      }
      if(!exists) {
        response = ""
      } else {
        readFile@File({
          .filename = filename
        })(code)
        sha256@Checksum(code)(response)
      }
    }]
    [get( request )( response ) {
      derive_filename
      exists@File(filename)(exists)
      if(p.verbose) {
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
        })(code)
        with(response) {
          .error = false
          .data = code
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
          content = request.code
        })()
        response.error = false
      }
    }]
  }
}
