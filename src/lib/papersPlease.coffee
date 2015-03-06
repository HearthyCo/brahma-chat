crypto = require 'crypto'
secret = require('./config').secret

# Check signature
checkSignature = (string, sign) ->
  # sign = signtaure + timestamp
  timestamp = sign.substring 44
  signature = sign.substring 0, 44

  # timestamp + string = stringToSign
  newSignature = crypto.createHmac("SHA256", secret).update(timestamp + string).digest('base64')

  return signature is newSignature

# Security checks (⌐■_■)
papersPlease = {
  request: (request) ->
    # TODO: check origin: request.origin
    # TODO: check auth
    return true

  handshake: (object) ->
    ###
      public class Signing {

          public static String sign(String message) {
              long date = System.currentTimeMillis();
              return sign(message, date);
          }

          public static String sign(String message, long date) {
              String key = Play.application().configuration().getString("application.secret");
              String innerMessage = Long.toString(date) + message;
              try {
                  Mac sha256_HMAC = Mac.getInstance("HmacSHA256");
                  SecretKeySpec secret_key = new SecretKeySpec(key.getBytes(), "HmacSHA256");
                  sha256_HMAC.init(secret_key);
                  String hash = Base64.encodeBase64String(sha256_HMAC.doFinal(innerMessage.getBytes()));
                  return hash + Long.toString(date);
              } catch (NoSuchAlgorithmException e) {
                  throw new RuntimeException(e);
              } catch (InvalidKeyException e) {
                  throw new RuntimeException(e);
              }
          }

          public static long getTimestamp(String signature) {
              return Long.parseLong(signature.substring(44));
          }

          public static boolean check(String message, String signature) {
              long date = getTimestamp(signature);
              String newSignature = sign(message, date);
              return newSignature.equals(signature);
          }

      }
    ###
    if not object.data
      return false
    data = object.data
    if not data._userId_sign or not data._sessions_sign
      return false

    if not checkSignature data.userId, data._userId_sign
      return false

    if not checkSignature JSON.stringify(data.sessions), data._sessions_sign
      return false

    return true

  message: (object) ->
    # TODO: check by type
    return true
}

module.exports = exports = papersPlease