# KrakenDev Game Engine
A safe, intuitive, open-source game engine designed for CC: Tweaked

## Features

### Shell
Includes a basic shell designed specifically to interface with the API.

Included in the startup function or can be run simply:
```
krakendev/shell
```

In the kdshell, you can see the API commands using:
```
kd help [page]
```

### Running A Project

In the kdshell, you can run a project directory using,
```kd run <project directory>```

or run a project cart (a compressed file of game data which gets loaded into temp to be played and then cleared after) using ```kd crun <project cart directory>```

You can also interface the function directly from the API without the shell:
```lua
local kdev = require('krakendev/api')

kdev.run("project") -- Running a project directory directly

kdev.unpackRun("disk") -- Running a project cart
```

<sub>Note: Keep in mind, these carts can be encrypted with a password using the RCC modpack module, the cryptographic accelerator. Without the accelerator, you can't open them.</sub>
