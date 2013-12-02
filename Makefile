COFFEE=coffee

build:
	$(COFFEE) -co lib src

clean:
	rm -rf lib
