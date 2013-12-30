---
title: Web Server
main: chadburn
author: Tim
---

I've started work on the Web Server component, and as it's the first software component of the build a [Github repo](https://github.com/Libbum/Chadburn) has also been started.

The soft plan at the moment will be to write a number / status value to a file via the teensy; which will be written in `C`. Implementing the rest of the stack in `C` is madness considering we have no need to keep everything embedded.

This means that we'll need a file watcher connected to a web app for the panel interface (which, with `v1.0` will be a soft panel). I know of a decent watcher in `Ruby` and a couple in `Python`, and considering I hate `Ruby` and _Fenchurch_ already has `Python` (somewhat) installed; it seemed like a good starting point. `Python` also has a decent http server stack so that's a plus; but:

![What is this shit](/images/noidea.jpg)

with `Python`... I could argue that this could all be done in `Haskell` too, but no-one likes and Evangelist.

So next step: I don't want to have to refresh the page on an update of the E.O.T. (i.e. a modification in the status file), nor do I want to poll the server with a tonne of ajax queries every 30 seconds or so. Although the update doesn't really need to come through as a push notification, it's also useless if __coffee__ is called and no notification arrives for 15 minutes...

(Very, very) long story short; I'm going to implement the communication system using [Web Sockets](http://en.wikipedia.org/wiki/WebSocket). They should be fine across most browsers (maybe not if you use IE, but also: if you use IE I don't care about notifying you of anything anyway) as long as it's relatively recent.

At present, a bare bones system using [Tornado](http://www.tornadoweb.org) has me connecting to a local socket server and echoing messages back to a client. Many unique clients are also working - so we can all have the panel open on each of our machines.

I also have the file watcher working - it's using [Watchdog](http://pythonhosted.org/watchdog/) and it shouldn't be too hard to merge the two. I'll post up the code here when it's working...
