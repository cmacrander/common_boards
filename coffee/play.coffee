# Vocabulary

# Piece - generic term for a manipulable object in a game
# KitPiece - a piece in the kitCanvas that serves as a prototype for pieces
#     you can add to the main canvas
# PieceInstance - a piece on the main canvas, may share a PieceType with other
#     PieceInstances
# Gallery - a canvas that stores kitPieces so you can click on them and add
#     pieceInstances to the main canvas. A given kitCanvas can be saved as a kit.
# Kit - a particular set of contents for a kitCanvas. The idea being that a
#     certain kit could be used to created several different initial game
#     states. A tic-tac-toe kit would include an X, an O, and a board.
# State - a javascript dictionary/object representation (the result of
#     parsed JSON) of a canvas; can be passed directly to canvas.loadFromJSON


#-- DEBUGGING --#


window.getScope = ->
    return angular.element($('#main')).scope()


#-- CONSTANTS --#


includedProperties = [
    '_cbId',
    '_cbPieceName',
    '_cbLocked',
    '_cbOriginalWidth',
    '_cbOriginalHeight',
]


#-- FUNCTIONS --#


window.getRequestStringData = ->
    pairs = window.location.search.substring(1).split('&')
    data = {}
    for p in pairs
        d = p.split('=')
        data[d[0]] = d[1]
    return data


#-- CLASSES --#




#-- ANGULAR DIRECTIVES --#


PlayApp = angular.module('PlayApp', [])

# Create a fabric canvas for the main canvas within an angular scope
# also attach a click handler that will clear the currently selected object
# if no object was clicked on
PlayApp.directive 'ngMainCanvas', ->
    return ($scope, element, attrs) ->
        options = {containerClass: 'twelve columns alpha'}
        $scope.canvas = new fabric.Canvas(element.attr('id'), options)
        $scope.canvas.setDimensions({width: 700, height: 644})
        $scope.canvas.on 'object:selected', (options) -> $scope.$apply ->
            $scope.currentPiece = options.target
        $scope.canvas.on 'selection:cleared', (options) -> $scope.$apply ->
            $scope.currentPiece = false
        $scope.canvas.on 'object:moving', (options) -> $scope.$apply ->
            $scope.pieceMoving(options)




#-- ANGULAR PLAY CONTROLLER --#
            
window.PlayCtrl = ($scope) ->
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

    $scope.tabs =
        props: {selected: true}
        players: {selected: false}

    $scope.players = {}

    $scope.pieces = {}
    $scope.currentPiece = false

    $scope.motionLabels = {}
    $scope.motionLabelTimeouts = {}

    data = getRequestStringData()
    $scope.gameId = data.gameId
    $scope.userName = data.userName

    $scope.selectTab = (tabName) ->
        t.selected = false for name, t of $scope.tabs
        $scope.tabs[tabName].selected = true

    # todo: standardize signature with builder
    $scope.lockPiece = (o) ->
        o.lockMovementX = o.lockMovementY = o.lockRotation =
            o.lockScalingX = o.lockScalingY = o.lockUniScaling =
            o._cbLocked
        o.set('hasControls', !o._cbLocked)

    # applied to all non-locked object when a fresh game state is loaded onto 
    # the canvas
    $scope.allowTranslationOnly = (o) ->
        o.set('hasControls', false)
        if o._cbLocked
            $scope.lockPiece(o)
        else
            o.lockRotation = o.lockScalingX = o.lockScalingY = 
                o.lockUniScaling = true

    $scope.sendToBack = ->
        $scope.canvas.sendToBack($scope.currentPiece)

    $scope.bringToFront = ->
        $scope.canvas.bringToFront($scope.currentPiece)

    # called from the canvas directive, linked to fabric's object:moving event
    # options.target is the moving object, options.e is the mouse event
    $scope.pieceMoving = (options) ->
        # process position info and broadcast it
        newValueDict =
            left: options.target.left
            top: options.target.top
        webSocket.setObjectProperties(options.target._cbId, newValueDict)

    $scope.saveGame = ->
        # remember to remove all the labels that might be around
        # before serializing the canvas
        for id, label of $scope.motionLabels
            $scope.canvas.remove(label)

    handlers =
        error: (msg) ->
            console.error(msg)

        # called when a player first loads the page, initializes the canvas
        setGameState: (msg) -> $scope.$apply ->
            $scope.gameName = msg.gameName
            $scope.canvas.loadFromJSON(msg.gameState)
            $scope.canvas.forEachObject (o) ->
                # lock down rotation, scaling, and handles
                $scope.allowTranslationOnly(o)
                # index objects for easy reference and manipulation
                $scope.pieces[o._cbId] = o


        playersUpdate: (msg) -> $scope.$apply ->
            $scope.players = msg.players
            # make a motion tag for each player
            $scope.motionLabels = {}
            for id, name of $scope.players
                label = new fabric.Text name,
                    fontSize: 18
                $scope.motionLabels[id] = label


        # Another player has changed the properties of some object
        setObjectProperties: (msg) -> $scope.$apply ->
            # todo: right now this is only about motion, will have
            # to generalize it to handle all properties

            # update the client's data to match
            o = $scope.pieces[msg.objectId]
            for p, v of msg.newValueDict
                o.set(p, v)
            o.setCoords()

            if 'left' of msg.newValueDict and 'top' of msg.newValueDict
                # object is moving, so attach a motion label
                label = $scope.motionLabels[msg.senderId]
                if msg.senderId not in $scope.motionLabelTimeouts
                    # the label isn't currently attached, so put it on the canvas
                    $scope.canvas.add(label)
                else
                    # there's a timeout active, clear it so it can be updated
                    clearTimeout($scope.motionLabelTimeouts[msg.senderId])
                # update the timeout
                callback = ->
                    $scope.canvas.remove(label)
                    delete $scope.motionLabelTimeouts[msg.senderId]
                $scope.motionLabelTimeouts[msg.senderId] = setTimeout(callback, 1000)
                # also position the label near the moving object
                label.set('left', msg.newValueDict.left - 50)
                label.set('top', msg.newValueDict.top - 50)
                label.setCoords()
            $scope.canvas.renderAll()


       

    dispatchers =
        enterGame: (userName, gameId) ->
            # return
            messageType: 'enterGame'
            userName: $scope.userName
            gameId: $scope.gameId

        setObjectProperties: (objectId, newValueDict) ->
            # return
            messageType: 'setObjectProperties'
            gameId: $scope.gameId
            objectId: objectId
            newValueDict: newValueDict

    # provided by websocket.coffee
    webSocket = window.initializeWebSocket(handlers, dispatchers)

    webSocket.onopen = ->
        webSocket.enterGame()


#-- ANGULAR STANDARD CONTROLLER --#


# The same controller that players would use to manipulate their shapes
# in play.html
window.ControlCtrl = ($scope) ->


#-- JQUERY-UI WIDGET INSTANTIATION --#


$(document).ready ->
    # create dialog boxes
    $("#add_piece_dialog").dialog
        autoOpen: false
        height: 500
        width: 600
        modal: true
