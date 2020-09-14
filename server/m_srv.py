from pprint import pprint
from twisted.internet import reactor
from twisted.internet.defer import inlineCallbacks,returnValue, ensureDeferred, setDebugging
from twisted.internet.endpoints import TCP4ServerEndpoint
from twisted.internet.protocol import Factory
from twisted.internet.protocol import Protocol
from twisted.logger import Logger
from elasticsearch import Elasticsearch
from json import loads
from time import time

TIMESTAMP = "date"

class ForwardData(Protocol):
    """
    If issues with timestamp not being accepted by elastic as type date
    the mapping probably has to be set manually: 
    Use index mapping from: 
    https://www.elastic.co/guide/en/elasticsearch/reference/current/date.html
    and then use the console dev tool to set it. the index will likely have to
    be deleted before setting the mapping.
    """
    def __init__(self):
        self.elastic = Elasticsearch([{'host':'localhost','port':9200}])

    def connectionMade(self):
        print("Connection made...")
        #self.transport.write(b'Welcome to Mogop Server\n')
        self.transport.write(b'{"message":"Welcome to Mogop Server", "status":1}\n')

    def dataReceived(self, received_data):
        self.transport.write(b'Data is being handled\n')
        received_data = loads(received_data)
        received_data[TIMESTAMP] = int(time()*1000)
        print(received_data)
        self.elastic.index('sandbox',received_data)
        self.transport.loseConnection()

class ForwardDataFactory(Factory):

    #def __init__(self, es_srvr):
    #    self.es_srvr = es_srvr

    def buildProtocol(self, addr):
        return ForwardData()

class Elastic(object):
    #DOC TYPES
    def __init__(self, host='127.0.0.1', port='9200', index='sandbox', doc_type='test'):
        self.host = host
        self.port = port
        self.index = index
        self.doc_type = doc_type
        self.es = Elasticsearch('{}:{}'.format(host,port) )

    @inlineCallbacks
    def index_data(self, data, index=None):
        print("Indexing")
        if index is None:
            index = self.index
        #yield ensureDeferred(self.es.index(data, doc_type=self.doc_type, index=index))
        self.es.index(index, data)
        print("Data indexed")


endpoint = TCP4ServerEndpoint(reactor, 1234)
endpoint.listen(ForwardDataFactory())
print("Starting Server")
reactor.run()
