checkSignature = require './checkSignature'

console.log "result", checkSignature 90005, "jqH5JjRxd8tsPoNITZrXcFSwSTkHf7NSJO7DXnL7ucE=1425650576292"
console.log "result", checkSignature JSON.stringify([90700]), "M4Bv3qY+dnfjC8u9CE9cYfi2V08niP1MlJ3mU3ASYrM=1425650576292"