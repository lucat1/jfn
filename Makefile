RUNNER_LOCATION := socket://localhost:6003
SINGLETON_LOCATION := socket://localhost:6004

.EXPORT_ALL_VARIABLES:

PROVISIONER_LOCATION = socket://localhost:6001
FUNCTION_CATALOG_LOCATION = socket://localhost:6002
GATEWAY_LOCATION = socket://localhost:6005
JOCKER_LOCATION = socket://localhost:8008
DOCKER_NETWORK = jfn
MIN_RUNNERS = 2
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
	jolie function_catalog_loader.ol

provisioner:
	jolie provisioner_loader.ol

runner:
	ADVERTISE_LOCATION=$$RUNNER_LOCATION jolie runner_loader.ol

singleton:
	ADVERTISE_LOCATION=$$RUNNER_LOCATION jolie singleton_loader.ol

gateway:
	jolie gateway_loader.ol

jocker:
	cd jocker-source; jolie dockerAPI.ol
