# Brahma Chat
## Websockets
Refer to [socket.io](http://socket.io/) for technical stuff.

## Protocol

### Common message structure
#### Request
```
{
	"id": String,
	"type": String,
	"session": null | String,
	"data": Object
}
```
#### Received
```
{
	"id": String,
	"type": String,
	"author": String,
	"timestamp": Integer,
	"session": null | String,
	"data": Object
}
```
#### Response
```
{
	"id": null | String,
	"type": String,
	"status": Integer,
	"session": null | String,
	"data": Object
}
```
### Request
#### Handshake
```
{
	"id": String,
	"type": "handshake",
	"session": null,
	"data": {
		"user": {
			"name": String,
			"role": String
		}
	}
}
```
#### Message
```
{
	"id": String,
	"type": "message",
	"session": String,
	"data": {
		"message": String
	}
}
```
#### Attachment
```
{
	"id": String,
	"type": "attachment",
	"session": String,
	"data": {
		"message": String,
		"href": String,
		"type": String (MIME),
		"size": Integer (bytes)
	}
}
```
#### Ping
```
{
	"id": String,
	"type": "ping",
	"data": {
		"message": null | String
	}
}
```
### Response
#### Status, Error
```
{
	"id": null | String,
	"type": "status",
	"status": Integer,
	"session": null | String,
	"data": {
		"message": String
	}
}
```
#### Pong
```
{
	"id": String,
	"type": "pong",
	"author": String,
	"timestamp": Integer,
	"data": {
		"message": null | String
	}
}
```
## Status
Basically, our status codes are an extension of the HTTP status codes.

In example: _Forbidden_ status (`HTTP 403`) is the status `4030`.

### 1xxx Informational
### 2xxx Success
### 3xxx Redirection
### 4xxx Client Error
##### 4030 Forbidden
### 5xxx Server Error