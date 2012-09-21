(function($){
  var pixChat = {
    channel: '',

    show: function(msg) {
      console.log('[pixChat] ' + msg)
    },

    init: function() {
      pixChat.ws = ws = new WebSocket('ws://'+document.location.hostname+':4567');
      ws.onopen    = function()  { pixChat.show('connecting...'); };
      ws.onclose   = function()  { pixChat.show('disconnected.'); }
      ws.onmessage = function(m) { pixChat.parse(m.data); };
      $(document).on('click', '.pixchat-talker > input[type=button]', pixChat.clickTalk);
      $(document).on('keydown', '.pixchat-talker > input[type=textbox]', function(e){if(e.keyCode == 13){ pixChat.clickTalk(); }});
    },

    clickTalk: function() {
      var chatbox = $('#pixChat-'+pixChat.channel+' + .pixchat-talker > input[type=textbox]');

      if (chatbox.val() != "")
        pixChat.talk(chatbox.val());

      chatbox.val('');
    },

    join: function(chan) {
      console.log('[pixChat] switching to channel '+chan);
      pixChat.send({event: 'join', username: pixiv.user.username, channel: chan});
      pixChat.channel = chan;
    },

    part: function() {
      console.log('[pixChat] leaving channel '+pixChat.channel);
      pixChat.send({event: 'part', channel: pixChat.channel});
      pixChat.channel = null;
    },

    parse: function(data) {
      pixChat.show('received: '+data);
      data = $.parseJSON(data);
      switch(data['event']) {
        case 'connect':
          break;

        case 'join':
          var target = $('#pixChat-'+pixChat.channel);
          var text = "";

          if (data['sender'] == pixiv.user.username)
            text = "You have joined.";
          else
            text = data['sender']+ " has joined.";

          target.prepend(text+"<br/>");

          break;

        case 'part':
          var target = $('#pixChat-'+pixChat.channel);
          var text = "";

          if (data['sender'] == pixiv.user.username)
            text = "You have left.";
          else
            text = data['sender']+ " has left.";

          target.prepend(text+"<br/>");

          break;

        case 'msg':
          var target = $('#pixChat-'+pixChat.channel);
          target.prepend("&lt;"+data['sender']+ "&gt; "+data['payload']+"<br />");
      }
    },

    send: function(data) {
      pixChat.ws.send(JSON.stringify(data));
    },

    talk: function(data) {
      pixChat.send({event: 'msg', msg: data});
    }
  }

  window.pixChat = pixChat;
  jQuery(function ($) {
    pixChat.init();
  });
})(jQuery);
