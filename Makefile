all: checksum

checksum: Checksum.java
	javac -cp "$$HOME/.local/jolie/jolie-dist/jolie.jar" Checksum.java
	mkdir jfn
	mv Checksum.class jfn
	jar cvf jfn.jar jfn/Checksum.class
	mv jfn/Checksum.class .
	rm -d jfn
	mv jfn.jar $$HOME/.local/jolie/jolie-dist/lib
