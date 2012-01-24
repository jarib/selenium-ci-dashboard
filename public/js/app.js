//
// Sidebar
//

var Sidebar = function() {};

Sidebar.prototype.refresh = function(context) {
  context.load('revs.json').
          render('revision_sidebar.mustache').
          replace('.sidebar');

};

//
// Builds
//

var Builds = function() {};

Builds.prototype.load = function(context, params) {
  context.load("/builds/" + params.revision + ".json")
      .render("builds.mustache")
      .replace('.content')
      .then(function() {
        $("#list").tablesorter();

        if(params.view == "list") {
          $("#matrix-tab").removeClass("active")
          $("#list-tab").addClass("active")

          $("#matrix").hide();
          $("#list").slideDown();
        } else {
          $("#list-tab").removeClass("active")
          $("#matrix-tab").addClass("active")

          $("#list").hide();
          $("#matrix").slideDown();
        }
      });
};

var app = Sammy('#main', function() {
  this.use('Mustache');

  this.pages = {};
  this.pages.sidebar = new Sidebar();
  this.pages.builds = new Builds();

  $(document).ajaxStart(function() {
  });

  $(document).ajaxStop(function() {
  });

  this.get('#/', function(context) {
    app.pages.sidebar.refresh(this);
  });

  this.get('#/revision/:revision/:view', function(context) {
    app.pages.sidebar.refresh(this);
    app.pages.builds.load(this, this.params)
  });
});

$(document).ready(function() {
  app.run('#/');
});
