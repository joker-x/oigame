
function check_current_navbar(section){ 
  // comprueba en que URL nos encontramos y dependiendo de eso marca con .active
  // un link del header
  //
  // TODO: mover al controlador, esto es una guarrada
  if ( section.split("#")[1] ) {
    var query = section.split("#")[1];
  }
  var section = section.split("#")[0];
  switch (section) {
    case "campaigns": 
      $("#header-campaigns").addClass("active");
      break;
    case "users":
      $("#header-signup").addClass("active");
      break;
    case "donate":
      $("#header-donate").addClass("active");
      break;
    case "answers":
      $("#header-answers").addClass("active");
      generateTOC("#preguntas");
      generateTOC("#tutorial");
      if (query) { goTo(query); }
      break;
  }
}
////////////////////////// check-current-navbar start
//
$(function() {

  // mensajes de flash, para que se muestren con jGrowl automaticamente
  $(".flash-messages").each(function() {
    var msg = $(this).children("p");
    var theme = $(this).children("p").attr("class");
    $.jGrowl(msg.text(), { 
      sticky: true, 
      theme: "flash-" + theme,
      open: function() { 
        $(this).click( 
          function(){ 
            $(this).fadeOut();
          } 
        )
      }
    });
  });

  // Para la barra de navegación del login
  // cuando no se está desconectado
  $(".signin").click(function(e) {
    e.preventDefault();
    $("fieldset#signin-menu").toggle();
  });

  $("fieldset#signin-menu").mouseup(function() {
    return false;
  });

  $(document).mouseup(function(e) {
    if ($(e.target).parent("a.signin").length==0) {
      $("fieldset#signin-menu").hide();
    }
  });
  
  // Para la barra de navegación del login
  // cuando se está conectado
  $(".signin").click(function(e) {
    e.preventDefault();
    $("#session-menu").toggle();
  });

  $("#session-menu").mouseup(function() {
    return false;
  });

  $(document).mouseup(function(e) {
    if ($(e.target).parent("a.signin").length==0) {
      $("#session-menu").hide();
    }
  });

  $("#user_email").focus();
  $("#campaign_name").focus();
  $("#contact_name").focus();

  check_current_navbar(document.URL.split('/')[3]);

});
