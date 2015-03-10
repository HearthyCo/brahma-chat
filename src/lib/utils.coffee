statusCodes =
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

utils =
  checkRequiredFields: (object, args) ->
    return false if not object?
    for arg in args
      t = object
      fields = arg.split '.'
      for field in fields
        return false if not t[field]?
        t = t[field]
    return true

  mkResponse: (code, id, type, session, data) ->
    status = statusCodes[code]
    type = type || 'status'
    data = data || message: status

    console.warn new Date(), code, type, data if code >= 4000 && status?

    if not status
      code = 5000
      status = 'Internal Server Error'
      console.error new Date(), status, type, data

    statusObject =
      id: id or null
      type: type
      status: code
      data: data

    JSON.stringify statusObject

  htmlEntities: (str) ->
    String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')

module.exports = exports = utils
