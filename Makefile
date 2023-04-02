RUNNER_LOCATION := socket://localhost:6003
SINGLETON_LOCATION := socket://localhost:6004

.EXPORT_ALL_VARIABLES:

PROVISIONER_LOCATION = socket://localhost:6001
FUNCTION_CATALOG_LOCATION = socket://localhost:6002
GATEWAY_LOCATION = socket://localhost:6005
VERBOSE = true
DEBUG = false
# For the singleton service
FUNCTION = hello

all: checksum

checksum: lib Checksum.java
	javac -cp "$$HOME/.local/jolie/jolie-dist/jolie.jar" Checksum.java
	mkdir jfn
	mv Checksum.class jfn
	jar cvf checksum.jar jfn/Checksum.class
	mv jfn/Checksum.class .
	rm -d jfn
	mv checksum.jar lib/checksum.jar
	rm Checksum.class

lib:
	mkdir lib

function_catalog:
	jolie function_catalog.ol

provisioner:
	jolie provisioner.ol

runner:
	echo '{"location":"$(RUNNER_LOCATION)"}' > runner.json
	jolie --params runner.json runner.ol

singleton:
	echo '{"location":"$(SINGLETON_LOCATION)"}' > singleton.json
	jolie --params singleton.json singleton.ol

gateway:
	jolie gateway.ol