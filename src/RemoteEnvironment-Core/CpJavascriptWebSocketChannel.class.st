Class {
	#name : #CpJavascriptWebSocketChannel,
	#superclass : #CpMessageChannel,
	#instVars : [
		'state',
		'eventSemaphore',
		'semaphoreIndex'
	],
	#category : #'RemoteEnvironment-Core'
}

{ #category : #all }
CpJavascriptWebSocketChannel class >> for: ownerObject connectedToUrl: urlString [

	"Create for the specified owner, a new instance of the receiver which is connected
	to the specified URL.
	Implementation: A primitive WebSocket is created which operates asynchronously and
	uses a Semaphore to signal events. For convenience #connectToUrl: does wait for the
	connection to become established (or explicitly fails)."

	| instance |

	instance := self newFor: ownerObject.
	(instance connectToUrl: urlString)
		ifFalse: [
			instance release.
			^ nil ].

	"Start message handler now that the connection is established"
	^ instance
		createMessageHandler ;
		yourself
]

{ #category : #all }
CpJavascriptWebSocketChannel class >> newFor: ownerObject [

	"Answer a new instance of the receiver with the specified owner"

	^ self new
		owner: ownerObject ;
		yourself
]

{ #category : #all }
CpJavascriptWebSocketChannel class >> startServerOnPort: anInteger path: aString do: aValuable [

	"Create a server listening on the specified port and path.
	When a new connection is made a new instance of the receiver is created for the
	specified owner. The owner Object will need to handle the relevant events.
	See CpMessageChannel>>#owner:."

	"A Javascript implementation for Node.js is in the making. There will not be
	a web browser implementation, since web browsers should not allow incoming network
	connections (because of security reasons)."
	Error signal: 'Currently the Javascript implementation is still missing'
]

{ #category : #all }
CpJavascriptWebSocketChannel >> close [

	"Close the receiver, thereby making the receiver unusable.
	Implementation: Closing is performed asynchronously and an event will be signalled when closed."

	self primWebSocketClose
]

{ #category : #all }
CpJavascriptWebSocketChannel >> connectToUrl: urlString [

	"Connect the receiver to the specified URL and answer whether this succeeded.
	Implementation: A primitive WebSocket is created which operates asynchronously and uses a Semaphore
	to signal events. Make this method synchronous: wait for the connection to become ready."

	self primWebSocketConnectTo: urlString withEventSemaphore: semaphoreIndex.

	"Wait for state to become different than -1 (unused) or 0 (connecting)"
	[ #(-1 0) includes: state  ] whileTrue: [ self updateState ].

	"Connection is only successful if state is open"
	^ self isOpen
]

{ #category : #all }
CpJavascriptWebSocketChannel >> initialize [

	"Initialize the receiver.
	Implementation: Start with an 'unused' state so #isOpen will answer false."

	super initialize.

	eventSemaphore := Semaphore new.
	semaphoreIndex := (Smalltalk registerExternalObject: eventSemaphore)
		ifNil: [ Error signal: 'Failed to register semaphore for WebSocket connection' ].

	state := -1

]

{ #category : #all }
CpJavascriptWebSocketChannel >> isOpen [

	"Receiver is considered open if state is 'open'.
	See #updateState"

	^ state = 1
]

{ #category : #all }
CpJavascriptWebSocketChannel >> primWebSocketClose [

	"Close the primitive WebSocket. Closing an already closed connection will be ignored."

	<primitive: 'primitiveWebSocketClose' module: 'CpSystemPlugin'>
	self primitiveFailed

]

{ #category : #all }
CpJavascriptWebSocketChannel >> primWebSocketConnectTo: urlString withEventSemaphore: semaIndex [

	"Connect the primitive WebSocket to the specified URL and use the specified Semaphore for signaling events"

	<primitive: 'primitiveWebSocketConnectTo:withEventSemaphore:' module: 'CpSystemPlugin'>
	self primitiveFailed
]

{ #category : #all }
CpJavascriptWebSocketChannel >> primWebSocketReadyState [

	"Answer the state of the primitive WebSocket.
	See https://devdocs.io/dom/websocket/readystate"

	<primitive: 'primitiveWebSocketReadyState' module: 'CpSystemPlugin'>
	self primitiveFailed

]

{ #category : #all }
CpJavascriptWebSocketChannel >> primWebSocketReceivedMessage [

	"Answer the next message received or nil if none is available"

	<primitive: 'primitiveWebSocketReceivedMessage' module: 'CpSystemPlugin'>
	self primitiveFailed

]

{ #category : #all }
CpJavascriptWebSocketChannel >> primWebSocketSend: aByteArray [

	"Send the message through the primitive WebSocket (asynchronous).
	Answer a Boolean indicating whether send was successful."

	<primitive: 'primitiveWebSocketSend:' module: 'CpSystemPlugin'>
	self primitiveFailed

]

{ #category : #all }
CpJavascriptWebSocketChannel >> receivedMessage [

	"Answer the next message received or nil if none is available.
	Implementation: The WebSocket works asynchronous and will respond directly with either the
	'oldest' message received or nil if no messages are left."

	^ self primWebSocketReceivedMessage

]

{ #category : #all }
CpJavascriptWebSocketChannel >> release [

	"Release instance variables of the receiver.
	Implementation: Reset the state to an 'unused' value so #isOpen will answer false."

	eventSemaphore ifNotNil: [
		eventSemaphore signal.
		Smalltalk unregisterExternalObject: eventSemaphore.
		eventSemaphore := nil ].
	semaphoreIndex := nil.

	state := -1.

	super release
]

{ #category : #all }
CpJavascriptWebSocketChannel >> sendMessage: aByteArray [

	"Send the specified message.
	An Exception should be thrown if sending failed."

	(self primWebSocketSend: aByteArray)
		ifFalse: [ Error signal: 'Failed to send message' ]
]

{ #category : #all }
CpJavascriptWebSocketChannel >> updateState [

	"Update the receiver's state.
	Implementation: The receiver works asynchronously, so wait for events to be signalled.

	Set state according to primitive WebSocket (negative state values are used internally)
		0 - connecting
		1 - open (and ready to communicate)
		2 - closing
		3 - closed (or could not be opened)
	See https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/readyState
	"

	"Set the state before and after waiting for the next event, so other processes see
	the correct state of the receiver. No need to wait for another event if state is 3 (closed)."
	(state := self primWebSocketReadyState) = 3
		ifTrue: [ ^ self ].
	eventSemaphore wait.
	state := self primWebSocketReadyState
]