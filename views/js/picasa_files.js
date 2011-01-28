$(function() {
  $('form').submit(function() {
    $(this).css('display', 'none');
    $('div#indicator').css('display', 'block');
  });
});
