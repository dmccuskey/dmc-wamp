# Backend for the dmc-wamp examples: runs inside the Crossbar router
# (the "container" worker in .crossbar/config.json).
#
# - provides the procedure com.example.add2, which adds two numbers
# - publishes 'tick-1', 'tick-2', ... on com.myapp.topic1 once a second
# - prints whatever others publish on com.myapp.topic1

from autobahn.twisted.wamp import ApplicationSession
from autobahn.twisted.util import sleep
from twisted.internet.defer import inlineCallbacks


class Backend(ApplicationSession):

    @inlineCallbacks
    def onJoin(self, details):

        def add2(a, b):
            print("backend: add2 called with", a, b)
            return a + b

        def on_event(*args, **kwargs):
            print("backend: received event", args, kwargs)

        yield self.register(add2, 'com.example.add2')
        yield self.subscribe(on_event, 'com.myapp.topic1')

        n = 0
        while True:
            n += 1
            self.publish('com.myapp.topic1', 'tick-%d' % n)
            yield sleep(1)
