# Brahma Chat

## Dokku setup
BUILDPACK_URL=https://github.com/mbuchetics/heroku-buildpack-nodejs-grunt.git

Copy the `nginx.conf.d` directory (found at `doc/`) into the `/home/dokku/[deploy_app_name]` directory on the dokku server. It's needed to listen to the 443 port to avoid http cache proxies.

## Websockets
Refer to [socket.io](http://socket.io/) for technical stuff.

## Protocol

### Common message structure
#### Request
```
{
	"id": String,
	"type": String,
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
### Received
#### Sessions
```
{
	"id": String,
	"type": "sessions",
	"data": {
		"sessions": Array,
		"_sessions_sign": String 
	}
}
```
#### Message
```
{
	"id": String,
	"type": "message",
	"author": String,
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
	"author": String,
	"session": String,
	"data": {
		"message": String,
		"href": String,
		"type": String (MIME),
		"size": Integer (bytes)
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