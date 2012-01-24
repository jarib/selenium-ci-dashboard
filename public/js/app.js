$(document).ready(function() {
  $("table").tablesorter();

  $(".tabs a").click(function() {
    var el = $(this);

    var rev = el.parent().parent().attr("data-rev");
    var revsTable = $("#revs-" + rev).hide();
    // switch tab
    $(".tabs li").removeClass("active");
    el.parent().addClass("active");

    if(el.text() == "matrix") {
      $.ajax({
          url: "/matrix/" + rev,
          type: "GET",
          dataType: "html",

          success: function(data) {
            revsTable.after(data);
          },

          error: function() {
            $("#error-message").slideDown();
            setTimeout(function() {
              $("#error-message").slideUp();
            }, 3000);
          },
      });
    } else {
      $("#matrix-" + rev).hide();
      $("#revs-" + rev).show();
    }
  });
});