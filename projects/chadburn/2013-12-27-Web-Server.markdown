---
title: Web Server
main: chadburn
author: Tim
---

The Web Server component of the E.O.T. will probably be the most complicated, so I started with it. A [Github repo](https://github.com/Libbum/Chadburn) has also been created that will hold the panel and the Teensy control code too.

The soft plan at the moment will be to write a number / status value to a file via the Teensy; which will be written in `C`. Implementing the rest of the stack in `C` is madness considering we have no need to keep everything embedded.

This means that we'll need a file watcher connected to a web app for the panel interface (which, with `v1.0` will be a soft panel). I know of a decent watcher in `Ruby` and a couple in `Python`, and considering I hate `Ruby` and _Fenchurch_ already has `Python` (somewhat) installed; it seemed like a good starting point. `Python` also has a decent http server stack so that's a plus; but:

![What is this shit](/images/noidea.jpg)

with `Python`... I could argue that this could all be done in `Haskell` too, but no-one likes and Evangelist.

So next step: I don't want to have to refresh the page on an update of the E.O.T. (i.e. a modification in the status file), nor do I want to poll the server with a tonne of ajax queries every 30 seconds or so. Although the update doesn't really need to come through as a push notification, it's also useless if __coffee__ is called and no notification arrives for 15 minutes...

(Very, very) long story short; I've implemented the communication system using [Web Sockets](http://en.wikipedia.org/wiki/WebSocket). They're compaitible with most browsers (maybe not if you use IE, but also: if you use IE I don't care about notifying you of anything anyway) as long as it's a relatively recent build (Chrome though: you're good almost as far back as the dark ages).

[Tornado](http://www.tornadoweb.org) is a great Socket server capable asynchronous (threaded) processes. This is quite helpful for us here because our file watcher will need to run in a separate thread. If any of you have worked with async before you'll know it's a nightmare if you don't have things set up right: race conditions, deadlocks _etc. etc._ It also handles many unique clients - so we can all have the panel open on each of our machines. With the web sockets always open (but not polling), we will have push notifications from the E.O.T. without any overhead on Fenchurch or our local machines.

Once the server is initialised, a callback to [Watchdog](http://pythonhosted.org/watchdog/) is added, which watches `status.eot`: the file written via the teensy, for modifications. If the file has changed (the E.O.T. position has been changed), that value will be instantly read and pushed through the open web sockets to each attached client.

A small amount of debugging has also been implemented (see the `on_message` member of the `WebSocketHandler` class below), which is currently accessible via the panel; although it'll most likely be removed in the future.

Clients are currently identified by `uuid`, but in the future this can be changed to something more personal, a mac address, something like that. It depends on how much capability we want to put into the panel and if any decent ideas are thought up along the way. One thing that I've left out presently is a broadcast update of each client's acceptance message. I've done this because it may be a good way in the future to indicate who is coming to __coffee__ or something.

The only other thing of note is that I've implemented a graceful shutdown so Jared (or any other sudoer) can call a `kill -2` on the server to halt it if it's being an ass. It will call shutdown routines for the watcher and allow any further socket communication to cease (with a maximum waiting time of 5 seconds) before ultimately killing itself.

The code for [v0.5](https://github.com/Libbum/Chadburn/tree/3ca93285c219a7ae818c116e12eff649864bba79) is posted below with enough comments to get you by. Most of those reading this will be familiar enough with `Matlab` to be able to 'read' the `Python` syntax. 

~~~ {lang="python"}
#!/usr/bin/python2

import os
import signal
import time
import uuid

from tornado import gen, ioloop, web, websocket
from tornado.options import define, options, parse_command_line
from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler

define("port", default=1873, help="Run Socket Server on the given port", type=int)
define("status_file", default='status.eot', 
       help="Location of the Chadburn status file")
define("accept_file", default='accept.eot', 
       help="Location of the Chadburn acceptance file")
BASEDIR = os.path.abspath(os.path.dirname(__file__))
MAX_WAIT = 5 #Seconds, before shutdown in signal

observer = Observer() #Filewatcher
clients = dict() #List of all connections

def get_status():
    """
    Reads the contents of the status file when requested
    """
    with open(options.status_file, 'r') as status_file:
        status = status_file.read()
    return status.rstrip()

def write_accept(cmd):
    """
    Writes to the acceptance file the current accepted state.
    This value should ultimately change the mechanical EOT's
    status to an acknowledgement position.
    """
    with open(options.accept_file, 'w') as accept_file:
        accept_file.write(cmd)

def broadcast(message):
    """
    Pushes a message to all currently connected clients.
    Tests connection before hand just in case a disconnect
    has just occurred.
    """
    for ids, ws in clients.items():
        if not ws.ws_connection.stream.socket:
            del clients[ids]
        else:
            ws.write_message(message)

@gen.engine
def status_watcher():
    """
    File watchdog. Using the PatternMatching event handler to minimize 
    overhead. By default the watchdog observes all files and folders recursively
    from the base directory. This setup only watches the supplied status_file.
    """
    event_handler = ChangeHandler(patterns=[BASEDIR + '/' + options.status_file],
                                      ignore_directories=True,
                                      case_sensitive=True)
    observer.schedule(event_handler, BASEDIR, recursive=False)
    observer.start()
    try:
        while True:
            #Non-blocking thread wait
            yield gen.Task(ioloop.IOLoop.instance().add_timeout, time.time() + 1)
    except:
        pass #no default keyboard interrupt handler because of the shutdown below
    observer.join()

def sig_handler(sig, frame):
    """
    Calls shutdown on the next I/O Loop iteration. 
    Should only be used from a signal handler, unsafe otherwise.
    """
    ioloop.IOLoop.instance().add_callback_from_signal(shutdown)

def shutdown():
    """
    Graceful shutdown of all services. Can be called with kill -2 for example, a 
    CTRL+C keyboard interrupt, or 'shutdown' from the debug console on the panel.
    """
    broadcast("EOT Server is shutting down.")
    print "Stopping Status Watcher..."
    observer.stop()
    print "Shutting down EOT server (will wait up to %s seconds to \
           complete running threads ...)" % MAX_WAIT
    
    instance = ioloop.IOLoop.instance()
    deadline = time.time() + MAX_WAIT
 
    def terminate():
        """
        Recursive method to wait for incomplete async callbacks and timeouts
        """
        now = time.time()
        if now < deadline and (instance._callbacks or instance._timeouts):
            instance.add_timeout(now + 1, terminate)
        else:
            instance.stop()
            print "Shutdown."
    terminate()

class ChangeHandler(PatternMatchingEventHandler):
    """
    Broadcasts a status change to all clients when the status_file is modified 
    """
    def on_modified(self, event):
        status = get_status()
        print "Status changed to: " + status
        broadcast(status)

class IndexHandler(web.RequestHandler):
    """
    Serve up the panel
    """
    @web.asynchronous
    def get(self):
        self.render("panel.html")

class WebSocketHandler(websocket.WebSocketHandler):
    """
    Descriptions of websocket interactions. What to do when 
    connecting/disconnecting a client and how to handle a client message
    """
    def open(self):
        #Give client a unique identifier. This may be changed to something 
        #more personal in the future if required.
        self.id = uuid.uuid4()
        self.stream.set_nodelay(True)
        clients[self.id] = self
        print "New Client: %s" % (self.id)
        self.write_message("Connected to EOT Server")
        #Push initial status and assume acknowledgement
        self.write_message(get_status() + "&1") 

    def on_message(self, message):        
        print "Message from Client %s: %s" % (self.id, message)

        #complex commands will be of the form command&command&command
        commands = message.split("&") 
       
        #Most of these are now superfluous. Ultimately only Accept case is 
        #needed, but will keep them here until the production version.
        if (message == 'base'):
            self.write_message(u"Base Directory: " + BASEDIR)
        elif (message == 'file'):
            self.write_message(u"EOT Status file: " + options.status_file)
        elif (message == 'shutdown'):
            self.write_message(u"Shutting down EOT Server...")
            ioloop.IOLoop.instance().add_callback(shutdown)
        elif (message == 'status'):
            status = get_status()
            self.write_message(u"Current Status: " + status)
        elif (len(commands) > 1):
            #Incoming command (for now this is just ACK)
            if (commands[0] == 'Accept'):
                self.write_message(u"Accepted state: " + commands[1])
                write_accept(commands[1] + '\n')
        else:
            self.write_message(u"Server echoed: " + message)
        
    def on_close(self):
        print "Client %s disconnected." % self.id
        if self.id in clients:
            del clients[self.id]
    
app = web.Application([
    (r'/', IndexHandler),
    (r'/websocket', WebSocketHandler),
    (r'/(favicon.ico)', web.StaticFileHandler, {'path': ''},),
    (r'/static/(.*)', web.StaticFileHandler, {'path': './static'},),
])

if __name__ == '__main__':
    #Set up server
    parse_command_line()
    app.listen(options.port)

    #Signal Register
    signal.signal(signal.SIGTERM, sig_handler)
    signal.signal(signal.SIGINT, sig_handler)
    
    #Start the file watcher
    ioloop.IOLoop.instance().add_callback(status_watcher)
    #Start the server main loop
    ioloop.IOLoop.instance().start()
~~~

