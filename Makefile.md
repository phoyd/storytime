 # Makefile
 This is a sample Makefile, which produces the markdown for the 
 sources in this project. Here are the files we want to build.
```makefile
OUTPUT=README.md Makefile.md

```
 The default target builds everything.
```makefile
all: $(OUTPUT)

```
 Build the markdown for storytime.lua itself. This goes to `README.md` and it's kind of stupid right now, because we essentally duplicate the source file here. This should be generated on fly. 
```makefile
README.md: storytime.lua
	lua storytime.lua storytime.lua >README.md

```
 And build the story for this Makefile as well. 
```makefile
Makefile.md: Makefile
	lua storytime.lua --language makefile Makefile >Makefile.md

```
 We need a `clean` target.
```makefile
clean: 
	rm $(OUTPUT)
	

```
