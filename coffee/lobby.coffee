# not used
hashToRequestString = (hash) ->
    pairs = ( k + '=' + v for k, v of hash )
    return pairs.join '&'

LobbyApp = angular.module('LobbyApp', [])


window.LobbyCtrl = ($scope) ->
    # https://coderwall.com/p/ngisma
    # this solves the following problem: a event-driven function is sometimes
    # called from the global scope due to a mouse click, and so needs $apply,
    # but sometimes the same function is called from WITHIN SCOPE, like as
    # a consequence of canvas.remove(object), in which case $apply would
    # throw an error. This checks if $apply is necessary before doing it.
    $scope.$safeApply = (fn) ->
        phase = this.$root.$$phase
        if phase is '$apply' or phase is '$digest'
            if fn and (typeof(fn) is 'function')
                fn()
        else
            this.$apply(fn)

    $scope.gameTypes = {}
    $scope.currentGameType = false

    $scope.games = {}

    $scope.requestNewGame = ->
        if not $scope.currentGameType then return
        userName = $scope.userName ? 'anonymous'
        gameName = prompt("Name your game:")
        if gameName
            webSocket.requestNewGame(userName, gameName)

    $scope.joinGame = (gameId) ->
        userName = $scope.userName ? 'anonymous'
        window.location = "play.html?gameId=#{gameId}&userName=#{userName}"

    $scope.stupid = (gameId) -> console.log('stupid')


    handlers =
        error: (msg) ->
            console.error(msg)

        gameTypeList: (msg) -> $scope.$apply ->
            $scope.gameTypes = {}
            for gameType in msg.data
                $scope.gameTypes[gameType.id] = gameType

        lobbyUpdate: (msg) -> $scope.$apply ->
            $scope.games = {}
            for game in msg.gameList
                game.clientsHtml = game.clients.join('<br>')
                $scope.games[game.id] = game

        newGameReady: (msg) -> $scope.$apply ->
            $scope.joinGame(msg.gameId)


    dispatchers =
        enterLobby: ->
            # return
            messageType: 'enterLobby'

        listGameTypes: ->
            # return
            messageType: 'listGameTypes'

        requestNewGame: (userName, gameName) ->
            #return
            messageType: 'createGame'
            userName: $scope.userName
            gameTypeId: $scope.currentGameType.id
            gameName: gameName

        enterGame: (userName, gameId) ->
            # return
            messageType: 'enterGame'
            userName: userName
            gameId: gameId


    # provided by websocket.coffee
    webSocket = window.initializeWebSocket(handlers, dispatchers)

    webSocket.onopen = ->
        webSocket.listGameTypes()
        webSocket.enterLobby()
