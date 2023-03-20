all: checksum

checksum: lib Checksum.java
	javac -cp "$$HOME/.local/jolie/jolie-dist/jolie.jar" Checksum.java
	mkdir jfn
	mv Checksum.class jfn
	jar cvf checksum.jar jfn/Checksum.class
	mv jfn/Checksum.class .
	rm -d jfn
	mv checksum.jar lib/checksum.jar

lib:
	mkdir lib
