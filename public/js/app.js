//
// Sidebar
//

var Sidebar = function() {
  this.setupKeyboard();
};

Sidebar.prototype.refresh = function(context) {
  context.load('revs.json', {cache: false}).
          render('revision_sidebar.mustache').
          replace('.sidebar').then(function() {
            $(".sidebar tr").click(function() {
              context.redirect($(this).find("a").attr("href"));
            })
          });
};

Sidebar.prototype.setupKeyboard = function() {
  var self = this;
  $(window).keydown(function(e) {
    switch (e.which) {
      case 74: // j
        self.moveDown();
        break;
      case 75: // k
        self.moveUp()
        break;
    }
  });
};

Sidebar.prototype.moveDown = function() {
  var rows = $(".sidebar tr");
  var active = rows.filter(".active")
  var next = active.next();

  if(active.size() == 0 || next.size() == 0) {
    // select the first item
    this.makeFirstItemActive();
  } else {
    active.removeClass("active");
    next.addClass("active").scrollintoview({duration: 0});
    next.find("a").click();
  }
};

Sidebar.prototype.moveUp = function() {
  var rows = $(".sidebar tr");
  var active = rows.filter(".active")
  var prev = active.prev();

  if(active.size() == 0 || prev.size() == 0) {
    // select the first item
  } else {
    active.removeClass("active");
    prev.addClass("active").scrollintoview({duration: 0});
    prev.find("a").click();
  }
};

Sidebar.prototype.makeFirstItemActive = function() {
  $(".sidebar tr").filter(":eq(1)")
      .addClass("active")
      .scrollintoview({duration: 0});
};

//
// Builds
//

var Builds = function() {};
Builds.currentView = 'list';

Builds.prototype.load = function(context, params) {
  $(".content").html('');

  context.load("/builds/" + params.revision + ".json")
      .render("builds.mustache")
      .replace('.content')
      .then(function() {
        $("#list").tablesorter();

        if(params.view == "list") {
          Builds.currentView = "list";

          $("#matrix-tab").removeClass("active")
          $("#list-tab").addClass("active")

          $("#matrix").hide();
          $("#list").show();
        } else {
          Builds.currentView = "matrix";

          $("#list-tab").removeClass("active")
          $("#matrix-tab").addClass("active")

          $("#list").hide();
          $("#matrix").show();
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

  this.get('#/revision/:revision', function(context) {
    this.redirect("#/revision/" + this.params.revision + "/" + Builds.currentView)
  });
});

$(document).ready(function() {
  app.run('#/');
});
