.EXPORT_ALL_VARIABLES:

PROVISIONER_LOCATION = socket://localhost:6001
FUNCTION_CATALOG_LOCATION = socket://localhost:6002
RUNNER_LOCATION = socket://localhost:6003
GATEWAY_LOCATION = socket://localhost:6004
VERBOSE = true

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
	jolie provisioner.ol

gateway:
	jolie provisioner.ol
