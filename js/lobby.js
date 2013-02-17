// Generated by CoffeeScript 1.4.0
(function() {
  var hashToRequestString, renderGameTable;

  window.sock = null;

  window.requestNewGame = function(selectNode) {
    var gameName, gameType, userName;
    gameType = selectNode.value;
    if (!gameType) {
      return;
    }
    gameName = prompt("Name your game:");
    userName = $("#user_name").val();
    if (!userName) {
      userName = "anonymous";
    }
    return window.sock.sendAsJson({
      messageType: "requestNewGame",
      gameType: gameType,
      gameName: gameName,
      userName: userName
    });
  };

  hashToRequestString = function(hash) {
    var k, pairs, v;
    pairs = (function() {
      var _results;
      _results = [];
      for (k in hash) {
        v = hash[k];
        _results.push(k + "=" + v);
      }
      return _results;
    })();
    return pairs.join("&");
  };

  renderGameTable = function(gameList) {
    var row, _i, _len, _results;
    $("#game_list_tbody").html("");
    _results = [];
    for (_i = 0, _len = gameList.length; _i < _len; _i++) {
      row = gameList[_i];
      _results.push((function(row) {
        var a, aTd, client, nameTd, playerLi, playersTd, playersUl, tr, typeTd, _j, _len1, _ref;
        typeTd = $("<td>" + row.type + "</td>");
        nameTd = $("<td>" + row.name + "</td>");
        playersTd = $("<td>");
        playersUl = $("<ul>");
        _ref = row.clients;
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          client = _ref[_j];
          playerLi = $("<li>" + client + "</li>");
          playersUl.append(playerLi);
        }
        playersTd.append(playersUl);
        aTd = $("<td>");
        a = $("<a class='button'>join</a>");
        a.click(function() {
          return window.location = "play.html?gameId=" + row.id + "&userName=" + encodeURIComponent(window.userName);
        });
        aTd.append(a);
        tr = $("<tr>");
        tr.append(typeTd);
        tr.append(nameTd);
        tr.append(playersTd);
        tr.append(aTd);
        return tbody.append(tr);
      })(row));
    }
    return _results;
  };

  $(document).ready(function() {
    var MessageHandler, messageHandler, wsuri;
    MessageHandler = (function() {

      function MessageHandler() {}

      MessageHandler.prototype.lobbyUpdate = function(msg) {
        return renderGameTable(msg.gameList);
      };

      MessageHandler.prototype.newGameReady = function(msg) {
        var hash;
        hash = {
          userName: encodeURIComponent(msg.userName),
          gameId: msg.gameId
        };
        return window.location = "play.html?" + hashToRequestString(hash);
      };

      return MessageHandler;

    })();
    messageHandler = new MessageHandler();
    window.userName = "anonymous";
    if (window.location.protocol === "file:") {
      wsuri = "ws://localhost:9000";
    } else {
      wsuri = "ws://" + window.location.hostname + ":9000";
    }
    if (typeof WebSocket !== "undefined" && WebSocket !== null) {
      window.sock = new WebSocket(wsuri);
    } else if (typeof MozWebSocket !== "undefined" && MozWebSocket !== null) {
      window.sock = new MozWebSocket(wsuri);
    } else {
      window.location = "http://autobahn.ws/unsupportedbrowser";
    }
    window.sock.onopen = function() {
      console.log("Connected to " + wsuri);
      return window.sock.sendAsJson({
        messageType: "enterLobby"
      });
    };
    window.sock.onclose = function(e) {
      console.log(("Connection closed (wasClean = " + e.wasClean + ", ") + ("code = " + e.code + ", reason = '" + e.reason + "')"));
      return window.sock = null;
    };
    window.sock.onmessage = function(e) {
      var msgObj;
      console.log("received message:", e);
      msgObj = JSON.parse(e.data);
      return messageHandler[msgObj.messageType](msgObj);
    };
    window.sock.sendAsJson = function(msgObject) {
      return this.send(JSON.stringify(msgObject));
    };
    return $.ajax({
      url: "game_types.json",
      dataType: "json",
      success: function(response) {
        var gameInfo, option, sel, _i, _len, _results;
        sel = $("#create_game_select");
        _results = [];
        for (_i = 0, _len = response.length; _i < _len; _i++) {
          gameInfo = response[_i];
          option = $("<option value='" + gameInfo.gameType + "'>                                " + gameInfo.displayName + "                            </option>");
          _results.push(sel.append(option));
        }
        return _results;
      }
    });
  });

}).call(this);
