 # Storytime!

 _storytime_ is a simple script to extract markdown from comments in source code and turn it back into normal markdown, 
 while moving the source code into intermediate code blocks, effectively turning the text inside out. A kind of literate programming light if you want to.
 The script is written in [Lua](https://www.lua.org/), mostly because Lua is self-contained enough to bundle the script _and_ the sources to the Lua interpreter (or binaries)
 with the project sources, making it an easy tooling choice for text transformations like this. 
 ## Usage :
 There not much to know. The command line is:

 `lua storytime.lua [--language <language>] [--prefix <comment prefix>] <input file>`

 Output goes to stdout and there is a [Makefile](Makefile.md) which shows how to use it.  
 
 ## Implementation
 So what we want to do is this: Read a file, find the comment files we want to lift to the text level and write them out, while putting source lines into source fences.

 We start by defining the language of the code we would like to pass through `storytime`. Since we don't try to auto detect the language, we need a default.
```lua startFrom=18
local language="lua"
```
 Let's say, that these language names are the ones [Linguist](https://github.com/github/linguist/blob/master/lib/linguist/languages.yml) uses, because Linguist is the syntax highlighter of github and we put the value of `language` into the code fences we generate. 

 Next, we prepare a list of regexprs for line comments in the language, that shall contain wrapped markdown and a variable that is later set to the prefix for the user language. I like the arrow style for markdown comments, so the defaults are exactly that.
```lua startFrom=22
local prefix_map={
  lua="%-%->[%s\n]",
  sql="%-%->[%s\n]",
  cpp="//%->[%s\n]",
  shell="#%-%->[%s\n]",
  makefile="[#]%-%->[%s\n]"
} 
local story_prefix=nil
```
 This can be changed later with the --prefix command line argument.
 
 Now we define the main processing function. `unwrap_file` simply reads all lines from `in` and passes them to `out`, after rewriting the lines. We are not specific about what `input` actually is, we just treat it as an iterator.
 > There is a reason why `output` comes fist, which is explained later.  
```lua startFrom=34
function unwrap_file(output, input)
  local last="story" --> type of the last line ("code" or "story")
  local lineno=0 --> count the current line number, we want these in the code fences.
  for l in input do  
    l=l.."\n" --> EOL is removed from the lines() iterator, but we'd like to have it. 
    lineno=lineno+1 --> an we'd like the current line number.    
    local s,e=l:find(story_prefix)
```
 There are two cases: Either the line simply starts with a story prefix.
 In that case we check if we need to close a preceding code block and 
 then we emit the line without the prefix.
```lua startFrom=44
    if s==1 then --> line starts with story comment
      if last=="code" then --> close preceding code block
        output("```\n")
        last="story"
      end
      output(l:sub(e)) --> remove the prefix and print
```
 Or it's just a line, so we need to check, if we have to open a code block
```lua startFrom=51
    else
      --> so, it's a code line 
      if last=="story" then 
        --> Open code block if necessary.
        output(string.format('```%s startFrom=%d\n', language, lineno)) --> How do I do line numbers with github? 
        last="code"
      end
      output(l) --> write the code line 
    end
```
 We're at end of the file. If we are still in "code" mode, then there is a code 
 block open that we need to close.
```lua startFrom=62
  end
  if last=="code" then --> close preceeding code block
    output("```\n")
    last="story"
  end
end 
```

 ### Push-Pull mismatch.
 `unwrap_file` processes it's data as a **push-pull** filter: it **pulls** data from `input` (an iterator) an **pushes** the result to `output` (a function). This is not ideal, because it makes it hard to compose filters. If we treat `output` as the next stage of the processing pipeline, then it would get it's data pushed in. It would be a **push-push** filter. Since a push-push filter is called repeatedly, it can not held its state in the invocation frame and needs to handle resuming execution. 
 That's error prone and it also blurrs the intent of the code, because we'll end up with boilerplate code to adapt the function to its usage. But in Lua, there is a simple solution to that problem: Any pull-push function can be converter into a **pull-pull** function (a function taking an iterator and returning an iterator) using continuations. Here's the generic function for this conversion: 
```lua startFrom=72

function generator(f,...) 
 local args={...}
 local co=coroutine.create(
 	function()
 		f(coroutine.yield,unpack(args))
 	end)
 return function () 
  local code, res=coroutine.resume(co)
  return res
 end
end
```
 we can now use generator like this: 
 ~~~
 for line in generator(unwrap_file, input) do
  print(line)
 end
 ~~~
 and compose passes like:
 ~~~
 pass1=generator(pass1_function,input)
 composed=generator(pass2_function, pass1)
 ~~~

 `generator` returns a new function from f which is arranged to pass coroutine.yield as the output function of f, `...` are the _other_ arguments of f and since passing variadic arguments around is limited to the trailing parameters of a function, we need to make sure, that the `output` function is the first one. Ok, that's not so ovious, but you can read about all this in the [relevant](https://www.lua.org/pil/9.3.html) [sections](https://www.lua.org/pil/5.2.html) of the Lua manual.
 
 That's the processing part. Now we parse the command line and call `unwrap_file` accordingly.
 
```lua startFrom=100
local fname=nil
local i=1
while i<=#arg do 
  if arg[i]=="--prefix" then
    story_prefix = (i+1<=#arg) and arg[i+1] or error("missing argument to --prefix")
```
 > The above is the Lua equivalent of a ternary operator. In C/C++ this would be `(i+1<argc)?argv[i]:perror("arg")` or something like that.
```lua startFrom=106
    i=i+2
  elseif arg[i]=="--language" then 
    language=(i+1<=#arg) and arg[i+1] or error("missing argument to --language")
    i=i+2
  else 
    fname = not fname and arg[i] or error("input file already set to "..fname)
    i=i+1
  end
end
```
 Now process the arguments: Set the story_prefix if not given and set up the input file.
```lua startFrom=116
if not story_prefix then 
  story_prefix=prefix_map[language] or error("unknown language "..language..". Please set a --prefix")
end

local infile=io.input()
if fname then
  infile=assert(io.open(fname,"r"))
end
```
 We now rocess the file. This could be done by calling `unwrap_file(io.write, infile:lines())` directly, but we want to be prepared to add passes to in- and output, so we use the `generator` function to turn `unwrap_file` into a function returning an iterator: 
```lua startFrom=125
local proc=generator(unwrap_file,infile:lines())
for line in proc do
 io.write(line)
end
```
 That's it. We close the input file, because we are nice.
```lua startFrom=130
infile:close() --> Closing stdin is OK.
```
 ~ _Fin_ ~ 
