from console import Console
from file import File

type FunctionCatalogRunner {
  location: string

  verbose: bool
}

type FunctionCatalogGetRequest  { name: string }
type FunctionCatalogPutRequest  {
  name: string
  content: string
}
type FunctionCatalogResult {
  error: bool
  data: string
}

interface FunctionCatalogAPI {
  RequestResponse:
    get( FunctionCatalogGetRequest )( FunctionCatalogResult ),
    put( FunctionCatalogPutRequest )( FunctionCatalogResult )
}

constants {
  FUNCTIONS_PATH = "functions"
}

define derive_filename {
  filename = root + sep + FUNCTIONS_PATH + sep + request.name + ".ol"
}

service FunctionCatalog( p : FunctionCatalogRunner ) {
  execution: concurrent
  embed Console as Console
  embed File as File

  inputPort FunctionCatalogInput {
    location: p.location
    protocol: sodep
    interfaces: FunctionCatalogAPI
  }

  init {
    enableTimestamp@Console(true)()
    getFileSeparator@File()(sep)
    getServiceDirectory@File()(root)
  }

  main {
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
