statusCodes = {
  2000: 'OK'
  2010: 'Created'
  2020: 'Accepted'
  4000: 'Bad Request'
  4010: 'Unauthorized'
  4020: 'Payment Required'
  4030: 'Forbidden'
  4040: 'Not Found'
  4050: 'Method Not Allowed'
  4080: 'Request Timeout'
}

sendStatus = (code, session, message) ->
  status = statusCodes[code]

  if not status
    code = 5000
    status = 'Internal Server Error'

  statusObject =
    type: 'status'
    status: code
    session: session or null
    data:
      message: message or status

  console.warn message or status

  return JSON.stringify statusObject

module.exports = exports = sendStatus