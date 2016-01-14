$(document).ready(function() {
  $.getJSON("/--/env.json", function(data) {
    $("#foo").text(data.FOO);
    $("#bar").text(data.BAR);
    $("#secret").text(data.SECRET);
  });
});
