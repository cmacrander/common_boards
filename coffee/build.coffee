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


generateId = ->
    numerals = (n + '' for n in [0..9])
    uppercase = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
                 "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V",
                 "W", "X", "Y", "Z"]
    lowercase = (l.toLowerCase() for l in uppercase)
    chars = numerals.concat(uppercase).concat(lowercase)
    return (chars[Math.floor(Math.random() * 62)] for x in [1..20]).join('')


#-- CLASSES --#


# Fabric has a kinda shitty concept of "class" with lots of aribtrary
# conventions in the serialization process. See
# http://stackoverflow.com/questions/11272772/fabricjs-how-to-save-canvas-on-server-with-custom-attributes/11276133#11276133
# fabric.Piece = fabric.util.createClass(fabric.Rect, {

#     type: 'Piece'

#     initialize: (element, options) ->
#         this.callSuper('initialize', element, options)
#         if options 
#             this.set('_cbId', options._cbId)
#             this.set('_cbPieceName', options._cbPieceName)
#             this.set('_cbLocked', options._cbLocked)
#             this.set('_cbOriginalWidth', options._cbOriginalWidth)
#             this.set('_cbOriginalHeight', options._cbOriginalHeight)

#     toObject: () ->
#         fabric.util.object.extend(this.callSuper('toObject'), {
#             _cbId: this._cbId
#             _cbPieceName: this._cbPieceName
#             _cbLocked: this._cbLocked
#             _cbOriginalWidth: this._cbOriginalWidth
#             _cbOriginalHeight: this._cbOriginalHeight
#         })

# })

# fabric.Piece.fromObject = (object, callback) ->
#   return new fabric.Piece(object)


#-- ANGULAR DIRECTIVES --#


BuildApp = angular.module('BuildApp', [])

# Create a fabric canvas for the main canvas within an angular scope
# also attach a click handler that will clear the currently selected object
# if no object was clicked on
BuildApp.directive 'ngMainCanvas', ->
    return ($scope, element, attrs) ->
        options = {containerClass: 'twelve columns alpha'}
        $scope.canvas = new fabric.Canvas(element.attr('id'), options)
        $scope.canvas.setDimensions({width: 700, height: 644})
        $scope.canvas.on 'object:selected', (options) -> $scope.$safeApply ->
            $scope.currentPiece = options.target
        $scope.canvas.on 'selection:cleared', (options) -> $scope.$safeApply ->
            $scope.currentPiece = false

# Create a fabric canvas for the kitCanvas in the sidebar within the angular scope
# also attach a click handler so that pieces clicked on will add a corresponding
# instance to the main canvas
BuildApp.directive 'ngKitCanvas', ->
    return ($scope, element, attrs) ->
        $scope.kitCanvas = new fabric.Canvas(element.attr('id'))
        $scope.kitCanvas.setDimensions({width: 190, height: 450})
        $scope.kitCanvas.hoverCursor = 'pointer'

        # set up the kitCanvas's click functions
        $scope.kitCanvas.on 'object:selected', (options) -> $scope.$safeApply ->
            $scope.currentKitPiece = options.target
        $scope.kitCanvas.on 'selection:cleared', (options) -> $scope.$safeApply ->
            $scope.currentKitPiece = false

#-- ANGULAR BUILD CONTROLLER --#
            
