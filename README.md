# G'DAY

This is a template I made for my [mentorship program](https://learn.randy.gg/?src=template-starter) to make getting started with no-engine game dev a lot easier.

I figured I'd make this free and open, as a nice sample of what the program has to offer.

My whole goal is to create resources and content that makes no-engine game dev more fun and less of a slog for people. That way we can all focus on writing gameplay code and doing game design, instead of getting stuck in tech no-mans-land and having to write a whole bunch of boring boilerplate just to get a triangle showing up on screen.

**GAMEPLAY O'CLOCK BAYBEEEE**

This is practically my entire core layer I use for game development. I used the concepts in here to make these games:
- https://store.steampowered.com/app/2571560/ARCANA/
- https://store.steampowered.com/app/3309460/Demon_Knives/
- https://store.steampowered.com/app/3433610/Terrafactor/

I've been tweaking and iterating on these ideas for the last 5 years of learning how to program a game without an engine.

These days, I've landed on Odin as the language, and Sokol as the core platform & rendering abstractions. With a bunch of concepts and helpers added on top to make life easier.

## About
All the files marked with `core_` are designed to be updated, I'll push updates as needed.

See the FAQ segment at the bottom for more info.

### What this is great for:
- arcade games & game jams
- a small to medium size singleplayer Steam game

## Building

In general, development is way easier on windows since there's more tooling and it's what [~96%](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam) of Steam customers use, so it leads to less bugs for the majority of people because you're daily-driving the same OS and can iron out all the platform-specific kinks.

I get that some people prefer to be linux or mac chads though. It's relatively simple to get working natively since Sokol is great, so I'm beginning to add in support for both.

If you're planning on doing game-dev full time though and targeting Steam, I'd highly recommend getting some kind of windows environment setup. There's just no way around it right now unfortunately. Game dev is easier on windows despite the OS itself getting worse and worse each year and making me cry at HOW FUCKING DOGSHIT IT FEELS TO USE alsk;djfkl;asd fjl;ksadjfk sadfkjl;sdaflkj

... sorry about that. Here's the build instructions.

### Windows
1. [install Odin](https://odin-lang.org/docs/install/)
2. call `build.bat`
3. check `build/windows_debug`
4. see instructions below for running

### Mac
1. [install Odin](https://odin-lang.org/docs/install/)
2. make the folders for `build/mac_debug` (currently a bug)
3. call `build_mac.sh`
4. check `build/mac_debug`
5. see instructions below for running

### Linux
todo

### Web
coming soon™️

## Running
Needs to run from the root directory since it's accessing /res.

I'd recommend setting up the [RAD Debugger](https://github.com/EpicGamesExt/raddebugger) (windows-only) for a great running & debugging experience. I always launch my game directly from there so it's easier to catch bugs on the fly.

## FAQ
### How do I use this to make a game?
I'm focusing my efforts on making course content for this in [my paid program](https://learn.randy.gg/?src=template-starter) with a bunch of examples of how to use it.

If you're on a budget, here's some free alternatives:
- I do [live streams](https://www.youtube.com/@randyprime2) of development while using this template
- My public [Discord community](https://discord.gg/JXhxeQW4ca) (you can ask as many questions in there as you'd like and get help from the community, I just can't guarentee the quality of the answers)

### Why is this a template (not a library)?
Game development is complicated.

I think trying to abstract everything away behind a library is a mistake. It makes things look and feel "clean" but sacrifices the capability, limiting what you're able to do and forcing you to use hacky workarounds instead of just doing the simplest and most direct thing possible to solve the problem.

I tried my best to seperate the core layer from the game so it's easy to upgrade later on, but there's what I believe to be an unavoidable tangling of some ideas in a lot of places.

### Why Odin?
Compared to C, it's a lot more fun to work in. Less overall typing, more safety by default, and great quality of life. Happy programming = more gameplay.

Compared to Jai, it has more users and is public (Jai is still in a closed beta). So that means more stability and a better ecosystem around packages, tooling etc, (because more people use it).

### Why Sokol?
Compared to Raylib:

I initially tried using Raylib for this template, it was going well... Right up until the point where I needed to do a specific shader effect on a single sprite. At that point, I would have had to do something hacky to single out the vertices in the shader, or just use the lower level RLGL to basically just write a custom renderer so I could modify the verts and have more power with the shaders.

... at that point, Sokol just becomes a way better option because it lets you do native targets like DirectX11 and Metal with a simple abstraction.
