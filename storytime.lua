--> # Storytime!
-->
--> _storytime_ is a simple script to extract markdown from comments in source code and turn them back into normal markdown, 
--> while moving the source code into intermediate code blocks, effectively turning the text inside out. A kind of literate programming light if you want to.
--> The script is written in [Lua](https://www.lua.org/), mostly because Lua is self-contained enough to bundle the script _and_ the sources to the Lua interpreter (or binaries)
--> with the project sources, making it an easy tooling choice for text transformations like this. 
--> ## Usage :
--> There not much to know. The command line is:
-->
--> `lua storytime.lua [--language <language>] [--prefix <comment prefix>] <input file>`
-->
--> Output goes to stdout and there is a [Makefile](Makefile.md) which shows hoe to the use it.  
--> 
--> So what we want to do is: Read a file, find the comment files we want to lift to the text level and write them out, while putting source lines into source fences.
-->
--> We start by  defining the language of the code we would like to pass through `storytime`. Since we don't try to autodetect the language, we need a default.
local language="lua"
--> Let's say, that these language names are the ones [Linguist](https://github.com/github/linguist/blob/master/lib/linguist/languages.yml) uses, because Linguist is the syntax highlighter of github and we put the value of `language` into the code fences we generate. 
-->
--> Next, I preparea a list of regexprs for line comments in the language, that shall contain wrapped markdown and a variable that is later set to the prefix for the user language. I like the arrow style for markdown comments, so my defaults are exactly that.
local prefix_map={
  lua="%-%->[%s\n]",
  sql="%-%->[%s\n]",
  cpp="//%->[%s\n]",
  shell="#%-%->[%s\n]",
  makefile="[#]%-%->[%s\n]"
} 
local story_prefix=nil
--> This can be changed later with the --prefix command line argument.
--> 
--> Now we define the main processing function. `unwrap_file` simply reads from `file` and 
--> Read all the files and pass them to a print function. 
function unwrap_file(file, out)
  local last="story" --> type of the last line (code, story)
  local lineno=0 --> count the current line number, we want these in the code fences.
  for l in file:lines() do  
    l=l.."\n" --> EOL is removed from the lines() iterator, but we'd like to have it. 
    lineno=lineno+1 --> an we'd like the current line number.    
    local s,e=l:find(story_prefix)
--> There are two cases: Either the line simply starts with a story prefix.
--> In that case we check if we need to close a preceeding code block and 
--> then we emit the line without the prefix.
    if s==1 then --> line starts with story comment
      if last=="code" then --> close preceeding code block
        out("```\n")
        last="story"
      end
      out(l:sub(e)) --> remove the prefix and print
--> Or it's just a line, so we need to check, if we have to open a code block
    else
      --> so, it's a code line 
      if last=="story" then 
        --> Open code block if neccesary.
        out(string.format('```%s\n', language, lineno)) --> How do I do linenumbers? 
        last="code"
      end
      out(l)
    end
--> We're at end of the file. If we are still in "code" mode, then there is a code 
--> block open that we need to close.
  end
  if last=="code" then --> close preceeding code block
    out("```\n")
    last="story"
  end
end 
-->
--> That's the processing part. Now we parse the command line and call `unwrap_file` accordingly.
--> 
local fname=nil
local i=1
while i<=#arg do 
  if arg[i]=="--prefix" then
    story_prefix = (i+1<=#arg) and arg[i+1] or error("missing argument to --prefix")
    i=i+2
  elseif arg[i]=="--language" then 
    language=(i+1<=#arg) and arg[i+1] or error("missing argument to --language")
    i=i+2
  else 
    fname = not fname and arg[i] or error("input file already set to "..fname)
    i=i+1
  end
end
--> Now process the arguments: Set the story_prefix if not given and set up the input file.
if not story_prefix then 
  story_prefix=prefix_map[language] or error("unknown language "..language..". Please set a --prefix")
end

local infile=io.input()
if fname then
  infile=assert(io.open(fname,"r"))
end
--> And now process the file.
unwrap_file(infile,io.write)
--> That's it. We close the input file, because we are nice and are finished.
infile:close() --> Closing stdin is OK.
--> ~ _Fin_ ~ 
