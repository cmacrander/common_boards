window.initializeWebSocket = (handlers, dispatchers) ->
    if window.location.protocol == "file:"
        wsuri = "ws://localhost:9000"
    else
        wsuri = "ws://" + window.location.hostname + ":9000"
    
    if WebSocket?         then sock = new WebSocket wsuri
    else if MozWebSocket? then sock = new MozWebSocket wsuri
    else window.location = "http://autobahn.ws/unsupportedbrowser"

    #-- LISTENERS --#
    
    sock.sendAsJson = (message) -> 
        # console.log("webSocket sent:", message)
        @send(JSON.stringify(message))
    
    sock.onopen = () ->
        console.log "Default onopen() listener. Connected to " + wsuri
    
    sock.onclose = (e) ->
        console.log "Default onclose() listener. Connection closed " +
                    "(wasClean = #{e.wasClean}, " +
                    "code = #{e.code}, reason = '#{e.reason}')"

    sock.onmessage = (e) ->
        message = JSON.parse(e.data)
        # console.log("webSocket received:", message)
        if message.messageType of @handlers
            @handlers[message.messageType] message
        else
            throw new Error("No handler for message type #{message.messageType}.")

    sock.handlers = handlers

    for name, f of dispatchers
        do (name, f) ->
            if name of sock
                throw new Error("Dispatcher name collided: #{name}.")
            else
                sock[name] = (args...) ->
                    @sendAsJson(f(args...))

    return sock
