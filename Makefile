COFFEE=coffee

build: clean
	@$(COFFEE) -co lib src

clean:
	@rm -rf lib
