$(document).ready ->
    stage = new Kinetic.Stage
        container: 'canvas'
        width: $("#canvas").width() - 20
        height: $("#canvas").height() - 20

    layer = new Kinetic.Layer()

    rect = new Kinetic.Rect
        x: 239
        y: 75
        width: 100
        height: 50
        fill: 'green'
        stroke: 'black'
        strokeWidth: 4
        draggable: true

    # add the shape to the layer
    layer.add rect

    rect.on 'mousedown touchstart', -> 
        rect.setFill "blue"
        layer.draw()
   
    rect.on 'mouseup touchend', () ->
        this.setFill "green"
        layer.draw()

    # add the layer to the stage
    stage.add layer