# Handles the UI for importing and exporting shapes and canvases, selecting
# sets of shapes to use, and putting them on the canvas
# Also handles the UI for setting what properties apply to a given shape
window.BuildCtrl = ($scope) ->
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
        tools: {selected: true}
        props: {selected: false}

    $scope.kits = {}
    $scope.currentKit = false

    $scope.gameTypes = {}
    $scope.currentGameType = false

    $scope.currentPiece = false
    $scope.currentKitPiece = false

    $scope.selectTab = (tabName) ->
        t.selected = false for name, t of $scope.tabs
        $scope.tabs[tabName].selected = true

    $scope.openAddPieceDialog = () ->
        $scope.addPieceName = $scope.addPieceURL = $scope.addPieceSVG = ''
        $('#add_piece_dialog').dialog('open');

    $scope.addPieceByImage = (form) ->
        if form.$invalid then return
        $("#add_piece_dialog").dialog('close')
        fabric.Image.fromURL $scope.addPieceURL, $scope.addPieceTypeByObject

    $scope.addPieceBySVG = (form) ->
        if form.$invalid then return
        $("#add_piece_dialog").dialog('close')
        fabric.loadSVGFromString $scope.addPieceSVG, (objects, options) ->
            o = fabric.util.groupSVGElements(objects, options)
            $scope.addPieceTypeByObject(o)

    # add a fabricjs object to the kitCanvas
    $scope.addPieceTypeByObject = (o) ->
        console.log("adding object to kit", o, $scope.addPieceName)
        o._cbPieceName = $scope.addPieceName
        o.set('hasControls', false)
        o.lockMovementX = o.lockMovementY = true

        box = o.getBoundingRect()
        # shrink to fit in the kitCanvas
        # save original size so instances can be added to main canvas in 
        # the future
        if box.width > box.height and box.width > 60
            o.scaleToWidth(60)
            o._cbOriginalWidth = box.width
        else if box.height >= box.width and box.height > 60
            o.scaleToHeight(60)
            o._cbOriginalHeight = box.height
        # calculate correct position in kitCanvas
        index = $scope.kitCanvas.getObjects().length
        column = index % 2
        row = Math.floor(index / 2)
        $scope.kitCanvas.add(o)
        o.set('top', row * 60 + 30)
        o.set('left', column * 60 + 30)
        o.setCoords()
        $scope.kitCanvas.renderAll()
        $scope.kitCanvas.calcOffset()
        console.log("final object")

    # add an instance of a piece in the kitCanvas to the main canvas
    $scope.addPieceInstance = ->
        clone = fabric.util.object.clone($scope.currentKitPiece)
        clone._cbId = generateId()
        clone.set('hasControls', true)
        clone.lockMovementX = clone.lockMovementY = false

        # ----------
        # there will be more default properties here
        clone._cbLocked = false
        # ----------

        # the object may have been shrunk for display in the kitCanvas, so scale
        # it back to original size
        if clone._cbOriginalWidth
            clone.scaleToWidth(clone._cbOriginalWidth)
        else if clone._cbOriginalHeight
            clone.scaleToHeight(clone._cbOriginalHeight)
        $scope.canvas.add(clone)
        clone.center()
        # http://stackoverflow.com/questions/16694075/why-doesnt-fabricjs-canvas-update-properly-after-object-center/16694541#16694541
        clone.setCoords()
        $scope.canvas.setActiveObject(clone)

    $scope.lockPiece = ->
        o = $scope.currentPiece
        o.lockMovementX = o.lockMovementY = o.lockRotation =
            o.lockScalingX = o.lockScalingY = o.lockUniScaling =
            o._cbLocked
        o.set('hasControls', !o._cbLocked)

    $scope.sendToBack = ->
        $scope.canvas.sendToBack($scope.currentPiece)

    $scope.bringToFront = ->
        $scope.canvas.bringToFront($scope.currentPiece)

    $scope.displayKit = ->
        $scope.kitCanvas.clear()
        loadCallback = () ->
            $scope.kitCanvas.forEachObject (o, index) ->
                o.lockMovementX = o.lockMovementY = true
        $scope.kitCanvas.loadFromJSON($scope.currentKit.state, loadCallback)

    $scope.displayGameType = ->
        $scope.canvas.clear()
        $scope.canvas.loadFromJSON($scope.currentGameType.state)

    $scope.saveKit = ->
        kitName = prompt('kit name:')
        webSocket.saveKit(kitName)

    $scope.saveGameType = ->
        gameTypeName = prompt('game name:')
        webSocket.saveGameType(gameTypeName)

    $scope.deleteKit = ->
        if confirm("Delete kit \"#{$scope.currentKit.name}\"?")
            webSocket.deleteKit($scope.currentKit.id)

    $scope.deleteGameType = ->
        if confirm("Delete game \"#{$scope.currentGameType.name}\"?")
            webSocket.deleteGameType($scope.currentGameType.id)

    $scope.deleteSelectedKitPiece = ->
        o = $scope.kitCanvas.getActiveObject()
        $scope.kitCanvas.remove(o)

    $scope.deleteSelectedPiece = ->
        o = $scope.canvas.getActiveObject()
        $scope.canvas.remove(o)

    handlers =
        kitList: (msg) -> $scope.$apply ->
            $scope.kits = {}
            for kit in msg.data
                $scope.kits[kit.id] = kit

        gameTypeList: (msg) -> $scope.$apply ->
            $scope.gameTypes = {}
            for gameType in msg.data
                $scope.gameTypes[gameType.id] = gameType

        kitSaved: (msg) -> $scope.$apply ->
            console.log("kit saved, id:", msg.kitId, "probably want visual confirmation here.")
            $scope.tempKit.id = msg.kitId
            $scope.kits[msg.kitId] = $scope.tempKit
            delete $scope.tempKit

        gameTypeSaved: (msg) -> $scope.$apply ->
            console.log("gameType saved, id:", msg.gameTypeId, "probably want visual confirmation here.")
            $scope.tempGameType.id = msg.gameTypeId
            $scope.gameTypes[msg.gameTypeId] = $scope.tempGameType
            delete $scope.tempGameType

        kitDeleted: (msg) -> $scope.$apply ->
            console.log("kit deleted, id:", msg.kitId, "probably want visual confirmation here.")
            delete $scope.kits[msg.kitId]

        gameTypeDeleted: (msg) -> $scope.$apply ->
            console.log("gameType deleted, id:", msg.gameTypeId, "probably want visual confirmation here.")
            delete $scope.gameTypes[msg.gameTypeId]

    dispatchers =
        listKits: ->
            # return
            messageType: 'listKits'

        listGameTypes: ->
            # return
            messageType: 'listGameTypes'

        saveKit: (kitName) ->
            state = $scope.kitCanvas.toJSON(includedProperties)
            $scope.tempKit = {name: kitName, state: state}
            # return
            messageType: 'saveKit'
            kitName: kitName
            state: state

        saveGameType: (gameTypeName) ->
            state = $scope.canvas.toJSON(includedProperties)
            $scope.tempGameType = {name: gameTypeName, state: state}
            # return
            messageType: 'saveGameType',
            gameTypeName: gameTypeName,
            state: state

        deleteKit: (kitId) ->
            # return
            messageType: 'deleteKit'
            kitId: kitId

        deleteGameType: (gameTypeId) ->
            #return
            messageType: 'deleteGameType'
            gameTypeId: gameTypeId

    # provided by websocket.coffee
    webSocket = window.initializeWebSocket(handlers, dispatchers)

    webSocket.onopen = ->
        webSocket.listKits()
        webSocket.listGameTypes()


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
