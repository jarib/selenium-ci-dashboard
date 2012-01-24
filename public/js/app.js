$(document).ready(function() {
  $("table").tablesorter();

  $(".tabs a").click(function() {
    var el = $(this);

    var rev = el.parent().parent().attr("data-rev");
    var matrixElement = $("#matrix-" + rev);
    var revElement = $("#revs-" + rev);

    // switch tab
    $(".tabs li").removeClass("active");
    el.parent().addClass("active");

    if(el.text() == "matrix") {
      revElement.hide();

      if(matrixElement.size() != 0) {
        console.log("showing existing element");
        matrixElement.show();
        return;
      }

      $.ajax({
          url: "/matrix/" + rev,
          type: "GET",
          dataType: "html",

          success: function(data) {
            revElement.before(data);
          },

          error: function() {
            $("#error-message").slideDown();
            setTimeout(function() {
              $("#error-message").slideUp();
            }, 3000);
          },
      });
    } else {
      matrixElement.hide();
      revElement.show();
    }
  });
});