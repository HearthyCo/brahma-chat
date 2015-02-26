# Brahma Chat

## Protocol

### Common message structure
#### Request
```
{
	"type": String,
	"session": null | String,
	"data": Object
}
```
#### Response
```
{
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
	"type": "ping"
}
```
### Response
#### Status, Error
```
{
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
	"type": "pong"
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