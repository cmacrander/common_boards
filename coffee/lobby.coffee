window.sock = null

window.requestNewGame = (selectNode) ->
    gameType = selectNode.value
    if not gameType then return
    
    gameName = prompt "Name your game:" 
    
    userName = $("#user_name").val()
    if not userName then userName = "anonymous"
    
    window.sock.sendAsJson
        messageType: "requestNewGame"
        gameType: gameType
        gameName: gameName
        userName: userName
        
hashToRequestString = (hash) ->
    pairs = ( k + "=" + v for k, v of hash )
    return pairs.join "&"

renderGameTable = (gameList) ->
    $("#game_list_tbody").html("")
    
    for row in gameList
     do (row) ->
        typeTd = $("<td>#{row.type}</td>")
        
        nameTd = $("<td>#{row.name}</td>")
        
        playersTd = $("<td>")
        playersUl = $("<ul>")
        for client in row.clients
            playerLi = $("<li>#{client}</li>")
            playersUl.append playerLi 
        playersTd.append playersUl
        
        aTd = $("<td>")
        a = $("<a class='button'>join</a>")
        a.click () ->
            window.location = "play.html?gameId=" + row.id + 
                              "&userName=" + encodeURIComponent window.userName
        aTd.append a
        
        tr = $("<tr>")
        tr.append typeTd
        tr.append nameTd
        tr.append playersTd
        tr.append aTd
        
        tbody.append tr

$(document).ready () ->

    #-- DEFINITIONS --#

    class MessageHandler
        lobbyUpdate: (msg) -> renderGameTable msg.gameList
        
        newGameReady: (msg) ->
            hash = 
                userName: encodeURIComponent msg.userName
                gameId: msg.gameId
                
            window.location = "play.html?" + hashToRequestString hash

    #-- INITIALIZE VALUES --#
    
    messageHandler = new MessageHandler()
    window.userName = "anonymous"
    
    #-- PREPARE WEBSOCKET CONNECTION --#
    
    if window.location.protocol == "file:"
        wsuri = "ws://localhost:9000"
    else
        wsuri = "ws://#{window.location.hostname}:9000"
    
    if WebSocket?         then window.sock = new WebSocket wsuri
    else if MozWebSocket? then window.sock = new MozWebSocket wsuri
    else window.location = "http://autobahn.ws/unsupportedbrowser"
    
    window.sock.onopen = () ->
        console.log "Connected to #{wsuri}"
        window.sock.sendAsJson { messageType: "enterLobby" }
    
    window.sock.onclose = (e) ->
        console.log "Connection closed (wasClean = #{e.wasClean}, " +
                    "code = #{e.code}, reason = '#{e.reason}')"
        window.sock = null

    window.sock.onmessage = (e) ->
        console.log "received message:", e
        msgObj = JSON.parse e.data
        messageHandler[msgObj.messageType] msgObj
        
    window.sock.sendAsJson = (msgObject) -> @send JSON.stringify msgObject
    
    #--- RENDERING --#
    
    # get game type menu
    $.ajax
        url: "game_types.json"
        dataType: "json"
        success: (response) ->
            sel = $("#create_game_select")
            for gameInfo in response
                option = $("<option value='#{gameInfo.gameType}'>
                                #{gameInfo.displayName}
                            </option>")
                sel.append option
    
    #--- MISC ---#
    
    # dojo.byId("create_game_select").value = ""